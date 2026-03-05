package com.fortunelog.engine.application;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fortunelog.engine.common.ApiClientException;
import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PaymentWebhookServiceTest {

    private static final String SECRET = "test-secret";

    private SupabasePersistenceService persistenceService;
    private PaymentWebhookService service;

    @BeforeEach
    void setUp() {
        persistenceService = mock(SupabasePersistenceService.class);
        service = new PaymentWebhookService(persistenceService, new ObjectMapper(), SECRET);
    }

    @Test
    void shouldProcessWebhookAndPropagateEntitlement() {
        String payload = """
                {
                  "provider": "revenuecat",
                  "provider_order_id": "order-1",
                  "event_id": "evt-1",
                  "user_id": "11111111-1111-1111-1111-111111111111",
                  "order_status": "paid",
                  "plan_code": "premium_monthly",
                  "subscription_status": "active",
                  "subscription_started_at": "2026-03-05T12:00:00Z",
                  "subscription_expires_at": "2026-04-05T12:00:00Z"
                }
                """;

        when(persistenceService.registerPaymentWebhookEvent(
                eq("revenuecat"),
                eq("order-1"),
                eq("evt-1"),
                eq("11111111-1111-1111-1111-111111111111"),
                any()
        )).thenReturn(false);
        when(persistenceService.updateOrderStatus("revenuecat", "order-1", "paid")).thenReturn(true);
        when(persistenceService.upsertSubscriptionSnapshot(
                "11111111-1111-1111-1111-111111111111",
                "premium_monthly",
                "active",
                "2026-03-05T12:00:00Z",
                "2026-04-05T12:00:00Z"
        )).thenReturn(true);
        when(persistenceService.hasActiveEntitlement("11111111-1111-1111-1111-111111111111")).thenReturn(true);
        when(persistenceService.updatePaidReportVisibility("11111111-1111-1111-1111-111111111111", true)).thenReturn(2);

        var result = service.processWebhook(payload, sign(payload));

        assertFalse(result.duplicate());
        assertTrue(result.orderUpdated());
        assertTrue(result.subscriptionUpdated());
        assertTrue(result.entitled());
        assertEquals(2, result.reportsUpdated());
        assertEquals("revenuecat:order-1:evt-1", result.idempotencyKey());

        verify(persistenceService).updateOrderStatus("revenuecat", "order-1", "paid");
        verify(persistenceService).upsertSubscriptionSnapshot(
                "11111111-1111-1111-1111-111111111111",
                "premium_monthly",
                "active",
                "2026-03-05T12:00:00Z",
                "2026-04-05T12:00:00Z"
        );
        verify(persistenceService, never()).hasPaidOrder("11111111-1111-1111-1111-111111111111");
    }

    @Test
    void shouldTreatDuplicateEventAsIdempotentButStillRefreshVisibility() {
        String payload = """
                {
                  "provider": "revenuecat",
                  "provider_order_id": "order-1",
                  "event_id": "evt-dup",
                  "user_id": "11111111-1111-1111-1111-111111111111",
                  "order_status": "paid"
                }
                """;

        when(persistenceService.registerPaymentWebhookEvent(
                eq("revenuecat"),
                eq("order-1"),
                eq("evt-dup"),
                eq("11111111-1111-1111-1111-111111111111"),
                any()
        )).thenReturn(true);
        when(persistenceService.hasActiveEntitlement("11111111-1111-1111-1111-111111111111")).thenReturn(false);
        when(persistenceService.hasPaidOrder("11111111-1111-1111-1111-111111111111")).thenReturn(true);
        when(persistenceService.updatePaidReportVisibility("11111111-1111-1111-1111-111111111111", true)).thenReturn(1);

        var result = service.processWebhook(payload, sign(payload));

        assertTrue(result.duplicate());
        assertFalse(result.orderUpdated());
        assertFalse(result.subscriptionUpdated());
        assertTrue(result.entitled());
        assertEquals(1, result.reportsUpdated());

        verify(persistenceService, never()).updateOrderStatus(any(), any(), any());
        verify(persistenceService, never()).upsertSubscriptionSnapshot(any(), any(), any(), any(), any());
        verify(persistenceService).hasPaidOrder("11111111-1111-1111-1111-111111111111");
    }

    @Test
    void shouldRejectInvalidSignature() {
        String payload = """
                {
                  "provider": "revenuecat",
                  "provider_order_id": "order-1",
                  "event_id": "evt-1",
                  "user_id": "11111111-1111-1111-1111-111111111111",
                  "order_status": "paid"
                }
                """;

        ApiClientException ex = assertThrows(
                ApiClientException.class,
                () -> service.processWebhook(payload, "invalid-signature")
        );

        assertEquals("PAYMENT_SIGNATURE_INVALID", ex.code());
        assertEquals(HttpStatus.UNAUTHORIZED, ex.status());
    }

    private String sign(String payload) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(SECRET.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
