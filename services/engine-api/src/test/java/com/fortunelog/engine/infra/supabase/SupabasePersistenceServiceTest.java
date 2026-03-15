package com.fortunelog.engine.infra.supabase;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fortunelog.engine.application.EngineVersion;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SupabasePersistenceServiceTest {

    private MockWebServer server;
    private SupabasePersistenceService service;

    @BeforeEach
    void setUp() throws IOException {
        server = new MockWebServer();
        server.start();
        service = new SupabasePersistenceService(
                new ObjectMapper(),
                server.url("/").toString(),
                "service-key",
                0,
                0,
                5000
        );
    }

    @AfterEach
    void tearDown() throws IOException {
        server.shutdown();
    }

    @Test
    void shouldUpsertChartAndReturnId() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(201).setBody("[{\"id\":\"chart-1\"}]"));

        String id = service.insertSajuChart(
                "user-1",
                "birth-1",
                Map.of("year", "갑자"),
                Map.of("wood", 2),
                EngineVersion.CURRENT
        );

        assertEquals("chart-1", id);

        RecordedRequest request = server.takeRequest();
        assertTrue(request.getPath().contains("/rest/v1/saju_charts"));
        assertTrue(request.getPath().contains("on_conflict=user_id%2Cbirth_profile_id%2Cengine_version"));
        assertEquals("return=representation,resolution=merge-duplicates", request.getHeader("Prefer"));
    }

    @Test
    void shouldInsertDailyReportWithoutUpsert() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(201).setBody("[{\"id\":\"report-1\"}]"));

        String id = service.insertReport(
                "user-1",
                "chart-1",
                "daily",
                Map.of("score", 80),
                false,
                true
        );

        assertEquals("report-1", id);

        RecordedRequest request = server.takeRequest();
        assertTrue(request.getPath().contains("/rest/v1/reports"));
        assertTrue(!request.getPath().contains("on_conflict="));
        assertEquals("return=representation", request.getHeader("Prefer"));
    }

    @Test
    void shouldFallbackToInsertWhenDailyUpsertConstraintIsMissing() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(400).setBody(
                "{\"code\":\"42P10\",\"message\":\"there is no unique or exclusion constraint matching the ON CONFLICT specification\"}"
        ));
        server.enqueue(new MockResponse().setResponseCode(201).setBody("[{\"id\":\"report-fallback\"}]"));

        String id = service.upsertDailyFortuneReport(
                "user-1",
                "chart-1",
                LocalDate.of(2026, 2, 19),
                Map.of("score", 74),
                false,
                true
        );

        assertEquals("report-fallback", id);

        RecordedRequest first = server.takeRequest();
        assertTrue(first.getPath().contains("/rest/v1/reports"));
        assertTrue(first.getPath().contains("on_conflict=user_id%2Cchart_id%2Creport_type%2Ctarget_date"));

        RecordedRequest second = server.takeRequest();
        assertTrue(second.getPath().contains("/rest/v1/reports"));
        assertTrue(!second.getPath().contains("on_conflict="));
    }

    @Test
    void shouldFallbackToInsertWhenNonDailyUpsertConstraintIsMissing() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(400).setBody(
                "{\"code\":\"42P10\",\"message\":\"there is no unique or exclusion constraint matching the ON CONFLICT specification\"}"
        ));
        server.enqueue(new MockResponse().setResponseCode(201).setBody("[{\"id\":\"report-non-daily-fallback\"}]"));

        String id = service.upsertNonDailyReport(
                "user-1",
                "chart-1",
                "ai_interpretation",
                Map.of("summary", "ok"),
                true,
                true
        );

        assertEquals("report-non-daily-fallback", id);

        RecordedRequest first = server.takeRequest();
        assertTrue(first.getPath().contains("/rest/v1/reports"));
        assertTrue(first.getPath().contains("on_conflict=user_id%2Cchart_id%2Creport_type"));

        RecordedRequest second = server.takeRequest();
        assertTrue(second.getPath().contains("/rest/v1/reports"));
        assertTrue(!second.getPath().contains("on_conflict="));
    }

    @Test
    void shouldUpdateExistingNonDailyReportWhenFallbackInsertHitsDuplicate() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(400).setBody(
                "{\"code\":\"42P10\",\"message\":\"there is no unique or exclusion constraint matching the ON CONFLICT specification\"}"
        ));
        server.enqueue(new MockResponse().setResponseCode(409).setBody(
                "{\"code\":\"23505\",\"message\":\"duplicate key value violates unique constraint \\\"reports_user_chart_type_unique\\\"\"}"
        ));
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"id\":\"report-existing\"}]"));

        String id = service.upsertNonDailyReport(
                "user-1",
                "chart-1",
                "ai_interpretation",
                Map.of("summary", "updated"),
                true,
                true
        );

        assertEquals("report-existing", id);

        RecordedRequest first = server.takeRequest();
        assertTrue(first.getPath().contains("/rest/v1/reports"));
        assertTrue(first.getPath().contains("on_conflict=user_id%2Cchart_id%2Creport_type"));

        RecordedRequest second = server.takeRequest();
        assertTrue(second.getPath().contains("/rest/v1/reports"));
        assertTrue(!second.getPath().contains("on_conflict="));

        RecordedRequest third = server.takeRequest();
        assertEquals("PATCH", third.getMethod());
        assertTrue(third.getPath().contains("/rest/v1/reports"));
        assertTrue(third.getPath().contains("user_id=eq.user-1"));
        assertTrue(third.getPath().contains("chart_id=eq.chart-1"));
        assertTrue(third.getPath().contains("report_type=eq.ai_interpretation"));
    }

    @Test
    void shouldMarkWebhookEventAsDuplicateWhenUniqueConstraintHits() throws Exception {
        server.enqueue(new MockResponse().setResponseCode(409).setBody(
                "{\"code\":\"23505\",\"message\":\"duplicate key value violates unique constraint \\\"payment_webhook_events_idempotency_key_key\\\"\"}"
        ));

        boolean duplicate = service.registerPaymentWebhookEvent(
                "appstore",
                "order-1",
                "evt-1",
                "11111111-1111-1111-1111-111111111111",
                new ObjectMapper().readTree("{\"kind\":\"test\"}")
        );

        assertTrue(duplicate);

        RecordedRequest request = server.takeRequest();
        assertEquals("POST", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/payment_webhook_events"));
    }

    @Test
    void shouldFindActiveAccountDeletionRequestId() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"id\":\"del-1\"}]"));

        String requestId = service.findActiveAccountDeletionRequestId("user-1");

        assertEquals("del-1", requestId);

        RecordedRequest request = server.takeRequest();
        assertEquals("GET", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/account_deletion_requests"));
        assertTrue(request.getPath().contains("status=in.%28requested%2Cprocessing%29"));
    }

    @Test
    void shouldCreateAccountDeletionRequestAndReturnId() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(201).setBody("[{\"id\":\"del-2\"}]"));

        String requestId = service.createAccountDeletionRequest(
                "user-1",
                "서비스를 더 이상 사용하지 않음"
        );

        assertEquals("del-2", requestId);

        RecordedRequest request = server.takeRequest();
        assertEquals("POST", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/account_deletion_requests"));
    }

    @Test
    void shouldMarkProfileAsDeactivated() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"id\":\"user-1\"}]"));

        boolean updated = service.markProfileDeactivated("user-1");

        assertTrue(updated);

        RecordedRequest request = server.takeRequest();
        assertEquals("PATCH", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/profiles"));
        assertTrue(request.getPath().contains("id=eq.user-1"));
    }

    @Test
    void shouldReadProfileDeactivatedFlag() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"is_deactivated\":true}]"));

        boolean deactivated = service.isProfileDeactivated("user-1");

        assertTrue(deactivated);

        RecordedRequest request = server.takeRequest();
        assertEquals("GET", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/profiles"));
        assertTrue(request.getPath().contains("select=is_deactivated"));
    }

    @Test
    void shouldFindRequestedAccountDeletionQueueItems() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody(
                "[{\"id\":\"req-1\",\"user_id\":\"user-1\"}]"
        ));

        List<SupabasePersistenceService.AccountDeletionQueueItem> items =
                service.findRequestedAccountDeletionRequests(20);

        assertEquals(1, items.size());
        assertEquals("req-1", items.get(0).requestId());
        assertEquals("user-1", items.get(0).userId());

        RecordedRequest request = server.takeRequest();
        assertEquals("GET", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/account_deletion_requests"));
        assertTrue(request.getPath().contains("status=eq.requested"));
    }

    @Test
    void shouldMarkAccountDeletionRequestAsProcessing() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"id\":\"req-1\"}]"));

        boolean updated = service.markAccountDeletionRequestProcessing("req-1");

        assertTrue(updated);

        RecordedRequest request = server.takeRequest();
        assertEquals("PATCH", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/account_deletion_requests"));
        assertTrue(request.getPath().contains("status=eq.requested"));
    }

    @Test
    void shouldMarkAccountDeletionRequestAsCompleted() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"id\":\"req-1\"}]"));

        boolean updated = service.markAccountDeletionRequestCompleted("req-1");

        assertTrue(updated);

        RecordedRequest request = server.takeRequest();
        assertEquals("PATCH", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/account_deletion_requests"));
        assertTrue(request.getPath().contains("status=eq.processing"));
    }

    @Test
    void shouldDeleteReportsByUserId() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"id\":\"r1\"},{\"id\":\"r2\"}]"));

        int deleted = service.deleteUserReports("user-1");

        assertEquals(2, deleted);

        RecordedRequest request = server.takeRequest();
        assertEquals("DELETE", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/reports"));
        assertTrue(request.getPath().contains("user_id=eq.user-1"));
    }

    @Test
    void shouldUpdateOrderStatusByProviderAndProviderOrderId() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"id\":\"order-1\"}]"));

        boolean updated = service.updateOrderStatus("appstore", "order-1", "paid");

        assertTrue(updated);

        RecordedRequest request = server.takeRequest();
        assertEquals("PATCH", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/orders"));
        assertTrue(request.getPath().contains("provider=eq.appstore"));
        assertTrue(request.getPath().contains("provider_order_id=eq.order-1"));
    }

    @Test
    void shouldUpsertSubscriptionByUpdatingExistingSnapshot() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"id\":\"sub-1\"}]"));
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"id\":\"sub-1\"}]"));

        boolean updated = service.upsertSubscriptionSnapshot(
                "user-1",
                "premium_monthly",
                "active",
                "2026-03-05T00:00:00Z",
                "2026-04-05T00:00:00Z"
        );

        assertTrue(updated);

        RecordedRequest find = server.takeRequest();
        assertEquals("GET", find.getMethod());
        assertTrue(find.getPath().contains("/rest/v1/subscriptions"));
        assertTrue(find.getPath().contains("user_id=eq.user-1"));
        assertTrue(find.getPath().contains("plan_code=eq.premium_monthly"));

        RecordedRequest patch = server.takeRequest();
        assertEquals("PATCH", patch.getMethod());
        assertTrue(patch.getPath().contains("/rest/v1/subscriptions"));
        assertTrue(patch.getPath().contains("id=eq.sub-1"));
    }

    @Test
    void shouldDetectActiveEntitlementFromSubscriptionRows() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody(
                "[{\"status\":\"grace\",\"expires_at\":\"2099-01-01T00:00:00Z\"}]"
        ));

        boolean entitled = service.hasActiveEntitlement("user-1");

        assertTrue(entitled);

        RecordedRequest request = server.takeRequest();
        assertEquals("GET", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/subscriptions"));
        assertTrue(request.getPath().contains("status=in.%28active%2Cgrace%29"));
    }

    @Test
    void shouldReturnFalseWhenNoPaidOrderExists() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[]"));

        boolean hasPaidOrder = service.hasPaidOrder("user-1");

        assertFalse(hasPaidOrder);

        RecordedRequest request = server.takeRequest();
        assertEquals("GET", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/orders"));
        assertTrue(request.getPath().contains("status=eq.paid"));
    }

    @Test
    void shouldUpdatePaidReportVisibilityAndReturnAffectedCount() throws InterruptedException {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("[{\"id\":\"r1\"},{\"id\":\"r2\"}]"));

        int updated = service.updatePaidReportVisibility("user-1", false);

        assertEquals(2, updated);

        RecordedRequest request = server.takeRequest();
        assertEquals("PATCH", request.getMethod());
        assertTrue(request.getPath().contains("/rest/v1/reports"));
        assertTrue(request.getPath().contains("user_id=eq.user-1"));
        assertTrue(request.getPath().contains("is_paid_content=is.true"));
    }
}
