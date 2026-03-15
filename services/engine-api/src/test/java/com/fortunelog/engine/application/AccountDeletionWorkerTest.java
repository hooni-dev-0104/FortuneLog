package com.fortunelog.engine.application;

import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AccountDeletionWorkerTest {

    private SupabasePersistenceService persistenceService;
    private AccountDeletionWorker worker;

    @BeforeEach
    void setUp() {
        persistenceService = mock(SupabasePersistenceService.class);
        worker = new AccountDeletionWorker(persistenceService, true, 20);
    }

    @Test
    void shouldProcessRequestedDeletionAndComplete() {
        var item = new SupabasePersistenceService.AccountDeletionQueueItem(
                "req-1",
                "11111111-1111-1111-1111-111111111111"
        );
        when(persistenceService.findRequestedAccountDeletionRequests(20)).thenReturn(List.of(item));
        when(persistenceService.markAccountDeletionRequestProcessing("req-1")).thenReturn(true);
        when(persistenceService.deleteUserReports(item.userId())).thenReturn(2);
        when(persistenceService.deleteUserCharts(item.userId())).thenReturn(1);
        when(persistenceService.deleteUserBirthProfiles(item.userId())).thenReturn(1);
        when(persistenceService.deleteUserOrders(item.userId())).thenReturn(0);
        when(persistenceService.deleteUserSubscriptions(item.userId())).thenReturn(0);
        when(persistenceService.anonymizeUserProfile(item.userId())).thenReturn(true);
        when(persistenceService.markAccountDeletionRequestCompleted("req-1")).thenReturn(true);

        worker.processRequestedDeletions();

        verify(persistenceService).markAccountDeletionRequestCompleted("req-1");
        verify(persistenceService, never()).markAccountDeletionRequestRejected("req-1");
    }

    @Test
    void shouldRejectRequestWhenProcessingFails() {
        var item = new SupabasePersistenceService.AccountDeletionQueueItem(
                "req-2",
                "11111111-1111-1111-1111-111111111111"
        );
        when(persistenceService.findRequestedAccountDeletionRequests(20)).thenReturn(List.of(item));
        when(persistenceService.markAccountDeletionRequestProcessing("req-2")).thenReturn(true);
        when(persistenceService.deleteUserReports(item.userId())).thenThrow(new IllegalStateException("boom"));

        worker.processRequestedDeletions();

        verify(persistenceService).markAccountDeletionRequestRejected("req-2");
        verify(persistenceService, never()).markAccountDeletionRequestCompleted("req-2");
    }
}
