package com.fortunelog.engine.application;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fortunelog.engine.application.dto.PaymentWebhookEvent;
import com.fortunelog.engine.common.ApiClientException;
import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

@Service
public class PaymentWebhookService {
    private static final Set<String> ORDER_STATUS_VALUES = Set.of("pending", "paid", "failed", "canceled");
    private static final Set<String> SUBSCRIPTION_STATUS_VALUES = Set.of("active", "grace", "expired", "canceled");

    private final SupabasePersistenceService persistenceService;
    private final ObjectMapper objectMapper;
    private final String webhookSecret;

    public PaymentWebhookService(
            SupabasePersistenceService persistenceService,
            ObjectMapper objectMapper,
            @Value("${app.payment.webhook-secret:${PAYMENT_WEBHOOK_SECRET:}}") String webhookSecret
    ) {
        this.persistenceService = persistenceService;
        this.objectMapper = objectMapper;
        this.webhookSecret = webhookSecret;
    }

    public PaymentWebhookResult processWebhook(String rawPayload, String signatureHeader) {
        verifySignature(rawPayload, signatureHeader);

        JsonNode payloadNode = parsePayload(rawPayload);
        PaymentWebhookEvent event = parseEvent(payloadNode);
        validateEvent(event);

        String normalizedOrderStatus = normalizeOrderStatus(event.orderStatus());
        String normalizedSubscriptionStatus = normalizeSubscriptionStatus(event.subscriptionStatus());

        boolean duplicate = persistenceService.registerPaymentWebhookEvent(
                event.provider(),
                event.providerOrderId(),
                event.eventId(),
                event.userId(),
                payloadNode
        );

        boolean orderUpdated = false;
        boolean subscriptionUpdated = false;

        if (!duplicate) {
            if (normalizedOrderStatus != null) {
                orderUpdated = persistenceService.updateOrderStatus(
                        event.provider(),
                        event.providerOrderId(),
                        normalizedOrderStatus
                );
            }

            if (normalizedSubscriptionStatus != null && event.planCode() != null && !event.planCode().isBlank()) {
                subscriptionUpdated = persistenceService.upsertSubscriptionSnapshot(
                        event.userId(),
                        event.planCode(),
                        normalizedSubscriptionStatus,
                        normalizeIsoInstant(event.subscriptionStartedAt()),
                        normalizeIsoInstant(event.subscriptionExpiresAt())
                );
            }
        }

        boolean entitled = persistenceService.hasActiveEntitlement(event.userId())
                || persistenceService.hasPaidOrder(event.userId());
        int reportsUpdated = persistenceService.updatePaidReportVisibility(event.userId(), entitled);

        return new PaymentWebhookResult(
                duplicate,
                orderUpdated,
                subscriptionUpdated,
                entitled,
                reportsUpdated,
                idempotencyKey(event)
        );
    }

    private JsonNode parsePayload(String rawPayload) {
        try {
            return objectMapper.readTree(rawPayload);
        } catch (JsonProcessingException e) {
            throw new ApiClientException(
                    "PAYMENT_WEBHOOK_INVALID",
                    HttpStatus.BAD_REQUEST,
                    "invalid payment webhook payload"
            );
        }
    }

    private PaymentWebhookEvent parseEvent(JsonNode payloadNode) {
        try {
            return objectMapper.treeToValue(payloadNode, PaymentWebhookEvent.class);
        } catch (JsonProcessingException e) {
            throw new ApiClientException(
                    "PAYMENT_WEBHOOK_INVALID",
                    HttpStatus.BAD_REQUEST,
                    "invalid payment webhook payload"
            );
        }
    }

    private void validateEvent(PaymentWebhookEvent event) {
        if (isBlank(event.provider())) {
            throw badRequest("provider is required");
        }
        if (isBlank(event.providerOrderId())) {
            throw badRequest("provider_order_id is required");
        }
        if (isBlank(event.eventId())) {
            throw badRequest("event_id is required");
        }
        if (isBlank(event.userId())) {
            throw badRequest("user_id is required");
        }

        try {
            UUID.fromString(event.userId());
        } catch (IllegalArgumentException e) {
            throw badRequest("user_id must be a valid UUID");
        }

        String normalizedOrderStatus = normalizeOrderStatus(event.orderStatus());
        String normalizedSubscriptionStatus = normalizeSubscriptionStatus(event.subscriptionStatus());

        if (normalizedOrderStatus == null && normalizedSubscriptionStatus == null) {
            throw badRequest("order_status or subscription_status is required");
        }

        if (normalizedSubscriptionStatus != null && isBlank(event.planCode())) {
            throw badRequest("plan_code is required when subscription_status is present");
        }
    }

    private String normalizeOrderStatus(String value) {
        if (isBlank(value)) {
            return null;
        }

        String normalized = value.trim().toLowerCase(Locale.ROOT);
        if (!ORDER_STATUS_VALUES.contains(normalized)) {
            throw badRequest("unsupported order_status: " + value);
        }
        return normalized;
    }

    private String normalizeSubscriptionStatus(String value) {
        if (isBlank(value)) {
            return null;
        }

        String normalized = value.trim().toLowerCase(Locale.ROOT);
        if (!SUBSCRIPTION_STATUS_VALUES.contains(normalized)) {
            throw badRequest("unsupported subscription_status: " + value);
        }
        return normalized;
    }

    private String normalizeIsoInstant(String value) {
        if (isBlank(value)) {
            return null;
        }

        try {
            return Instant.parse(value.trim()).toString();
        } catch (DateTimeParseException e) {
            throw badRequest("timestamp must be ISO-8601 instant: " + value);
        }
    }

    private void verifySignature(String rawPayload, String signatureHeader) {
        if (isBlank(webhookSecret)) {
            throw new ApiClientException(
                    "PAYMENT_WEBHOOK_NOT_CONFIGURED",
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "payment webhook secret is not configured"
            );
        }
        if (isBlank(signatureHeader)) {
            throw new ApiClientException(
                    "PAYMENT_SIGNATURE_MISSING",
                    HttpStatus.UNAUTHORIZED,
                    "payment webhook signature is missing"
            );
        }

        String expected = hmacSha256Hex(webhookSecret, rawPayload == null ? "" : rawPayload);
        String provided = normalizeSignature(signatureHeader);

        if (!constantTimeEquals(expected, provided)) {
            throw new ApiClientException(
                    "PAYMENT_SIGNATURE_INVALID",
                    HttpStatus.UNAUTHORIZED,
                    "payment webhook signature is invalid"
            );
        }
    }

    private String normalizeSignature(String signatureHeader) {
        String value = signatureHeader == null ? "" : signatureHeader.trim();
        int idx = value.indexOf('=');
        if (idx >= 0 && idx < value.length() - 1) {
            value = value.substring(idx + 1);
        }
        return value.trim().toLowerCase(Locale.ROOT);
    }

    private String hmacSha256Hex(String secret, String payload) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException("failed to validate payment webhook signature", e);
        }
    }

    private boolean constantTimeEquals(String expected, String provided) {
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8),
                provided.getBytes(StandardCharsets.UTF_8)
        );
    }

    private String idempotencyKey(PaymentWebhookEvent event) {
        return event.provider() + ":" + event.providerOrderId() + ":" + event.eventId();
    }

    private ApiClientException badRequest(String message) {
        return new ApiClientException("PAYMENT_WEBHOOK_INVALID", HttpStatus.BAD_REQUEST, message);
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    public record PaymentWebhookResult(
            boolean duplicate,
            boolean orderUpdated,
            boolean subscriptionUpdated,
            boolean entitled,
            int reportsUpdated,
            String idempotencyKey
    ) {
    }
}
