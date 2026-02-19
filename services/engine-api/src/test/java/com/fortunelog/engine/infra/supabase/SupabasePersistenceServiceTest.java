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
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
        assertTrue(first.getPath().contains("on_conflict=user_id%2Creport_type%2Ctarget_date"));

        RecordedRequest second = server.takeRequest();
        assertTrue(second.getPath().contains("/rest/v1/reports"));
        assertTrue(!second.getPath().contains("on_conflict="));
    }
}
