package com.fortunelog.engine.infra.llm;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fortunelog.engine.common.ApiClientException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class GeminiAnalysisClient {

    private static final Logger log = LoggerFactory.getLogger(GeminiAnalysisClient.class);

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final String apiKey;
    private final String model;
    private final String apiBaseUrl;
    private final Duration requestTimeout;

    public GeminiAnalysisClient(
            ObjectMapper objectMapper,
            @Value("${app.gemini.api-key:${GEMINI_API_KEY:}}") String apiKey,
            @Value("${app.gemini.model:${GEMINI_MODEL:gemini-2.5-flash}}") String model,
            @Value("${app.gemini.api-base-url:${GEMINI_API_BASE_URL:https://generativelanguage.googleapis.com}}") String apiBaseUrl,
            @Value("${app.gemini.request-timeout-ms:${GEMINI_REQUEST_TIMEOUT_MS:15000}}") long requestTimeoutMs
    ) {
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newHttpClient();
        this.apiKey = apiKey == null ? "" : apiKey.trim();
        this.model = model == null || model.isBlank() ? "gemini-2.5-flash" : model.trim();
        this.apiBaseUrl = trimTrailingSlash(apiBaseUrl == null ? "" : apiBaseUrl.trim());
        this.requestTimeout = Duration.ofMillis(Math.max(requestTimeoutMs, 1000L));
    }

    public Map<String, Object> generateSajuInterpretation(Map<String, String> chart, Map<String, Integer> fiveElements) {
        if (apiKey.isBlank()) {
            throw new ApiClientException(
                    "AI_CONFIG_MISSING",
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "AI 해석 서비스 설정이 아직 완료되지 않았습니다."
            );
        }
        if (apiBaseUrl.isBlank()) {
            throw new ApiClientException(
                    "AI_CONFIG_MISSING",
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "AI 해석 서비스 설정이 아직 완료되지 않았습니다."
            );
        }

        String prompt = buildPrompt(chart, fiveElements);
        String requestBody = buildRequestBody(prompt);
        String path = "/v1beta/models/" + model + ":generateContent?key=" + URLEncoder.encode(apiKey, StandardCharsets.UTF_8);
        URI uri = URI.create(apiBaseUrl + path);

        HttpRequest request = HttpRequest.newBuilder(uri)
                .timeout(requestTimeout)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                .build();

        HttpResponse<String> response;
        try {
            response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        } catch (IOException | InterruptedException e) {
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            throw new ApiClientException(
                    "AI_GENERATION_FAILED",
                    HttpStatus.BAD_GATEWAY,
                    "AI 해석 생성에 실패했습니다. 잠시 후 다시 시도해주세요."
            );
        }

        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            log.warn("gemini call failed: status={}, body={}", response.statusCode(), response.body());
            throw new ApiClientException(
                    "AI_GENERATION_FAILED",
                    HttpStatus.BAD_GATEWAY,
                    "AI 해석 생성에 실패했습니다. 잠시 후 다시 시도해주세요."
            );
        }

        String modelText = extractCandidateText(response.body());
        Map<String, Object> parsed = parseModelJson(modelText);
        parsed.put("model", model);
        parsed.put("generatedAt", Instant.now().toString());
        parsed.put("source", "gemini");
        return parsed;
    }

    private String buildRequestBody(String prompt) {
        Map<String, Object> payload = Map.of(
                "contents", List.of(
                        Map.of(
                                "role", "user",
                                "parts", List.of(Map.of("text", prompt))
                        )
                ),
                "generationConfig", Map.of(
                        "temperature", 0.8,
                        "topP", 0.95,
                        "maxOutputTokens", 2048,
                        "responseMimeType", "application/json"
                )
        );

        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException e) {
            throw new ApiClientException(
                    "AI_GENERATION_FAILED",
                    HttpStatus.BAD_GATEWAY,
                    "AI 해석 생성에 실패했습니다. 잠시 후 다시 시도해주세요."
            );
        }
    }

    private String buildPrompt(Map<String, String> chart, Map<String, Integer> fiveElements) {
        String year = valueOrDash(chart.get("year"));
        String month = valueOrDash(chart.get("month"));
        String day = valueOrDash(chart.get("day"));
        String hour = valueOrDash(chart.get("hour"));

        int wood = fiveElements.getOrDefault("wood", 0);
        int fire = fiveElements.getOrDefault("fire", 0);
        int earth = fiveElements.getOrDefault("earth", 0);
        int metal = fiveElements.getOrDefault("metal", 0);
        int water = fiveElements.getOrDefault("water", 0);

        return """
                당신은 한국어로 설명하는 사주 전문 상담가입니다.
                입력된 사주팔자와 오행 분포를 바탕으로, 초보자도 이해하기 쉬운 문장으로 해석하세요.
                단정적인 예언/의학 진단/투자 확언은 피하고, 현실적인 조언 위주로 작성하세요.
                                
                [입력 데이터]
                - 년주: %s
                - 월주: %s
                - 일주: %s
                - 시주: %s
                - 오행: 목=%d, 화=%d, 토=%d, 금=%d, 수=%d
                                
                아래 JSON 스키마로만 응답하세요. 키 이름은 그대로 유지하고, 값은 한국어로 작성하세요.
                {
                  "summary": "한 문단 요약 (2~3문장)",
                  "coreTraits": ["성향 1", "성향 2", "성향 3"],
                  "strengths": ["강점 1", "강점 2", "강점 3"],
                  "cautions": ["주의점 1", "주의점 2", "주의점 3"],
                  "themes": {
                    "money": "금전운 해석",
                    "relationship": "연애/결혼운 해석",
                    "career": "직업/일운 해석",
                    "health": "건강운 해석"
                  },
                  "fortuneByPeriod": {
                    "year": "올해 운세",
                    "month": "이번 달 운세",
                    "week": "이번 주 운세",
                    "day": "오늘 운세"
                  },
                  "actionTips": ["실행 팁 1", "실행 팁 2", "실행 팁 3"],
                  "disclaimer": "참고용 안내 문구 1문장"
                }
                """.formatted(year, month, day, hour, wood, fire, earth, metal, water);
    }

    private String extractCandidateText(String responseBody) {
        try {
            JsonNode root = objectMapper.readTree(responseBody);
            JsonNode textNode = root.at("/candidates/0/content/parts/0/text");
            if (textNode.isMissingNode() || textNode.asText().isBlank()) {
                throw new ApiClientException(
                        "AI_RESPONSE_INVALID",
                        HttpStatus.BAD_GATEWAY,
                        "AI 해석 결과를 읽지 못했습니다. 잠시 후 다시 시도해주세요."
                );
            }
            return textNode.asText();
        } catch (JsonProcessingException e) {
            throw new ApiClientException(
                    "AI_RESPONSE_INVALID",
                    HttpStatus.BAD_GATEWAY,
                    "AI 해석 결과를 읽지 못했습니다. 잠시 후 다시 시도해주세요."
            );
        }
    }

    private Map<String, Object> parseModelJson(String text) {
        String normalized = normalizeJsonText(text);
        try {
            Map<String, Object> parsed = objectMapper.readValue(normalized, new TypeReference<>() {});
            return new LinkedHashMap<>(parsed);
        } catch (JsonProcessingException e) {
            log.warn("failed to parse gemini json: {}", normalized);
            throw new ApiClientException(
                    "AI_RESPONSE_INVALID",
                    HttpStatus.BAD_GATEWAY,
                    "AI 해석 결과를 읽지 못했습니다. 잠시 후 다시 시도해주세요."
            );
        }
    }

    private String normalizeJsonText(String text) {
        String trimmed = text == null ? "" : text.trim();
        if (trimmed.startsWith("```")) {
            String withoutFence = trimmed.replaceFirst("^```[a-zA-Z]*\\n?", "");
            withoutFence = withoutFence.replaceFirst("\\n?```$", "");
            return withoutFence.trim();
        }
        return trimmed;
    }

    private String valueOrDash(String value) {
        if (value == null || value.trim().isEmpty()) {
            return "-";
        }
        return value.trim();
    }

    private String trimTrailingSlash(String value) {
        if (value.endsWith("/")) {
            return value.substring(0, value.length() - 1);
        }
        return value;
    }
}
