package com.fortunelog.engine.infra.supabase;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpConnectTimeoutException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class SupabasePersistenceService {

    public record ChartSnapshot(
            Map<String, String> chart,
            Map<String, Integer> fiveElements
    ) {
    }

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    private final String supabaseUrl;
    private final String serviceRoleKey;
    private final int maxRetries;
    private final long backoffMs;
    private final Duration requestTimeout;

    public SupabasePersistenceService(
            ObjectMapper objectMapper,
            @Value("${app.supabase.url:${SUPABASE_URL:}}") String supabaseUrl,
            @Value("${app.supabase.service-role-key:${SUPABASE_SERVICE_ROLE_KEY:}}") String serviceRoleKey,
            @Value("${app.supabase.max-retries:2}") int maxRetries,
            @Value("${app.supabase.retry-backoff-ms:300}") long backoffMs,
            @Value("${app.supabase.request-timeout-ms:5000}") long requestTimeoutMs
    ) {
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newHttpClient();
        this.supabaseUrl = trimTrailingSlash(supabaseUrl);
        this.serviceRoleKey = serviceRoleKey;
        this.maxRetries = Math.max(maxRetries, 0);
        this.backoffMs = Math.max(backoffMs, 0L);
        this.requestTimeout = Duration.ofMillis(Math.max(requestTimeoutMs, 1000L));
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

        return upsertReturningId(
                "saju_charts",
                payload,
                List.of("user_id", "birth_profile_id", "engine_version")
        );
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

    public String upsertDailyFortuneReport(
            String userId,
            String chartId,
            LocalDate targetDate,
            Map<String, ?> content,
            boolean isPaidContent,
            boolean visible
    ) {
        Map<String, Object> payload = Map.of(
                "user_id", userId,
                "chart_id", chartId,
                "report_type", "daily",
                "target_date", targetDate.toString(),
                "content_json", content,
                "is_paid_content", isPaidContent,
                "visible", visible
        );

        try {
            return upsertReturningId(
                    "reports",
                    payload,
                    List.of("user_id", "chart_id", "report_type", "target_date")
            );
        } catch (IllegalStateException e) {
            // Backward compatibility:
            // - schemas without reports.target_date
            // - schemas missing a matching unique constraint for ON CONFLICT(user_id, chart_id, report_type, target_date)
            // In both cases we can't upsert by date, so we fall back to inserting a daily report row.
            String msg = e.getMessage() == null ? "" : e.getMessage().toLowerCase();
            // PostgREST error variants we've seen:
            // - "column reports.target_date does not exist"
            // - "PGRST204 ... Could not find the 'target_date' column of 'reports' in the schema cache"
            boolean missingTargetDate =
                    msg.contains("target_date") && (
                            msg.contains("does not exist")
                                    || msg.contains("could not find")
                                    || msg.contains("schema cache")
                                    || msg.contains("pgrst204")
                    );
            // Postgres variant:
            // - "42P10 ... there is no unique or exclusion constraint matching the ON CONFLICT specification"
            boolean missingConflictConstraint = isMissingConflictConstraint(msg);

            if (missingTargetDate || missingConflictConstraint) {
                return insertReport(userId, chartId, "daily", content, isPaidContent, visible);
            }
            throw e;
        }
    }

    public String upsertNonDailyReport(
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

        try {
            return upsertReturningId(
                    "reports",
                    payload,
                    List.of("user_id", "chart_id", "report_type")
            );
        } catch (IllegalStateException e) {
            String msg = e.getMessage() == null ? "" : e.getMessage().toLowerCase();
            if (isMissingConflictConstraint(msg)) {
                // Some DBs don't have a matching non-partial unique index for
                // ON CONFLICT(user_id, chart_id, report_type). Fallback to insert.
                try {
                    return insertReport(userId, chartId, reportType, content, isPaidContent, visible);
                } catch (IllegalStateException insertError) {
                    String insertMsg = insertError.getMessage() == null
                            ? ""
                            : insertError.getMessage().toLowerCase();
                    if (isUniqueViolation(insertMsg)) {
                        // If a legacy/partial unique index already has a row, update it in-place.
                        // This keeps "재생성" flows working even without a compatible ON CONFLICT target.
                        return updateExistingNonDailyReport(
                                userId,
                                chartId,
                                reportType,
                                content,
                                isPaidContent,
                                visible
                        );
                    }
                    throw insertError;
                }
            }
            throw e;
        }
    }

    private boolean isMissingConflictConstraint(String errorMessageLowerCase) {
        return errorMessageLowerCase.contains("42p10")
                || errorMessageLowerCase.contains("no unique or exclusion constraint matching the on conflict specification");
    }

    private boolean isUniqueViolation(String errorMessageLowerCase) {
        return errorMessageLowerCase.contains("23505")
                || errorMessageLowerCase.contains("duplicate key value violates unique constraint");
    }

    private String updateExistingNonDailyReport(
            String userId,
            String chartId,
            String reportType,
            Map<String, ?> content,
            boolean isPaidContent,
            boolean visible
    ) {
        Map<String, Object> payload = Map.of(
                "content_json", content,
                "is_paid_content", isPaidContent,
                "visible", visible
        );
        String path = "/rest/v1/reports"
                + "?select=" + URLEncoder.encode("id", StandardCharsets.UTF_8)
                + "&user_id=" + URLEncoder.encode("eq." + userId, StandardCharsets.UTF_8)
                + "&chart_id=" + URLEncoder.encode("eq." + chartId, StandardCharsets.UTF_8)
                + "&report_type=" + URLEncoder.encode("eq." + reportType, StandardCharsets.UTF_8);
        String responseBody = sendPatch(path, payload);

        try {
            JsonNode node = objectMapper.readTree(responseBody);
            if (!node.isArray() || node.isEmpty() || node.get(0).get("id") == null) {
                throw new IllegalStateException("update response did not include id");
            }
            return node.get(0).get("id").asText();
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("failed to parse Supabase response", e);
        }
    }

    public ChartSnapshot findChartSnapshot(String userId, String chartId) {
        ensureConfigured();
        String path = "/rest/v1/saju_charts"
                + "?select=" + URLEncoder.encode("chart_json,five_elements_json", StandardCharsets.UTF_8)
                + "&id=" + URLEncoder.encode("eq." + chartId, StandardCharsets.UTF_8)
                + "&user_id=" + URLEncoder.encode("eq." + userId, StandardCharsets.UTF_8)
                + "&limit=1";
        String responseBody = sendGet(path);

        try {
            JsonNode node = objectMapper.readTree(responseBody);
            if (!node.isArray() || node.isEmpty()) {
                return null;
            }

            JsonNode row = node.get(0);
            JsonNode chartNode = row.get("chart_json");
            JsonNode fiveNode = row.get("five_elements_json");
            if (chartNode == null || fiveNode == null) {
                return null;
            }

            Map<String, String> chart = objectMapper.convertValue(
                    chartNode,
                    new TypeReference<>() {}
            );
            Map<String, Integer> fiveElements = objectMapper.convertValue(
                    fiveNode,
                    new TypeReference<>() {}
            );
            return new ChartSnapshot(chart, fiveElements);
        } catch (IllegalArgumentException | JsonProcessingException e) {
            throw new IllegalStateException("failed to parse Supabase chart response", e);
        }
    }

    private String insertReturningId(String table, Map<String, ?> payload) {
        return writeReturningId(table, payload, false, List.of());
    }

    private String upsertReturningId(String table, Map<String, ?> payload, List<String> onConflictColumns) {
        return writeReturningId(table, payload, true, onConflictColumns);
    }

    private String writeReturningId(
            String table,
            Map<String, ?> payload,
            boolean upsert,
            List<String> onConflictColumns
    ) {
        ensureConfigured();
        String path = buildWritePath(table, upsert, onConflictColumns);
        String responseBody = sendPost(path, List.of(payload), upsert);

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

    private String buildWritePath(String table, boolean upsert, List<String> onConflictColumns) {
        List<String> query = new ArrayList<>();
        query.add("select=" + URLEncoder.encode("id", StandardCharsets.UTF_8));
        if (upsert && !onConflictColumns.isEmpty()) {
            query.add("on_conflict=" + URLEncoder.encode(String.join(",", onConflictColumns), StandardCharsets.UTF_8));
        }
        return "/rest/v1/" + table + "?" + String.join("&", query);
    }

    private String sendPost(String path, Object body, boolean upsert) {
        String bodyJson;
        try {
            bodyJson = objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("failed to serialize request body", e);
        }

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(supabaseUrl + path))
                .timeout(requestTimeout)
                .header("apikey", serviceRoleKey)
                .header("Authorization", "Bearer " + serviceRoleKey)
                .header("Content-Type", "application/json")
                .header("Prefer", preferHeader(upsert))
                .POST(HttpRequest.BodyPublishers.ofString(bodyJson))
                .build();

        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
                if (response.statusCode() >= 200 && response.statusCode() < 300) {
                    return response.body();
                }

                if (!isRetryableStatus(response.statusCode()) || attempt == maxRetries) {
                    throw new IllegalStateException("supabase insert failed: " + response.statusCode() + " " + response.body());
                }
            } catch (HttpConnectTimeoutException e) {
                if (attempt == maxRetries) {
                    throw new IllegalStateException("supabase request timeout", e);
                }
            } catch (IOException e) {
                if (attempt == maxRetries) {
                    throw new IllegalStateException("failed to call Supabase", e);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("supabase call interrupted", e);
            }

            sleepBackoff(attempt);
        }

        throw new IllegalStateException("supabase insert failed after retries");
    }

    private String sendGet(String path) {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(supabaseUrl + path))
                .timeout(requestTimeout)
                .header("apikey", serviceRoleKey)
                .header("Authorization", "Bearer " + serviceRoleKey)
                .header("Accept", "application/json")
                .GET()
                .build();

        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
                if (response.statusCode() >= 200 && response.statusCode() < 300) {
                    return response.body();
                }

                if (!isRetryableStatus(response.statusCode()) || attempt == maxRetries) {
                    throw new IllegalStateException("supabase select failed: " + response.statusCode() + " " + response.body());
                }
            } catch (HttpConnectTimeoutException e) {
                if (attempt == maxRetries) {
                    throw new IllegalStateException("supabase request timeout", e);
                }
            } catch (IOException e) {
                if (attempt == maxRetries) {
                    throw new IllegalStateException("failed to call Supabase", e);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("supabase call interrupted", e);
            }

            sleepBackoff(attempt);
        }

        throw new IllegalStateException("supabase select failed after retries");
    }

    private String sendPatch(String path, Object body) {
        String bodyJson;
        try {
            bodyJson = objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("failed to serialize request body", e);
        }

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(supabaseUrl + path))
                .timeout(requestTimeout)
                .header("apikey", serviceRoleKey)
                .header("Authorization", "Bearer " + serviceRoleKey)
                .header("Content-Type", "application/json")
                .header("Prefer", "return=representation")
                .method("PATCH", HttpRequest.BodyPublishers.ofString(bodyJson))
                .build();

        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
                if (response.statusCode() >= 200 && response.statusCode() < 300) {
                    return response.body();
                }

                if (!isRetryableStatus(response.statusCode()) || attempt == maxRetries) {
                    throw new IllegalStateException("supabase update failed: " + response.statusCode() + " " + response.body());
                }
            } catch (HttpConnectTimeoutException e) {
                if (attempt == maxRetries) {
                    throw new IllegalStateException("supabase request timeout", e);
                }
            } catch (IOException e) {
                if (attempt == maxRetries) {
                    throw new IllegalStateException("failed to call Supabase", e);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("supabase call interrupted", e);
            }

            sleepBackoff(attempt);
        }

        throw new IllegalStateException("supabase update failed after retries");
    }

    private String preferHeader(boolean upsert) {
        if (upsert) {
            return "return=representation,resolution=merge-duplicates";
        }
        return "return=representation";
    }

    private boolean isRetryableStatus(int statusCode) {
        return statusCode == 408 || statusCode == 429 || statusCode >= 500;
    }

    private void sleepBackoff(int attempt) {
        if (backoffMs == 0L) {
            return;
        }

        long delay = backoffMs * (attempt + 1);
        try {
            Thread.sleep(delay);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("supabase retry backoff interrupted", e);
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
