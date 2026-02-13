package com.fortunelog.engine.infra.supabase;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

@Service
public class SupabasePersistenceService {

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    private final String supabaseUrl;
    private final String serviceRoleKey;

    public SupabasePersistenceService(
            ObjectMapper objectMapper,
            @Value("${app.supabase.url:${SUPABASE_URL:}}") String supabaseUrl,
            @Value("${app.supabase.service-role-key:${SUPABASE_SERVICE_ROLE_KEY:}}") String serviceRoleKey
    ) {
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newHttpClient();
        this.supabaseUrl = trimTrailingSlash(supabaseUrl);
        this.serviceRoleKey = serviceRoleKey;
    }

    public String insertSajuChart(
            String userId,
            String birthProfileId,
            Map<String, String> chart,
            Map<String, Integer> fiveElements,
            String engineVersion
    ) {
        Map<String, Object> payload = Map.of(
                "user_id", userId,
                "birth_profile_id", birthProfileId,
                "chart_json", chart,
                "five_elements_json", fiveElements,
                "engine_version", engineVersion
        );

        return insertReturningId("saju_charts", payload);
    }

    public String insertReport(
            String userId,
            String chartId,
            String reportType,
            Map<String, ?> content,
            boolean isPaidContent,
            boolean visible
    ) {
        Map<String, Object> payload = Map.of(
                "user_id", userId,
                "chart_id", chartId,
                "report_type", reportType,
                "content_json", content,
                "is_paid_content", isPaidContent,
                "visible", visible
        );

        return insertReturningId("reports", payload);
    }

    private String insertReturningId(String table, Map<String, ?> payload) {
        ensureConfigured();
        String encodedSelect = URLEncoder.encode("id", StandardCharsets.UTF_8);
        String path = "/rest/v1/" + table + "?select=" + encodedSelect;
        String responseBody = sendPost(path, List.of(payload));

        try {
            JsonNode node = objectMapper.readTree(responseBody);
            if (!node.isArray() || node.isEmpty() || node.get(0).get("id") == null) {
                throw new IllegalStateException("insert response did not include id");
            }
            return node.get(0).get("id").asText();
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("failed to parse Supabase response", e);
        }
    }

    private String sendPost(String path, Object body) {
        String bodyJson;
        try {
            bodyJson = objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("failed to serialize request body", e);
        }

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(supabaseUrl + path))
                .header("apikey", serviceRoleKey)
                .header("Authorization", "Bearer " + serviceRoleKey)
                .header("Content-Type", "application/json")
                .header("Prefer", "return=representation")
                .POST(HttpRequest.BodyPublishers.ofString(bodyJson))
                .build();

        try {
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("supabase insert failed: " + response.statusCode() + " " + response.body());
            }
            return response.body();
        } catch (IOException e) {
            throw new IllegalStateException("failed to call Supabase", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("supabase call interrupted", e);
        }
    }

    private void ensureConfigured() {
        if (supabaseUrl == null || supabaseUrl.isBlank()) {
            throw new IllegalStateException("SUPABASE_URL is not configured");
        }
        if (serviceRoleKey == null || serviceRoleKey.isBlank()) {
            throw new IllegalStateException("SUPABASE_SERVICE_ROLE_KEY is not configured");
        }
    }

    private String trimTrailingSlash(String value) {
        if (value == null) {
            return "";
        }
        if (value.endsWith("/")) {
            return value.substring(0, value.length() - 1);
        }
        return value;
    }
}
