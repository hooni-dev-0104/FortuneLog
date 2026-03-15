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
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

@Service
public class PaymentWebhookService {
    private static final Set<String> ORDER_STATUS_VALUES = Set.of("pending", "paid", "failed", "canceled");
    private static final Set<String> SUBSCRIPTION_STATUS_VALUES = Set.of("active", "grace", "expired", "canceled");
    private static final String PROVIDER_REVENUECAT = "revenuecat";

    private final SupabasePersistenceService persistenceService;
    private final ObjectMapper objectMapper;
    private final String webhookSecret;
    private final String revenueCatAuthorization;

    public PaymentWebhookService(
            SupabasePersistenceService persistenceService,
            ObjectMapper objectMapper,
            @Value("${app.payment.webhook-secret:${PAYMENT_WEBHOOK_SECRET:}}") String webhookSecret,
            @Value("${app.payment.revenuecat-webhook-authorization:${REVENUECAT_WEBHOOK_AUTH:}}")
            String revenueCatAuthorization
    ) {
        this.persistenceService = persistenceService;
        this.objectMapper = objectMapper;
        this.webhookSecret = webhookSecret;
        this.revenueCatAuthorization = revenueCatAuthorization;
    }

    public PaymentWebhookResult processWebhook(
            String rawPayload,
            String authorizationHeader,
            String signatureHeader
    ) {
        JsonNode payloadNode = parsePayload(rawPayload);
        NormalizedPaymentWebhook event = normalizeEvent(payloadNode);
        verifyCredential(rawPayload, authorizationHeader, signatureHeader, event.credentialMode());

        if (event.noop()) {
            return new PaymentWebhookResult(
                    false,
                    false,
                    false,
                    false,
                    0,
                    idempotencyKey(event)
            );
        }

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
                        normalizeInstant(event.subscriptionStartedAt()),
                        normalizeInstant(event.subscriptionExpiresAt())
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

    private NormalizedPaymentWebhook normalizeEvent(JsonNode payloadNode) {
        JsonNode revenueCatEvent = payloadNode.get("event");
        if (revenueCatEvent != null && revenueCatEvent.isObject()) {
            return normalizeRevenueCatEvent(revenueCatEvent);
        }

        PaymentWebhookEvent event = parseLegacyEvent(payloadNode);
        return new NormalizedPaymentWebhook(
                event.provider(),
                event.providerOrderId(),
                event.eventId(),
                event.userId(),
                event.orderStatus(),
                event.planCode(),
                event.subscriptionStatus(),
                event.subscriptionStartedAt(),
                event.subscriptionExpiresAt(),
                CredentialMode.HMAC_SIGNATURE,
                false
        );
    }

    private PaymentWebhookEvent parseLegacyEvent(JsonNode payloadNode) {
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

    private NormalizedPaymentWebhook normalizeRevenueCatEvent(JsonNode eventNode) {
        String eventType = text(eventNode, "type");
        if (isBlank(eventType)) {
            throw badRequest("event.type is required");
        }

        String normalizedType = eventType.trim().toUpperCase(Locale.ROOT);
        String eventId = firstNonBlank(text(eventNode, "id"), text(eventNode, "event_id"));
        if (isBlank(eventId)) {
            throw badRequest("event.id is required");
        }

        String providerOrderId = firstNonBlank(
                text(eventNode, "original_transaction_id"),
                text(eventNode, "transaction_id"),
                eventId
        );
        String userId = resolveRevenueCatUserId(eventNode);
        String planCode = text(eventNode, "product_id");
        String startedAt = normalizeInstant(fromEpochMillisNode(eventNode.get("purchased_at_ms")));
        String expiresAt = normalizeInstant(fromEpochMillisNode(eventNode.get("expiration_at_ms")));
        String graceExpiresAt = normalizeInstant(fromEpochMillisNode(eventNode.get("grace_period_expiration_at_ms")));

        String orderStatus = null;
        String subscriptionStatus = null;
        boolean noop = false;

        switch (normalizedType) {
            case "INITIAL_PURCHASE", "RENEWAL" -> {
                orderStatus = "paid";
                subscriptionStatus = planCode == null ? null : "active";
            }
            case "NON_RENEWING_PURCHASE" -> orderStatus = "paid";
            case "PRODUCT_CHANGE", "UNCANCELLATION", "SUBSCRIPTION_EXTENDED", "TRANSFER" -> {
                subscriptionStatus = "active";
                expiresAt = firstNonBlank(expiresAt, graceExpiresAt);
            }
            case "TEMPORARY_ENTITLEMENT_GRANT" -> {
                subscriptionStatus = "active";
                expiresAt = firstNonBlank(expiresAt, graceExpiresAt);
            }
            case "BILLING_ISSUE" -> {
                subscriptionStatus = "grace";
                expiresAt = firstNonBlank(graceExpiresAt, expiresAt);
            }
            case "CANCELLATION" -> {
                if (expiresAt == null) {
                    orderStatus = "canceled";
                } else if (isFutureInstant(expiresAt)) {
                    subscriptionStatus = "BILLING_ERROR".equalsIgnoreCase(text(eventNode, "cancel_reason"))
                            ? "grace"
                            : "active";
                } else {
                    subscriptionStatus = "canceled";
                }
            }
            case "SUBSCRIPTION_PAUSED" -> noop = true;
            case "EXPIRATION" -> subscriptionStatus = "expired";
            case "INVOICE_ISSUANCE" -> orderStatus = "pending";
            case "REFUND_REVERSED" -> {
                orderStatus = "paid";
                if (planCode != null) {
                    subscriptionStatus = isFutureInstant(expiresAt) ? "active" : null;
                }
            }
            case "TEST", "SUBSCRIBER_ALIAS", "VIRTUAL_CURRENCY_TRANSACTION", "EXPERIMENT_ENROLLMENT" -> noop = true;
            default -> noop = true;
        }

        return new NormalizedPaymentWebhook(
                PROVIDER_REVENUECAT,
                providerOrderId,
                eventId,
                userId,
                orderStatus,
                planCode,
                subscriptionStatus,
                startedAt,
                expiresAt,
                CredentialMode.AUTHORIZATION_HEADER,
                noop
        );
    }

    private String resolveRevenueCatUserId(JsonNode eventNode) {
        List<String> candidates = new ArrayList<>();
        addCandidate(candidates, text(eventNode, "app_user_id"));
        addCandidate(candidates, text(eventNode, "original_app_user_id"));
        addArrayCandidates(candidates, eventNode.get("aliases"));
        addArrayCandidates(candidates, eventNode.get("transferred_to"));
        addArrayCandidates(candidates, eventNode.get("transferred_from"));

        for (String candidate : candidates) {
            if (isValidUuid(candidate)) {
                return candidate;
            }
        }

        return null;
    }

    private void addCandidate(List<String> candidates, String value) {
        if (!isBlank(value)) {
            candidates.add(value.trim());
        }
    }

    private void addArrayCandidates(List<String> candidates, JsonNode arrayNode) {
        if (arrayNode == null || !arrayNode.isArray()) {
            return;
        }
        for (JsonNode item : arrayNode) {
            if (item != null && !item.isNull()) {
                addCandidate(candidates, item.asText());
            }
        }
    }

    private String text(JsonNode node, String fieldName) {
        if (node == null) {
            return null;
        }
        JsonNode value = node.get(fieldName);
        if (value == null || value.isNull()) {
            return null;
        }
        String text = value.asText();
        return text == null || text.isBlank() ? null : text.trim();
    }

    private void validateEvent(NormalizedPaymentWebhook event) {
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

    private String normalizeInstant(String value) {
        if (isBlank(value)) {
            return null;
        }

        try {
            return Instant.parse(value.trim()).toString();
        } catch (DateTimeParseException e) {
            throw badRequest("timestamp must be ISO-8601 instant: " + value);
        }
    }

    private String fromEpochMillisNode(JsonNode node) {
        if (node == null || node.isNull()) {
            return null;
        }
        if (node.isNumber()) {
            return Instant.ofEpochMilli(node.asLong()).toString();
        }

        String raw = node.asText();
        if (raw == null || raw.isBlank()) {
            return null;
        }

        try {
            return Instant.ofEpochMilli(Long.parseLong(raw.trim())).toString();
        } catch (NumberFormatException ignored) {
            return normalizeInstant(raw);
        }
    }

    private boolean isFutureInstant(String value) {
        if (isBlank(value)) {
            return false;
        }

        try {
            return !Instant.parse(value).isBefore(Instant.now());
        } catch (DateTimeParseException e) {
            throw badRequest("timestamp must be ISO-8601 instant: " + value);
        }
    }

    private void verifyCredential(
            String rawPayload,
            String authorizationHeader,
            String signatureHeader,
            CredentialMode credentialMode
    ) {
        if (credentialMode == CredentialMode.AUTHORIZATION_HEADER) {
            verifyAuthorizationHeader(authorizationHeader);
            return;
        }

        verifySignatureHeader(rawPayload, signatureHeader);
    }

    private void verifyAuthorizationHeader(String authorizationHeader) {
        String expected = normalizedAuthorization(revenueCatAuthorization);
        if (isBlank(expected)) {
            throw new ApiClientException(
                    "PAYMENT_WEBHOOK_NOT_CONFIGURED",
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "revenuecat webhook authorization is not configured"
            );
        }

        if (isBlank(authorizationHeader)) {
            throw new ApiClientException(
                    "PAYMENT_SIGNATURE_MISSING",
                    HttpStatus.UNAUTHORIZED,
                    "payment webhook authorization header is missing"
            );
        }

        String provided = normalizedAuthorization(authorizationHeader);
        if (!constantTimeEquals(expected, provided)) {
            throw new ApiClientException(
                    "PAYMENT_SIGNATURE_INVALID",
                    HttpStatus.UNAUTHORIZED,
                    "payment webhook authorization header is invalid"
            );
        }
    }

    private void verifySignatureHeader(String rawPayload, String signatureHeader) {
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

    private String normalizedAuthorization(String headerValue) {
        if (isBlank(headerValue)) {
            return "";
        }
        String value = headerValue.trim();
        if (value.regionMatches(true, 0, "Bearer ", 0, 7)) {
            value = value.substring(7).trim();
        }
        return value;
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

    private String idempotencyKey(NormalizedPaymentWebhook event) {
        return event.provider() + ":" + event.providerOrderId() + ":" + event.eventId();
    }

    private ApiClientException badRequest(String message) {
        return new ApiClientException("PAYMENT_WEBHOOK_INVALID", HttpStatus.BAD_REQUEST, message);
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private boolean isValidUuid(String value) {
        try {
            UUID.fromString(value);
            return true;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (!isBlank(value)) {
                return value.trim();
            }
        }
        return null;
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

    private enum CredentialMode {
        AUTHORIZATION_HEADER,
        HMAC_SIGNATURE
    }

    private record NormalizedPaymentWebhook(
            String provider,
            String providerOrderId,
            String eventId,
            String userId,
            String orderStatus,
            String planCode,
            String subscriptionStatus,
            String subscriptionStartedAt,
            String subscriptionExpiresAt,
            CredentialMode credentialMode,
            boolean noop
    ) {
    }
}
