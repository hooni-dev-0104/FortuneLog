package com.fortunelog.engine.application;

import com.fortunelog.engine.application.dto.CalculateChartRequest;
import com.fortunelog.engine.application.dto.GenerateReportRequest;
import com.fortunelog.engine.application.dto.GenerateAiInterpretationRequest;
import com.fortunelog.engine.common.ApiClientException;
import com.fortunelog.engine.infra.llm.OpenAiAnalysisClient;
import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;

import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EngineServiceAccessGuardTest {

    private SupabasePersistenceService persistenceService;
    private OpenAiAnalysisClient aiAnalysisClient;
    private EngineService engineService;

    @BeforeEach
    void setUp() {
        persistenceService = mock(SupabasePersistenceService.class);
        aiAnalysisClient = mock(OpenAiAnalysisClient.class);
        engineService = new EngineService(persistenceService, aiAnalysisClient);
    }

    @Test
    void shouldRequireAiCreditsBeforeGeneratingInterpretation() {
        String userId = "11111111-1111-1111-1111-111111111111";
        String chartId = "22222222-2222-2222-2222-222222222222";
        when(persistenceService.findChartSnapshot(userId, chartId)).thenReturn(
                new SupabasePersistenceService.ChartSnapshot(
                        Map.of("year", "갑자", "month", "을축", "day", "병인", "hour", "정묘"),
                        Map.of("wood", 2, "fire", 1, "earth", 1, "metal", 1, "water", 1)
                )
        );
        when(persistenceService.creditBalance(userId, "ai_interpretation")).thenReturn(0);

        ApiClientException ex = assertThrows(
                ApiClientException.class,
                () -> engineService.generateAiInterpretation(userId, new GenerateAiInterpretationRequest(chartId))
        );

        assertEquals("AI_CREDIT_REQUIRED", ex.code());
        assertEquals(HttpStatus.PAYMENT_REQUIRED, ex.status());
        verify(aiAnalysisClient, never()).generateSajuInterpretation(
                org.mockito.ArgumentMatchers.anyMap(),
                org.mockito.ArgumentMatchers.anyMap()
        );
    }

    @Test
    void shouldFinalizeAiInterpretationBeforeReturningContent() {
        String userId = "11111111-1111-1111-1111-111111111111";
        String chartId = "22222222-2222-2222-2222-222222222222";
        when(persistenceService.findChartSnapshot(userId, chartId)).thenReturn(
                new SupabasePersistenceService.ChartSnapshot(
                        Map.of("year", "갑자", "month", "을축", "day", "병인", "hour", "정묘"),
                        Map.of("wood", 2, "fire", 1, "earth", 1, "metal", 1, "water", 1)
                )
        );
        when(persistenceService.creditBalance(userId, "ai_interpretation")).thenReturn(1);
        when(aiAnalysisClient.generateSajuInterpretation(
                org.mockito.ArgumentMatchers.anyMap(),
                org.mockito.ArgumentMatchers.anyMap()
        )).thenReturn(Map.of("summary", "ok", "source", "openai"));
        when(persistenceService.finalizeAiInterpretationReport(
                org.mockito.ArgumentMatchers.eq(userId),
                org.mockito.ArgumentMatchers.eq(chartId),
                org.mockito.ArgumentMatchers.anyMap(),
                org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyMap()
        )).thenReturn(true);

        var result = engineService.generateAiInterpretation(userId, new GenerateAiInterpretationRequest(chartId));

        assertEquals(chartId, result.chartId());
        assertEquals("ai_interpretation", result.reportType());
        assertEquals("ok", result.content().get("summary"));
        verify(persistenceService).finalizeAiInterpretationReport(
                org.mockito.ArgumentMatchers.eq(userId),
                org.mockito.ArgumentMatchers.eq(chartId),
                org.mockito.ArgumentMatchers.anyMap(),
                org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyMap()
        );
    }

    @Test
    void shouldNotReturnAiContentWhenFinalizationFails() {
        String userId = "11111111-1111-1111-1111-111111111111";
        String chartId = "22222222-2222-2222-2222-222222222222";
        when(persistenceService.findChartSnapshot(userId, chartId)).thenReturn(
                new SupabasePersistenceService.ChartSnapshot(
                        Map.of("year", "갑자", "month", "을축", "day", "병인", "hour", "정묘"),
                        Map.of("wood", 2, "fire", 1, "earth", 1, "metal", 1, "water", 1)
                )
        );
        when(persistenceService.creditBalance(userId, "ai_interpretation")).thenReturn(1);
        when(aiAnalysisClient.generateSajuInterpretation(
                org.mockito.ArgumentMatchers.anyMap(),
                org.mockito.ArgumentMatchers.anyMap()
        )).thenReturn(Map.of("summary", "ok", "source", "openai"));
        when(persistenceService.finalizeAiInterpretationReport(
                org.mockito.ArgumentMatchers.eq(userId),
                org.mockito.ArgumentMatchers.eq(chartId),
                org.mockito.ArgumentMatchers.anyMap(),
                org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyMap()
        )).thenReturn(false);

        ApiClientException ex = assertThrows(
                ApiClientException.class,
                () -> engineService.generateAiInterpretation(userId, new GenerateAiInterpretationRequest(chartId))
        );

        assertEquals("AI_CREDIT_REQUIRED", ex.code());
        assertEquals(HttpStatus.PAYMENT_REQUIRED, ex.status());
    }

    @Test
    void shouldReturnFallbackWithoutSavingOrConsumingCredits() {
        when(persistenceService.findChartSnapshot("user", "chart")).thenReturn(
                new SupabasePersistenceService.ChartSnapshot(Map.of(), Map.of()));
        when(persistenceService.creditBalance("user", "ai_interpretation")).thenReturn(1);
        when(aiAnalysisClient.generateSajuInterpretation(Map.of(), Map.of()))
                .thenReturn(Map.of("summary", "free guidance", "source", "fallback"));

        var result = engineService.generateAiInterpretation("user", new GenerateAiInterpretationRequest("chart"));
        assertEquals("fallback", result.content().get("source"));
        assertEquals(false, result.content().get("creditCharged"));
        verify(persistenceService, never()).finalizeAiInterpretationReport(
                org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyMap(), org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyMap());
    }

    @Test
    void shouldRejectUnverifiedAiContentWithoutCharging() {
        when(persistenceService.findChartSnapshot("user", "chart")).thenReturn(
                new SupabasePersistenceService.ChartSnapshot(Map.of(), Map.of()));
        when(persistenceService.creditBalance("user", "ai_interpretation")).thenReturn(1);
        when(aiAnalysisClient.generateSajuInterpretation(Map.of(), Map.of()))
                .thenReturn(Map.of("summary", "unverified"));
        var error = assertThrows(ApiClientException.class, () -> engineService.generateAiInterpretation(
                "user", new GenerateAiInterpretationRequest("chart")));
        assertEquals("AI_RESPONSE_INVALID", error.code());
        verify(persistenceService, never()).finalizeAiInterpretationReport(
                org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyMap(), org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyMap());
    }

    @Test
    void shouldKeepPersonalizedReportsClosedWithoutPersistingExamples() {
        when(persistenceService.findChartSnapshot("user", "chart")).thenReturn(
                new SupabasePersistenceService.ChartSnapshot(Map.of(), Map.of()));
        for (String type : java.util.List.of("personality", "relationship", "career")) {
            var error = assertThrows(ApiClientException.class, () -> engineService.generateReport(
                    "user", new GenerateReportRequest("chart", type)));
            assertEquals("REPORT_NOT_READY", error.code());
        }
        verify(persistenceService, never()).upsertNonDailyReport(
                org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyMap(),
                org.mockito.ArgumentMatchers.anyBoolean(), org.mockito.ArgumentMatchers.anyBoolean());
    }

    @Test
    void shouldRejectUnknownChartAndUnsupportedReportType() {
        assertEquals("CHART_NOT_FOUND", assertThrows(ApiClientException.class,
                () -> engineService.generateReport("user", new GenerateReportRequest("other-chart", "career"))).code());
        assertEquals("REPORT_TYPE_UNSUPPORTED", assertThrows(ApiClientException.class,
                () -> engineService.generateReport("user", new GenerateReportRequest("chart", "unknown"))).code());
    }

    @Test
    void shouldBlockChartCalculationWhenUserProfileIsDeactivated() {
        String userId = "11111111-1111-1111-1111-111111111111";
        when(persistenceService.isProfileDeactivated(userId)).thenReturn(true);

        var request = new CalculateChartRequest(
                "birth-1",
                "1990-01-01",
                "10:30",
                "Asia/Seoul",
                "Seoul",
                "solar",
                false,
                "male",
                false
        );

        ApiClientException ex = assertThrows(
                ApiClientException.class,
                () -> engineService.calculateChart(userId, request)
        );

        assertEquals("ACCOUNT_DELETION_LOCKED", ex.code());
        assertEquals(HttpStatus.FORBIDDEN, ex.status());
        verify(persistenceService, never()).insertSajuChart(
                org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyMap(),
                org.mockito.ArgumentMatchers.anyMap(),
                org.mockito.ArgumentMatchers.anyString()
        );
    }
}
