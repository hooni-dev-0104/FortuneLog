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
import java.net.http.HttpTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class GeminiAnalysisClient {

    private static final Logger log = LoggerFactory.getLogger(GeminiAnalysisClient.class);
    private static final String AI_PARSE_ERROR_MESSAGE = "AI 해석 결과를 읽지 못했습니다. 잠시 후 다시 시도해주세요.";

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
            @Value("${app.gemini.request-timeout-ms:${GEMINI_REQUEST_TIMEOUT_MS:60000}}") long requestTimeoutMs
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

        try {
            CandidatePayload primary = callGemini(buildPrompt(chart, fiveElements, false), false);
            Map<String, Object> parsed = parseModelJson(primary.text());
            return enrichResult(parsed);
        } catch (ApiClientException ex) {
            if (isRecoverableAiFailure(ex.code())) {
                log.warn("gemini unavailable/invalid response. falling back to deterministic interpretation. code={}", ex.code());
                return enrichFallbackResult(buildFallbackInterpretation(chart, fiveElements));
            }
            throw ex;
        }
    }

    private Map<String, Object> enrichResult(Map<String, Object> parsed) {
        parsed.put("model", model);
        parsed.put("generatedAt", Instant.now().toString());
        parsed.put("source", "gemini");
        return parsed;
    }

    private Map<String, Object> enrichFallbackResult(Map<String, Object> parsed) {
        parsed.put("model", model);
        parsed.put("generatedAt", Instant.now().toString());
        parsed.put("source", "fallback");
        return parsed;
    }

    private boolean isRecoverableAiFailure(String code) {
        return "AI_GENERATION_FAILED".equals(code)
                || "AI_GENERATION_TIMEOUT".equals(code)
                || "AI_RESPONSE_INVALID".equals(code);
    }

    private Map<String, Object> buildFallbackInterpretation(Map<String, String> chart, Map<String, Integer> fiveElements) {
        String day = valueOrDash(chart.get("day"));
        String dominant = dominantElement(fiveElements);
        String weak = weakestElement(fiveElements);
        String dominantKo = elementKo(dominant);
        String weakKo = elementKo(weak);

        Map<String, Object> themes = Map.of(
                "money", dominantKo + " 기운이 금전 감각을 살립니다. " + weakKo + " 기운 보완을 위해 지출 기준을 먼저 정해보세요.",
                "relationship", dominantKo + " 기운으로 표현력이 살아납니다. 관계에서는 속도보다 톤 조절이 유리합니다.",
                "career", dominantKo + " 기운이 실행력을 올립니다. 일주(" + day + ") 흐름상 우선순위 1개 집중이 효과적입니다.",
                "health", weakKo + " 기운이 약할 수 있어 회복 루틴이 중요합니다. 수면·수분 관리를 먼저 챙겨주세요."
        );
        return new LinkedHashMap<>(Map.of(
                "summary", dominantKo + " 중심 기운이 강해 핵심 과제에 집중할 때 성과가 잘 나는 편입니다. "
                        + "반면 " + weakKo + " 기운이 상대적으로 약해 감정 소모와 체력 저하가 누적되기 쉬울 수 있습니다. "
                        + "관계에서는 속도보다 말의 온도와 표현 순서를 조절하는 것이 안정적입니다. "
                        + "일/직업 영역은 우선순위를 좁혀 실행하면 강점이 더 또렷하게 드러납니다. "
                        + "금전은 지출 기준을 먼저 정하면 불필요한 소비를 줄이는 데 도움이 됩니다. "
                        + "건강은 수면·수분·가벼운 움직임 루틴을 고정하면 전체 흐름이 더 좋아집니다.",
                "coreTraits", List.of(
                        dominantKo + " 기운 중심의 추진력",
                        "현실적인 판단과 적응력",
                        "흐름을 읽고 속도를 조절하는 성향"
                ),
                "strengths", List.of(
                        "핵심 과제에 빠르게 집중",
                        "상황 변화에 맞춘 실행력",
                        "반복 루틴을 통한 안정적인 성과"
                ),
                "cautions", List.of(
                        weakKo + " 기운 부족으로 인한 피로 누적",
                        "동시에 많은 일을 벌여 집중이 분산되는 흐름",
                        "감정 표현이 급해지며 톤이 강해지는 반응"
                ),
                "themes", themes,
                "actionTips", List.of(
                        "오늘 가장 중요한 일 1개부터 완료하기",
                        "지출 상한을 먼저 정하고 소비하기",
                        "저녁에는 20분 회복 시간 확보하기"
                ),
                "disclaimer", "본 해석은 참고용이며, 중요한 결정은 전문가 상담과 함께 판단해주세요."
        ));
    }

    private String dominantElement(Map<String, Integer> fiveElements) {
        String dominant = "earth";
        int max = Integer.MIN_VALUE;
        for (var e : fiveElements.entrySet()) {
            int value = e.getValue() == null ? 0 : e.getValue();
            if (value > max) {
                max = value;
                dominant = e.getKey();
            }
        }
        return dominant;
    }

    private String weakestElement(Map<String, Integer> fiveElements) {
        String weak = "fire";
        int min = Integer.MAX_VALUE;
        for (var e : fiveElements.entrySet()) {
            int value = e.getValue() == null ? 0 : e.getValue();
            if (value < min) {
                min = value;
                weak = e.getKey();
            }
        }
        return weak;
    }

    private String elementKo(String element) {
        return switch (element) {
            case "wood" -> "목";
            case "fire" -> "화";
            case "earth" -> "토";
            case "metal" -> "금";
            case "water" -> "수";
            default -> "-";
        };
    }

    private CandidatePayload callGemini(String prompt, boolean conciseMode) {
        String requestBody = buildRequestBody(prompt, conciseMode);
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
        } catch (HttpTimeoutException e) {
            log.warn("gemini call timeout: {}", e.getMessage());
            throw new ApiClientException(
                    "AI_GENERATION_TIMEOUT",
                    HttpStatus.BAD_GATEWAY,
                    "AI 해석 생성 시간이 초과되었습니다. 잠시 후 다시 시도해주세요."
            );
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.warn("gemini call interrupted: {}", e.getMessage());
            throw new ApiClientException(
                    "AI_GENERATION_FAILED",
                    HttpStatus.BAD_GATEWAY,
                    "AI 해석 생성에 실패했습니다. 잠시 후 다시 시도해주세요."
            );
        } catch (IOException e) {
            log.warn("gemini call failed before response: {}", e.toString());
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

        return extractCandidatePayload(response.body());
    }

    private String buildRequestBody(String prompt, boolean conciseMode) {
        Map<String, Object> payload = new LinkedHashMap<>(Map.of(
                "contents", List.of(
                        Map.of(
                                "role", "user",
                                "parts", List.of(Map.of("text", prompt))
                        )
                )
        ));
        payload.put("generationConfig", new LinkedHashMap<>(Map.of(
                "temperature", conciseMode ? 0.35 : 0.7,
                "topP", 0.9,
                "maxOutputTokens", conciseMode ? 1536 : 3072,
                "responseMimeType", "application/json",
                "responseSchema", buildResponseSchema()
        )));

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

    private Map<String, Object> buildResponseSchema() {
        Map<String, Object> stringArray = Map.of(
                "type", "ARRAY",
                "items", Map.of("type", "STRING")
        );
        Map<String, Object> themes = Map.of(
                "type", "OBJECT",
                "properties", Map.of(
                        "money", Map.of("type", "STRING"),
                        "relationship", Map.of("type", "STRING"),
                        "career", Map.of("type", "STRING"),
                        "health", Map.of("type", "STRING")
                ),
                "required", List.of("money", "relationship", "career", "health")
        );

        return Map.of(
                "type", "OBJECT",
                "properties", Map.of(
                        "summary", Map.of("type", "STRING"),
                        "coreTraits", stringArray,
                        "strengths", stringArray,
                        "cautions", stringArray,
                        "themes", themes,
                        "actionTips", stringArray,
                        "disclaimer", Map.of("type", "STRING")
                ),
                "required", List.of(
                        "summary",
                        "coreTraits",
                        "strengths",
                        "cautions",
                        "themes",
                        "actionTips",
                        "disclaimer"
                )
        );
    }

    private String buildPrompt(Map<String, String> chart, Map<String, Integer> fiveElements, boolean conciseMode) {
        String year = valueOrDash(chart.get("year"));
        String month = valueOrDash(chart.get("month"));
        String day = valueOrDash(chart.get("day"));
        String hour = valueOrDash(chart.get("hour"));

        int wood = fiveElements.getOrDefault("wood", 0);
        int fire = fiveElements.getOrDefault("fire", 0);
        int earth = fiveElements.getOrDefault("earth", 0);
        int metal = fiveElements.getOrDefault("metal", 0);
        int water = fiveElements.getOrDefault("water", 0);
        String styleRule = conciseMode
                ? "모든 문장을 짧고 간결하게 작성하고, 각 항목은 1문장 또는 짧은 구문으로 제한하세요."
                : "초보자도 이해하기 쉬운 문장으로 작성하세요.";

        return """
                당신은 한국어로 설명하는 사주 전문 상담가입니다.
                입력된 사주팔자와 오행 분포를 바탕으로 해석하세요.
                단정적인 예언/의학 진단/투자 확언은 피하고, 현실적인 조언 위주로 작성하세요.
                %s

                [입력 데이터]
                - 년주: %s
                - 월주: %s
                - 일주: %s
                - 시주: %s
                - 오행: 목=%d, 화=%d, 토=%d, 금=%d, 수=%d
                - 해석 규칙: 일간=일주의 천간, 월지=월주의 지지

                [질문 사항]
                위 데이터를 바탕으로 명리학 전문가의 관점에서 다음 사항을 상세히 분석해 주십시오.
                1. 일간과 일주를 중심으로 본연의 기질과 중심 성격을 설명해 주십시오.
                2. 월지에 배정된 기운과 전체적인 십성의 흐름을 바탕으로, 이 사주가 사회에서 어떤 환경에 놓이기 쉬우며 어떤 방식으로 역량을 발휘하는지 분석해 주십시오.
                3. 주어진 십성 구성에서 나타나는 특징적인 장단점과 그에 따른 인생 흐름의 특성을 분석해 주십시오.
                4. 제공된 오행 분포 수치를 절대적 기준으로 삼아, 부족하거나 과한 기운을 조절할 수 있는 실생활의 보완책(색상, 습관 등)을 제안해 주십시오.
                5. 재물운, 연애·결혼운, 직업 적성, 건강운 등 주요 영역을 주어진 데이터를 근거로 종합 해석해 주십시오.
                6. 전체적인 사주 구성의 균형을 맞추기 위해 이 사주가 지향해야 할 삶의 태도와 핵심적인 조언을 들려주십시오.

                [출력 작성 가이드]
                - 반드시 입력 데이터 근거를 포함해 설명하세요(일간/일주/월지/오행 수치 반영).
                - 너무 일반적인 운세 문구를 피하고, 조건과 맥락을 분명하게 제시하세요.
                - summary는 2~3개 문단으로 충분히 상세하게 작성하세요.
                - coreTraits/strengths/cautions/actionTips는 각각 최소 5개 항목으로 작성하세요.
                - themes의 money/relationship/career/health는 각각 3~5문장으로 작성하세요.
                - actionTips에는 색상, 생활습관, 루틴, 환경 정리 등 실천 가능한 보완책을 포함하세요.

                아래 JSON 스키마로만 응답하세요. 키 이름은 그대로 유지하고, 값은 한국어로 작성하세요.
                {
                  "summary": "종합 요약 (2~3개 문단, 질문 1~3·6을 중심으로 상세히)",
                  "coreTraits": ["기질/성격 포인트 1", "기질/성격 포인트 2", "기질/성격 포인트 3", "기질/성격 포인트 4", "기질/성격 포인트 5"],
                  "strengths": ["강점/발휘 조건 1", "강점/발휘 조건 2", "강점/발휘 조건 3", "강점/발휘 조건 4", "강점/발휘 조건 5"],
                  "cautions": ["약점/리스크 1", "약점/리스크 2", "약점/리스크 3", "약점/리스크 4", "약점/리스크 5"],
                  "themes": {
                    "money": "재물운 상세 해석 (근거 포함)",
                    "relationship": "연애/결혼운 상세 해석 (근거 포함)",
                    "career": "직업 적성/일운 상세 해석 (근거 포함)",
                    "health": "건강운 상세 해석 (근거 포함)"
                  },
                  "actionTips": ["보완 실천 팁 1", "보완 실천 팁 2", "보완 실천 팁 3", "보완 실천 팁 4", "보완 실천 팁 5"],
                  "disclaimer": "참고용 안내 문구 1문장"
                }
                """.formatted(styleRule, year, month, day, hour, wood, fire, earth, metal, water);
    }

    private CandidatePayload extractCandidatePayload(String responseBody) {
        try {
            JsonNode root = objectMapper.readTree(responseBody);
            JsonNode textNode = root.at("/candidates/0/content/parts/0/text");
            if (textNode.isMissingNode() || textNode.asText().isBlank()) {
                throw new ApiClientException(
                        "AI_RESPONSE_INVALID",
                        HttpStatus.BAD_GATEWAY,
                        AI_PARSE_ERROR_MESSAGE
                );
            }
            String finishReason = root.at("/candidates/0/finishReason").asText("");
            return new CandidatePayload(textNode.asText(), finishReason);
        } catch (JsonProcessingException e) {
            throw new ApiClientException(
                    "AI_RESPONSE_INVALID",
                    HttpStatus.BAD_GATEWAY,
                    AI_PARSE_ERROR_MESSAGE
            );
        }
    }

    private Map<String, Object> parseModelJson(String text) {
        String normalized = normalizeJsonText(text);
        List<String> candidates = new ArrayList<>();
        candidates.add(normalized);
        String extracted = extractOuterJsonObject(normalized);
        if (extracted != null && !extracted.equals(normalized)) {
            candidates.add(extracted);
        }

        for (String candidate : candidates) {
            String sanitized = stripTrailingCommas(candidate);
            try {
                Map<String, Object> parsed = objectMapper.readValue(sanitized, new TypeReference<>() {});
                return new LinkedHashMap<>(parsed);
            } catch (JsonProcessingException ignored) {
                // try next candidate
            }
        }

        log.warn("failed to parse gemini json: {}", normalized);
        throw new ApiClientException(
                "AI_RESPONSE_INVALID",
                HttpStatus.BAD_GATEWAY,
                AI_PARSE_ERROR_MESSAGE
        );
    }

    private String normalizeJsonText(String text) {
        String trimmed = text == null ? "" : text.trim();
        if (trimmed.startsWith("```")) {
            String withoutFence = trimmed.replaceFirst("^```[a-zA-Z]*\\n?", "");
            withoutFence = withoutFence.replaceFirst("\\n?```$", "");
            return withoutFence.trim();
        }
        return trimmed.replace("\uFEFF", "");
    }

    private String extractOuterJsonObject(String text) {
        int start = text.indexOf('{');
        int end = text.lastIndexOf('}');
        if (start < 0 || end <= start) {
            return null;
        }
        return text.substring(start, end + 1).trim();
    }

    private String stripTrailingCommas(String text) {
        return text.replaceAll(",\\s*([}\\]])", "$1");
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

    private record CandidatePayload(String text, String finishReason) {
    }
}
