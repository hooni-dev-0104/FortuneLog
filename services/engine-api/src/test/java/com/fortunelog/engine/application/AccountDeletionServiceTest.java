package com.fortunelog.engine.application;

import com.fortunelog.engine.common.ApiClientException;
import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AccountDeletionServiceTest {

    private SupabasePersistenceService persistenceService;
    private AccountDeletionService service;

    @BeforeEach
    void setUp() {
        persistenceService = mock(SupabasePersistenceService.class);
        service = new AccountDeletionService(persistenceService);
    }

    @Test
    void shouldReturnExistingRequestWhenActiveRequestAlreadyExists() {
        String userId = "11111111-1111-1111-1111-111111111111";
        when(persistenceService.findActiveAccountDeletionRequestId(userId)).thenReturn("existing-del-1");

        var result = service.requestDeletion(userId, "테스트 사유");

        assertEquals("existing-del-1", result.deletionRequestId());
        assertEquals("requested", result.status());
        assertTrue(result.alreadyRequested());
    }

    @Test
    void shouldCreateDeletionRequestWhenNoActiveRequestExists() {
        String userId = "11111111-1111-1111-1111-111111111111";
        when(persistenceService.findActiveAccountDeletionRequestId(userId)).thenReturn(null);
        when(persistenceService.createAccountDeletionRequest(userId, "개인정보 삭제 요청")).thenReturn("new-del-1");

        var result = service.requestDeletion(userId, "  개인정보 삭제 요청  ");

        assertEquals("new-del-1", result.deletionRequestId());
        assertEquals("requested", result.status());
        assertFalse(result.alreadyRequested());
        verify(persistenceService).createAccountDeletionRequest(userId, "개인정보 삭제 요청");
    }

    @Test
    void shouldRejectInvalidUserId() {
        ApiClientException ex = assertThrows(
                ApiClientException.class,
                () -> service.requestDeletion("not-uuid", null)
        );

        assertEquals("ACCOUNT_DELETION_INVALID_USER", ex.code());
        assertEquals(HttpStatus.BAD_REQUEST, ex.status());
    }
}
