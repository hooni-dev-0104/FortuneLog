package com.fortunelog.engine.api;

import com.fortunelog.engine.application.AccountDeletionService;
import com.fortunelog.engine.application.EngineService;
import com.fortunelog.engine.application.PaymentWebhookService;
import com.fortunelog.engine.application.dto.RequestAccountDeletionRequest;
import org.junit.jupiter.api.Test;
import org.springframework.core.env.Environment;
import org.springframework.security.oauth2.jwt.Jwt;

import jakarta.servlet.http.HttpServletRequest;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EngineControllerTest {

    @Test
    void shouldForwardRevenueCatAuthorizationHeaderToPaymentWebhookService() {
        EngineService engineService = mock(EngineService.class);
        PaymentWebhookService paymentWebhookService = mock(PaymentWebhookService.class);
        AccountDeletionService accountDeletionService = mock(AccountDeletionService.class);
        Environment environment = mock(Environment.class);
        HttpServletRequest request = mock(HttpServletRequest.class);

        when(request.getAttribute("requestId")).thenReturn("req-1");
        when(paymentWebhookService.processWebhook("{}", "Bearer rc-test-secret", null))
                .thenReturn(new PaymentWebhookService.PaymentWebhookResult(false, true, true, true, 2, "idem-1"));

        EngineController controller = new EngineController(
                engineService,
                paymentWebhookService,
                accountDeletionService,
                environment
        );
        Map<String, Object> response = controller.processPaymentWebhook(
                "{}",
                "Bearer rc-test-secret",
                null,
                request
        );

        assertEquals("req-1", response.get("requestId"));
        assertEquals(false, response.get("duplicate"));
        assertEquals(true, response.get("orderUpdated"));
        assertEquals(true, response.get("subscriptionUpdated"));
        assertEquals(true, response.get("entitled"));
        assertEquals(2, response.get("reportsUpdated"));
        assertEquals("idem-1", response.get("idempotencyKey"));

        verify(paymentWebhookService).processWebhook("{}", "Bearer rc-test-secret", null);
    }

    @Test
    void shouldCreateAccountDeletionRequestForAuthenticatedUser() {
        EngineService engineService = mock(EngineService.class);
        PaymentWebhookService paymentWebhookService = mock(PaymentWebhookService.class);
        AccountDeletionService accountDeletionService = mock(AccountDeletionService.class);
        Environment environment = mock(Environment.class);
        HttpServletRequest request = mock(HttpServletRequest.class);
        Jwt jwt = mock(Jwt.class);

        when(request.getAttribute("requestId")).thenReturn("req-del-1");
        when(jwt.getSubject()).thenReturn("11111111-1111-1111-1111-111111111111");
        when(accountDeletionService.requestDeletion(
                "11111111-1111-1111-1111-111111111111",
                "서비스를 더 이상 사용하지 않습니다."
        )).thenReturn(new AccountDeletionService.AccountDeletionRequestResult(
                "del-req-1",
                "requested",
                false
        ));

        EngineController controller = new EngineController(
                engineService,
                paymentWebhookService,
                accountDeletionService,
                environment
        );

        Map<String, Object> response = controller.requestAccountDeletion(
                new RequestAccountDeletionRequest("서비스를 더 이상 사용하지 않습니다."),
                jwt,
                request
        );

        assertEquals("req-del-1", response.get("requestId"));
        assertEquals("del-req-1", response.get("deletionRequestId"));
        assertEquals("requested", response.get("status"));
        assertEquals(false, response.get("alreadyRequested"));
        verify(accountDeletionService).requestDeletion(
                "11111111-1111-1111-1111-111111111111",
                "서비스를 더 이상 사용하지 않습니다."
        );
    }
}
