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

    private static final String LEGACY_SECRET = "legacy-test-secret";
    private static final String REVENUECAT_AUTH = "rc-test-secret";
    private static final String USER_ID = "11111111-1111-1111-1111-111111111111";

    private SupabasePersistenceService persistenceService;
    private PaymentWebhookService service;

    @BeforeEach
    void setUp() {
        persistenceService = mock(SupabasePersistenceService.class);
        service = new PaymentWebhookService(
                persistenceService,
                new ObjectMapper(),
                LEGACY_SECRET,
                REVENUECAT_AUTH
        );
    }

    @Test
    void shouldProcessRevenueCatInitialPurchaseAndPropagateEntitlement() {
        String payload = """
                {
                  "api_version": "1.0",
                  "event": {
                    "id": "evt-1",
                    "type": "INITIAL_PURCHASE",
                    "app_user_id": "%s",
                    "product_id": "premium_monthly",
                    "original_transaction_id": "orig-1",
                    "transaction_id": "tx-1",
                    "purchased_at_ms": 1772712000000,
                    "expiration_at_ms": 1775390400000
                  }
                }
                """.formatted(USER_ID);

        when(persistenceService.registerPaymentWebhookEvent(
                eq("revenuecat"),
                eq("orig-1"),
                eq("evt-1"),
                eq(USER_ID),
                any()
        )).thenReturn(false);
        when(persistenceService.updateOrderStatus("revenuecat", "orig-1", "paid")).thenReturn(true);
        when(persistenceService.upsertSubscriptionSnapshot(
                USER_ID,
                "premium_monthly",
                "active",
                "2026-03-05T12:00:00Z",
                "2026-04-05T12:00:00Z"
        )).thenReturn(true);
        when(persistenceService.hasActiveEntitlement(USER_ID)).thenReturn(true);
        when(persistenceService.updatePaidReportVisibility(USER_ID, true)).thenReturn(2);

        var result = service.processWebhook(payload, "Bearer " + REVENUECAT_AUTH, null);

        assertFalse(result.duplicate());
        assertTrue(result.orderUpdated());
        assertTrue(result.subscriptionUpdated());
        assertTrue(result.entitled());
        assertEquals(2, result.reportsUpdated());
        assertEquals("revenuecat:orig-1:evt-1", result.idempotencyKey());

        verify(persistenceService).updateOrderStatus("revenuecat", "orig-1", "paid");
        verify(persistenceService).upsertSubscriptionSnapshot(
                USER_ID,
                "premium_monthly",
                "active",
                "2026-03-05T12:00:00Z",
                "2026-04-05T12:00:00Z"
        );
        verify(persistenceService, never()).hasPaidOrder(USER_ID);
    }

    @Test
    void shouldResolveRevenueCatUserIdFromAliases() {
        String payload = """
                {
                  "api_version": "1.0",
                  "event": {
                    "id": "evt-alias",
                    "type": "BILLING_ISSUE",
                    "app_user_id": "$RCAnonymousID:anon",
                    "original_app_user_id": "$RCAnonymousID:anon",
                    "aliases": ["%s"],
                    "product_id": "premium_monthly",
                    "original_transaction_id": "orig-2",
                    "purchased_at_ms": 1772712000000,
                    "expiration_at_ms": 1775390400000,
                    "grace_period_expiration_at_ms": 1775822400000
                  }
                }
                """.formatted(USER_ID);

        when(persistenceService.registerPaymentWebhookEvent(
                eq("revenuecat"),
                eq("orig-2"),
                eq("evt-alias"),
                eq(USER_ID),
                any()
        )).thenReturn(false);
        when(persistenceService.upsertSubscriptionSnapshot(
                USER_ID,
                "premium_monthly",
                "grace",
                "2026-03-05T12:00:00Z",
                "2026-04-10T12:00:00Z"
        )).thenReturn(true);
        when(persistenceService.hasActiveEntitlement(USER_ID)).thenReturn(true);
        when(persistenceService.updatePaidReportVisibility(USER_ID, true)).thenReturn(1);

        var result = service.processWebhook(payload, "Bearer " + REVENUECAT_AUTH, null);

        assertFalse(result.duplicate());
        assertFalse(result.orderUpdated());
        assertTrue(result.subscriptionUpdated());
        assertTrue(result.entitled());

        verify(persistenceService, never()).updateOrderStatus(any(), any(), any());
        verify(persistenceService).upsertSubscriptionSnapshot(
                USER_ID,
                "premium_monthly",
                "grace",
                "2026-03-05T12:00:00Z",
                "2026-04-10T12:00:00Z"
        );
    }

    @Test
    void shouldKeepAccessOnRevenueCatCancellationUntilExpiration() {
        String payload = """
                {
                  "api_version": "1.0",
                  "event": {
                    "id": "evt-cancel",
                    "type": "CANCELLATION",
                    "app_user_id": "%s",
                    "product_id": "premium_monthly",
                    "original_transaction_id": "orig-3",
                    "purchased_at_ms": 1772712000000,
                    "expiration_at_ms": 4102444800000,
                    "cancel_reason": "UNSUBSCRIBE"
                  }
                }
                """.formatted(USER_ID);

        when(persistenceService.registerPaymentWebhookEvent(
                eq("revenuecat"),
                eq("orig-3"),
                eq("evt-cancel"),
                eq(USER_ID),
                any()
        )).thenReturn(false);
        when(persistenceService.upsertSubscriptionSnapshot(
                USER_ID,
                "premium_monthly",
                "active",
                "2026-03-05T12:00:00Z",
                "2100-01-01T00:00:00Z"
        )).thenReturn(true);
        when(persistenceService.hasActiveEntitlement(USER_ID)).thenReturn(true);
        when(persistenceService.updatePaidReportVisibility(USER_ID, true)).thenReturn(1);

        var result = service.processWebhook(payload, "Bearer " + REVENUECAT_AUTH, null);

        assertFalse(result.duplicate());
        assertFalse(result.orderUpdated());
        assertTrue(result.subscriptionUpdated());
        assertTrue(result.entitled());

        verify(persistenceService, never()).updateOrderStatus(any(), any(), any());
        verify(persistenceService).upsertSubscriptionSnapshot(
                USER_ID,
                "premium_monthly",
                "active",
                "2026-03-05T12:00:00Z",
                "2100-01-01T00:00:00Z"
        );
    }

    @Test
    void shouldExpireRevenueCatSubscriptionAndHidePaidReports() {
        String payload = """
                {
                  "api_version": "1.0",
                  "event": {
                    "id": "evt-expired",
                    "type": "EXPIRATION",
                    "app_user_id": "%s",
                    "product_id": "premium_monthly",
                    "original_transaction_id": "orig-4",
                    "purchased_at_ms": 1772712000000,
                    "expiration_at_ms": 1775390400000
                  }
                }
                """.formatted(USER_ID);

        when(persistenceService.registerPaymentWebhookEvent(
                eq("revenuecat"),
                eq("orig-4"),
                eq("evt-expired"),
                eq(USER_ID),
                any()
        )).thenReturn(false);
        when(persistenceService.upsertSubscriptionSnapshot(
                USER_ID,
                "premium_monthly",
                "expired",
                "2026-03-05T12:00:00Z",
                "2026-04-05T12:00:00Z"
        )).thenReturn(true);
        when(persistenceService.hasActiveEntitlement(USER_ID)).thenReturn(false);
        when(persistenceService.hasPaidOrder(USER_ID)).thenReturn(false);
        when(persistenceService.updatePaidReportVisibility(USER_ID, false)).thenReturn(3);

        var result = service.processWebhook(payload, "Bearer " + REVENUECAT_AUTH, null);

        assertFalse(result.duplicate());
        assertFalse(result.orderUpdated());
        assertTrue(result.subscriptionUpdated());
        assertFalse(result.entitled());
        assertEquals(3, result.reportsUpdated());

        verify(persistenceService).hasPaidOrder(USER_ID);
        verify(persistenceService).updatePaidReportVisibility(USER_ID, false);
    }

    @Test
    void shouldTreatRevenueCatTestEventAsNoop() {
        String payload = """
                {
                  "api_version": "1.0",
                  "event": {
                    "id": "evt-test",
                    "type": "TEST",
                    "app_user_id": "%s",
                    "original_transaction_id": "orig-test"
                  }
                }
                """.formatted(USER_ID);

        var result = service.processWebhook(payload, "Bearer " + REVENUECAT_AUTH, null);

        assertFalse(result.duplicate());
        assertFalse(result.orderUpdated());
        assertFalse(result.subscriptionUpdated());
        assertFalse(result.entitled());
        assertEquals(0, result.reportsUpdated());
        assertEquals("revenuecat:orig-test:evt-test", result.idempotencyKey());

        verify(persistenceService, never()).registerPaymentWebhookEvent(any(), any(), any(), any(), any());
    }

    @Test
    void shouldTreatDuplicateLegacyEventAsIdempotentButStillRefreshVisibility() {
        String payload = """
                {
                  "provider": "revenuecat",
                  "provider_order_id": "order-1",
                  "event_id": "evt-dup",
                  "user_id": "%s",
                  "order_status": "paid"
                }
                """.formatted(USER_ID);

        when(persistenceService.registerPaymentWebhookEvent(
                eq("revenuecat"),
                eq("order-1"),
                eq("evt-dup"),
                eq(USER_ID),
                any()
        )).thenReturn(true);
        when(persistenceService.hasActiveEntitlement(USER_ID)).thenReturn(false);
        when(persistenceService.hasPaidOrder(USER_ID)).thenReturn(true);
        when(persistenceService.updatePaidReportVisibility(USER_ID, true)).thenReturn(1);

        var result = service.processWebhook(payload, null, sign(payload));

        assertTrue(result.duplicate());
        assertFalse(result.orderUpdated());
        assertFalse(result.subscriptionUpdated());
        assertTrue(result.entitled());
        assertEquals(1, result.reportsUpdated());

        verify(persistenceService, never()).updateOrderStatus(any(), any(), any());
        verify(persistenceService, never()).upsertSubscriptionSnapshot(any(), any(), any(), any(), any());
        verify(persistenceService).hasPaidOrder(USER_ID);
    }

    @Test
    void shouldRejectInvalidRevenueCatAuthorizationHeader() {
        String payload = """
                {
                  "api_version": "1.0",
                  "event": {
                    "id": "evt-unauthorized",
                    "type": "INITIAL_PURCHASE",
                    "app_user_id": "%s",
                    "product_id": "premium_monthly",
                    "original_transaction_id": "orig-5"
                  }
                }
                """.formatted(USER_ID);

        ApiClientException ex = assertThrows(
                ApiClientException.class,
                () -> service.processWebhook(payload, "Bearer wrong", null)
        );

        assertEquals("PAYMENT_SIGNATURE_INVALID", ex.code());
        assertEquals(HttpStatus.UNAUTHORIZED, ex.status());
    }

    @Test
    void shouldRejectInvalidLegacySignature() {
        String payload = """
                {
                  "provider": "revenuecat",
                  "provider_order_id": "order-1",
                  "event_id": "evt-1",
                  "user_id": "%s",
                  "order_status": "paid"
                }
                """.formatted(USER_ID);

        ApiClientException ex = assertThrows(
                ApiClientException.class,
                () -> service.processWebhook(payload, null, "invalid-signature")
        );

        assertEquals("PAYMENT_SIGNATURE_INVALID", ex.code());
        assertEquals(HttpStatus.UNAUTHORIZED, ex.status());
    }

    private String sign(String payload) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(LEGACY_SECRET.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
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
