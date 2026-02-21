package com.fortunelog.engine.infra.llm;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fortunelog.engine.common.ApiClientException;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class GeminiAnalysisClientTest {

    private MockWebServer server;

    @BeforeEach
    void setUp() throws IOException {
        server = new MockWebServer();
        server.start();
    }

    @AfterEach
    void tearDown() throws IOException {
        server.shutdown();
    }

    @Test
    void shouldGenerateInterpretationFromGeminiResponse() throws Exception {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("""
                {
                  "choices": [
                    {
                      "finish_reason": "stop",
                      "message": {
                        "content": "{\\"summary\\":\\"요약\\",\\"coreTraits\\":[\\"성향1\\",\\"성향2\\"],\\"actionTips\\":[\\"실행1\\"],\\"strengths\\":[\\"강점1\\"],\\"cautions\\":[\\"주의1\\"],\\"themes\\":{\\"money\\":\\"m\\",\\"relationship\\":\\"r\\",\\"career\\":\\"c\\",\\"health\\":\\"h\\"},\\"disclaimer\\":\\"d\\"}"
                      }
                    }
                  ]
                }
                """));

        GeminiAnalysisClient client = new GeminiAnalysisClient(
                new ObjectMapper(),
                "test-key",
                "gpt-5-mini",
                server.url("/").toString(),
                5000
        );

        Map<String, Object> result = client.generateSajuInterpretation(
                Map.of("year", "갑자", "month", "을축", "day", "병인", "hour", "정묘"),
                Map.of("wood", 2, "fire", 1, "earth", 2, "metal", 1, "water", 2)
        );

        assertEquals("요약", result.get("summary"));
        assertTrue(result.containsKey("generatedAt"));
        assertEquals("gpt-5-mini", result.get("model"));
        assertEquals("openai", result.get("source"));

        RecordedRequest request = server.takeRequest();
        assertTrue(request.getPath().contains("/v1/chat/completions"));
        assertEquals("Bearer test-key", request.getHeader("Authorization"));
        final var body = request.getBody().readUtf8();
        assertTrue(body.contains("\"response_format\""));
        assertTrue(body.contains("\"json_schema\""));
    }

    @Test
    void shouldThrowWhenApiKeyIsMissing() {
        GeminiAnalysisClient client = new GeminiAnalysisClient(
                new ObjectMapper(),
                "",
                "gpt-5-mini",
                server.url("/").toString(),
                5000
        );

        try {
            client.generateSajuInterpretation(
                    Map.of("year", "갑자", "month", "을축", "day", "병인", "hour", "정묘"),
                    Map.of("wood", 2, "fire", 1, "earth", 2, "metal", 1, "water", 2)
            );
        } catch (ApiClientException e) {
            assertEquals("AI_CONFIG_MISSING", e.code());
            return;
        }
        throw new AssertionError("Expected ApiClientException");
    }

    @Test
    void shouldFallbackWhenGeminiResponseIsTruncated() {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("""
                {
                  "choices": [
                    {
                      "finish_reason": "length",
                      "message": {
                        "content": "{\\"summary\\":\\"요약\\",\\"coreTraits\\":[\\"성향1\\",\\"성향2\\"]"
                      }
                    }
                  ]
                }
                """));

        GeminiAnalysisClient client = new GeminiAnalysisClient(
                new ObjectMapper(),
                "test-key",
                "gpt-5-mini",
                server.url("/").toString(),
                5000
        );

        Map<String, Object> result = client.generateSajuInterpretation(
                Map.of("year", "갑자", "month", "을축", "day", "병인", "hour", "정묘"),
                Map.of("wood", 2, "fire", 1, "earth", 2, "metal", 1, "water", 2)
        );

        assertTrue(result.containsKey("summary"));
        assertEquals("gpt-5-mini", result.get("model"));
        assertEquals("fallback", result.get("source"));
    }

    @Test
    void shouldFallbackWhenGeminiReturnsInvalidJsonTwice() {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("""
                {
                  "choices": [
                    {
                      "finish_reason": "stop",
                      "message": {
                        "content": "{\\"summary\\":\\"broken\\" "
                      }
                    }
                  ]
                }
                """));
        server.enqueue(new MockResponse().setResponseCode(200).setBody("""
                {
                  "choices": [
                    {
                      "finish_reason": "stop",
                      "message": {
                        "content": "```json\\n{ not-json }\\n```"
                      }
                    }
                  ]
                }
                """));

        GeminiAnalysisClient client = new GeminiAnalysisClient(
                new ObjectMapper(),
                "test-key",
                "gpt-5-mini",
                server.url("/").toString(),
                5000
        );

        Map<String, Object> result = client.generateSajuInterpretation(
                Map.of("year", "갑자", "month", "을축", "day", "병인", "hour", "정묘"),
                Map.of("wood", 2, "fire", 1, "earth", 2, "metal", 1, "water", 2)
        );

        assertEquals("fallback", result.get("source"));
        assertEquals("gpt-5-mini", result.get("model"));
        assertTrue(result.containsKey("summary"));
        assertTrue(result.containsKey("themes"));
    }
}
