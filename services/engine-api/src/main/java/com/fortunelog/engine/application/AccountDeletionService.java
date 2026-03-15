package com.fortunelog.engine.application;

import com.fortunelog.engine.common.ApiClientException;
import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class AccountDeletionService {

    public record AccountDeletionRequestResult(
            String deletionRequestId,
            String status,
            boolean alreadyRequested
    ) {
    }

    private final SupabasePersistenceService persistenceService;

    public AccountDeletionService(SupabasePersistenceService persistenceService) {
        this.persistenceService = persistenceService;
    }

    public AccountDeletionRequestResult requestDeletion(String userId, String reason) {
        validateUserId(userId);

        markUserAsDeactivated(userId);

        String existingRequestId = persistenceService.findActiveAccountDeletionRequestId(userId);
        if (existingRequestId != null && !existingRequestId.isBlank()) {
            return new AccountDeletionRequestResult(existingRequestId, "requested", true);
        }

        String deletionRequestId;
        try {
            deletionRequestId = persistenceService.createAccountDeletionRequest(userId, normalizeReason(reason));
        } catch (IllegalStateException ex) {
            throw new ApiClientException(
                    "ACCOUNT_DELETION_REQUEST_FAILED",
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "failed to create account deletion request"
            );
        }

        return new AccountDeletionRequestResult(deletionRequestId, "requested", false);
    }

    private void markUserAsDeactivated(String userId) {
        try {
            persistenceService.markProfileDeactivated(userId);
        } catch (IllegalStateException ex) {
            throw new ApiClientException(
                    "ACCOUNT_DELETION_REQUEST_FAILED",
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "failed to mark profile as deactivated"
            );
        }
    }

    private void validateUserId(String userId) {
        if (userId == null || userId.isBlank()) {
            throw new ApiClientException(
                    "ACCOUNT_DELETION_INVALID_USER",
                    HttpStatus.BAD_REQUEST,
                    "user id is required"
            );
        }

        try {
            UUID.fromString(userId);
        } catch (IllegalArgumentException e) {
            throw new ApiClientException(
                    "ACCOUNT_DELETION_INVALID_USER",
                    HttpStatus.BAD_REQUEST,
                    "user id must be a valid UUID"
            );
        }
    }

    private String normalizeReason(String reason) {
        if (reason == null) {
            return null;
        }
        String trimmed = reason.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
