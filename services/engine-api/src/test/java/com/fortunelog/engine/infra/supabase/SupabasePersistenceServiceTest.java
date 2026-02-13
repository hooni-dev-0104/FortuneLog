package com.fortunelog.engine.infra.supabase;

import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.IOException;
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
                "v0.1.0"
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
}
