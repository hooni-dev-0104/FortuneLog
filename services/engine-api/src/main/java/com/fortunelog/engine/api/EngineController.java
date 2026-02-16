package com.fortunelog.engine.api;

import com.fortunelog.engine.application.EngineService;
import com.fortunelog.engine.application.EngineVersion;
import com.fortunelog.engine.application.dto.CalculateChartRequest;
import com.fortunelog.engine.application.dto.GenerateDailyFortuneRequest;
import com.fortunelog.engine.application.dto.GenerateReportRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.core.env.Environment;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/engine/v1")
public class EngineController {

    private final EngineService engineService;
    private final Environment env;

    public EngineController(EngineService engineService, Environment env) {
        this.engineService = engineService;
        this.env = env;
    }

    @PostMapping("/charts:calculate")
    @ResponseStatus(HttpStatus.OK)
    public Map<String, Object> calculateChart(
            @Valid @RequestBody CalculateChartRequest request,
            @AuthenticationPrincipal Jwt jwt,
            HttpServletRequest httpRequest
    ) {
        var result = engineService.calculateChart(jwt.getSubject(), request);
        return Map.of(
                "requestId", requestId(httpRequest),
                "chartId", result.chartId(),
                "engineVersion", result.engineVersion(),
                "chart", result.chart(),
                "fiveElements", result.fiveElements()
        );
    }

    @PostMapping("/reports:generate")
    @ResponseStatus(HttpStatus.OK)
    public Map<String, Object> generateReport(
            @Valid @RequestBody GenerateReportRequest request,
            @AuthenticationPrincipal Jwt jwt,
            HttpServletRequest httpRequest
    ) {
        var result = engineService.generateReport(jwt.getSubject(), request);
        return Map.of(
                "requestId", requestId(httpRequest),
                "chartId", result.chartId(),
                "reportType", result.reportType(),
                "content", result.content()
        );
    }

    @PostMapping("/fortunes:daily")
    @ResponseStatus(HttpStatus.OK)
    public Map<String, Object> generateDailyFortune(
            @Valid @RequestBody GenerateDailyFortuneRequest request,
            @AuthenticationPrincipal Jwt jwt,
            HttpServletRequest httpRequest
    ) {
        var result = engineService.generateDailyFortune(jwt.getSubject(), request);
        return Map.of(
                "requestId", requestId(httpRequest),
                "userId", result.userId(),
                "date", result.date().toString(),
                "score", result.score(),
                "summary", result.summary(),
                "category", result.category(),
                "categoryDetails", result.categoryDetails(),
                "actions", result.actions()
        );
    }

    @GetMapping("/health")
    public Map<String, Object> health(HttpServletRequest httpRequest) {
        boolean insecureJwt = Boolean.parseBoolean(env.getProperty("ENGINE_INSECURE_JWT", "false"));
        boolean authDebug = Boolean.parseBoolean(env.getProperty("ENGINE_AUTH_DEBUG", "false"));
        String jwkSetUri = env.getProperty("spring.security.oauth2.resourceserver.jwt.jwk-set-uri", "");

        return Map.of(
                "requestId", requestId(httpRequest),
                "status", "ok",
                "engineVersion", EngineVersion.CURRENT,
                "security", Map.of(
                        "insecureJwt", insecureJwt,
                        "authDebug", authDebug
                ),
                "jwkSetUri", jwkSetUri
        );
    }

    private String requestId(HttpServletRequest request) {
        Object value = request.getAttribute("requestId");
        return value == null ? "" : value.toString();
    }
}
