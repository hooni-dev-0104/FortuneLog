package com.fortunelog.engine.application;

import com.fortunelog.engine.application.dto.CalculateChartRequest;
import com.fortunelog.engine.application.dto.GenerateDailyFortuneRequest;
import com.fortunelog.engine.application.dto.GenerateReportRequest;
import com.fortunelog.engine.domain.SajuCalculator;
import com.fortunelog.engine.domain.model.ChartResult;
import com.fortunelog.engine.domain.model.DailyFortuneResult;
import com.fortunelog.engine.domain.model.ReportResult;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

@Service
public class EngineService {

    private static final DateTimeFormatter BIRTH_TIME_FORMATTER = DateTimeFormatter.ofPattern("H:mm");

    private final SajuCalculator sajuCalculator = new SajuCalculator();

    public ChartResult calculateChart(CalculateChartRequest request) {
        LocalDate birthDate = LocalDate.parse(request.birthDate());
        LocalTime birthTime = request.unknownBirthTime()
                ? LocalTime.NOON
                : LocalTime.parse(request.birthTime(), BIRTH_TIME_FORMATTER);
        LocalDateTime birthDateTime = LocalDateTime.of(birthDate, birthTime);

        SajuCalculator.SajuChart chart = sajuCalculator.calculate(
                birthDateTime,
                request.unknownBirthTime(),
                request.calendarType()
        );

        return new ChartResult("v0.1.0", chart.chart(), chart.fiveElements());
    }

    public ReportResult generateReport(GenerateReportRequest request) {
        return new ReportResult(
                request.chartId(),
                request.reportType(),
                Map.of(
                        "summary", "실행력은 강하지만 과부하 관리가 핵심입니다.",
                        "strengths", List.of("빠른 판단", "높은 집중력"),
                        "cautions", List.of("무리한 일정", "감정 과열"),
                        "actions", List.of("오늘 1개 우선순위만 완료", "오후 30분 회복 시간 확보")
                )
        );
    }

    public DailyFortuneResult generateDailyFortune(GenerateDailyFortuneRequest request) {
        return new DailyFortuneResult(
                request.userId(),
                LocalDate.parse(request.date()),
                74,
                Map.of(
                        "love", "대화의 온도를 낮추면 관계가 안정됩니다.",
                        "work", "집중 시간대를 오전에 배치하세요.",
                        "money", "소액 반복 지출 점검이 유리합니다.",
                        "health", "수면 리듬을 우선 복구하세요."
                ),
                List.of(
                        "중요한 결정은 오후로 미루기",
                        "오늘의 지출 상한 정하기",
                        "저녁 20분 산책"
                )
        );
    }
}
