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
                  "candidates": [
                    {
                      "content": {
                        "parts": [
                          {
                            "text": "{\\"summary\\":\\"요약\\",\\"coreTraits\\":[\\"성향1\\",\\"성향2\\"],\\"actionTips\\":[\\"실행1\\"]}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """));

        GeminiAnalysisClient client = new GeminiAnalysisClient(
                new ObjectMapper(),
                "test-key",
                "gemini-2.5-flash",
                server.url("/").toString(),
                5000
        );

        Map<String, Object> result = client.generateSajuInterpretation(
                Map.of("year", "갑자", "month", "을축", "day", "병인", "hour", "정묘"),
                Map.of("wood", 2, "fire", 1, "earth", 2, "metal", 1, "water", 2)
        );

        assertEquals("요약", result.get("summary"));
        assertTrue(result.containsKey("generatedAt"));
        assertEquals("gemini-2.5-flash", result.get("model"));
        assertEquals("gemini", result.get("source"));

        RecordedRequest request = server.takeRequest();
        assertTrue(request.getPath().contains("/v1beta/models/gemini-2.5-flash:generateContent"));
        assertTrue(request.getPath().contains("key=test-key"));
        assertTrue(request.getBody().readUtf8().contains("\"responseMimeType\":\"application/json\""));
    }

    @Test
    void shouldThrowWhenApiKeyIsMissing() {
        GeminiAnalysisClient client = new GeminiAnalysisClient(
                new ObjectMapper(),
                "",
                "gemini-2.5-flash",
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
    void shouldRetryWithConcisePromptWhenFirstResponseJsonIsTruncated() throws Exception {
        server.enqueue(new MockResponse().setResponseCode(200).setBody("""
                {
                  "candidates": [
                    {
                      "finishReason": "MAX_TOKENS",
                      "content": {
                        "parts": [
                          {
                            "text": "{\\"summary\\":\\"요약\\",\\"coreTraits\\":[\\"성향1\\",\\"성향2\\"]"
                          }
                        ]
                      }
                    }
                  ]
                }
                """));
        server.enqueue(new MockResponse().setResponseCode(200).setBody("""
                {
                  "candidates": [
                    {
                      "finishReason": "STOP",
                      "content": {
                        "parts": [
                          {
                            "text": "{\\"summary\\":\\"재시도 요약\\",\\"coreTraits\\":[\\"성향1\\"],\\"strengths\\":[\\"강점1\\"],\\"cautions\\":[\\"주의1\\"],\\"themes\\":{\\"money\\":\\"금전\\",\\"relationship\\":\\"관계\\",\\"career\\":\\"직업\\",\\"health\\":\\"건강\\"},\\"fortuneByPeriod\\":{\\"year\\":\\"연\\",\\"month\\":\\"월\\",\\"week\\":\\"주\\",\\"day\\":\\"일\\"},\\"actionTips\\":[\\"실행1\\"],\\"disclaimer\\":\\"참고용\\"}"
                          }
                        ]
                      }
                    }
                  ]
                }
                """));

        GeminiAnalysisClient client = new GeminiAnalysisClient(
                new ObjectMapper(),
                "test-key",
                "gemini-2.5-flash",
                server.url("/").toString(),
                5000
        );

        Map<String, Object> result = client.generateSajuInterpretation(
                Map.of("year", "갑자", "month", "을축", "day", "병인", "hour", "정묘"),
                Map.of("wood", 2, "fire", 1, "earth", 2, "metal", 1, "water", 2)
        );

        assertEquals("재시도 요약", result.get("summary"));
        assertEquals("gemini-2.5-flash", result.get("model"));
        assertEquals("gemini", result.get("source"));
    }
}
