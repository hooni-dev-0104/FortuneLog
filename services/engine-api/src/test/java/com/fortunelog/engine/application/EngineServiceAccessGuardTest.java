package com.fortunelog.engine.application;

import com.fortunelog.engine.application.dto.CalculateChartRequest;
import com.fortunelog.engine.common.ApiClientException;
import com.fortunelog.engine.infra.llm.OpenAiAnalysisClient;
import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;
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
    private EngineService engineService;

    @BeforeEach
    void setUp() {
        persistenceService = mock(SupabasePersistenceService.class);
        OpenAiAnalysisClient aiAnalysisClient = mock(OpenAiAnalysisClient.class);
        engineService = new EngineService(persistenceService, aiAnalysisClient);
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
