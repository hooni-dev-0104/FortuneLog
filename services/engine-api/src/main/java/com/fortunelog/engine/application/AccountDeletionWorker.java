package com.fortunelog.engine.application;

import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class AccountDeletionWorker {

    private static final Logger log = LoggerFactory.getLogger(AccountDeletionWorker.class);

    private final SupabasePersistenceService persistenceService;
    private final boolean enabled;
    private final int batchSize;

    public AccountDeletionWorker(
            SupabasePersistenceService persistenceService,
            @Value("${app.account-deletion.worker-enabled:true}") boolean enabled,
            @Value("${app.account-deletion.worker-batch-size:20}") int batchSize
    ) {
        this.persistenceService = persistenceService;
        this.enabled = enabled;
        this.batchSize = Math.max(1, Math.min(batchSize, 100));
    }

    @Scheduled(fixedDelayString = "${app.account-deletion.worker-fixed-delay-ms:30000}")
    public void processRequestedDeletions() {
        if (!enabled) {
            return;
        }

        List<SupabasePersistenceService.AccountDeletionQueueItem> queue =
                persistenceService.findRequestedAccountDeletionRequests(batchSize);
        if (queue.isEmpty()) {
            return;
        }

        for (SupabasePersistenceService.AccountDeletionQueueItem item : queue) {
            boolean claimed = persistenceService.markAccountDeletionRequestProcessing(item.requestId());
            if (!claimed) {
                continue;
            }
            processOne(item);
        }
    }

    private void processOne(SupabasePersistenceService.AccountDeletionQueueItem item) {
        try {
            int reportRows = persistenceService.deleteUserReports(item.userId());
            int chartRows = persistenceService.deleteUserCharts(item.userId());
            int birthRows = persistenceService.deleteUserBirthProfiles(item.userId());
            int orderRows = persistenceService.deleteUserOrders(item.userId());
            int subscriptionRows = persistenceService.deleteUserSubscriptions(item.userId());
            persistenceService.anonymizeUserProfile(item.userId());
            persistenceService.markAccountDeletionRequestCompleted(item.requestId());

            log.info(
                    "account deletion completed: requestId={} userId={} deletedRows(reports={},charts={},birthProfiles={},orders={},subscriptions={})",
                    item.requestId(),
                    item.userId(),
                    reportRows,
                    chartRows,
                    birthRows,
                    orderRows,
                    subscriptionRows
            );
        } catch (Exception ex) {
            log.error("account deletion failed: requestId={} userId={}", item.requestId(), item.userId(), ex);
            persistenceService.markAccountDeletionRequestRejected(item.requestId());
        }
    }
}
