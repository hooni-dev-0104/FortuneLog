package com.fortunelog.engine.application.dto;

import com.fasterxml.jackson.annotation.JsonAlias;

public record PaymentWebhookEvent(
        @JsonAlias({"provider"})
        String provider,
        @JsonAlias({"provider_order_id", "providerOrderId"})
        String providerOrderId,
        @JsonAlias({"event_id", "eventId"})
        String eventId,
        @JsonAlias({"user_id", "userId"})
        String userId,
        @JsonAlias({"order_status", "orderStatus"})
        String orderStatus,
        @JsonAlias({"plan_code", "planCode"})
        String planCode,
        @JsonAlias({"subscription_status", "subscriptionStatus"})
        String subscriptionStatus,
        @JsonAlias({"subscription_started_at", "subscriptionStartedAt"})
        String subscriptionStartedAt,
        @JsonAlias({"subscription_expires_at", "subscriptionExpiresAt"})
        String subscriptionExpiresAt
) {
}
