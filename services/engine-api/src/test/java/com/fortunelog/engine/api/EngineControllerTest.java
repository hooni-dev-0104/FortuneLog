package com.fortunelog.engine.api;

import com.fortunelog.engine.application.EngineService;
import com.fortunelog.engine.application.PaymentWebhookService;
import org.junit.jupiter.api.Test;
import org.springframework.core.env.Environment;

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
        Environment environment = mock(Environment.class);
        HttpServletRequest request = mock(HttpServletRequest.class);

        when(request.getAttribute("requestId")).thenReturn("req-1");
        when(paymentWebhookService.processWebhook("{}", "Bearer rc-test-secret", null))
                .thenReturn(new PaymentWebhookService.PaymentWebhookResult(false, true, true, true, 2, "idem-1"));

        EngineController controller = new EngineController(engineService, paymentWebhookService, environment);
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
}
