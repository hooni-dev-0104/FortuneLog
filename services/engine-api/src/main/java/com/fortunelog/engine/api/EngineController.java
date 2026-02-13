package com.fortunelog.engine.api;

import com.fortunelog.engine.application.EngineService;
import com.fortunelog.engine.application.dto.CalculateChartRequest;
import com.fortunelog.engine.application.dto.GenerateDailyFortuneRequest;
import com.fortunelog.engine.application.dto.GenerateReportRequest;
import com.fortunelog.engine.domain.model.ChartResult;
import com.fortunelog.engine.domain.model.DailyFortuneResult;
import com.fortunelog.engine.domain.model.ReportResult;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/engine/v1")
public class EngineController {

    private final EngineService engineService;

    public EngineController(EngineService engineService) {
        this.engineService = engineService;
    }

    @PostMapping("/charts:calculate")
    @ResponseStatus(HttpStatus.OK)
    public ChartResult calculateChart(@Valid @RequestBody CalculateChartRequest request) {
        return engineService.calculateChart(request);
    }

    @PostMapping("/reports:generate")
    @ResponseStatus(HttpStatus.OK)
    public ReportResult generateReport(@Valid @RequestBody GenerateReportRequest request) {
        return engineService.generateReport(request);
    }

    @PostMapping("/fortunes:daily")
    @ResponseStatus(HttpStatus.OK)
    public DailyFortuneResult generateDailyFortune(@Valid @RequestBody GenerateDailyFortuneRequest request) {
        return engineService.generateDailyFortune(request);
    }

    @GetMapping("/health")
    public String health() {
        return "ok";
    }
}
