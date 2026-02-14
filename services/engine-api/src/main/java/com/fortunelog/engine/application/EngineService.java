package com.fortunelog.engine.application;

import com.fortunelog.engine.application.dto.CalculateChartRequest;
import com.fortunelog.engine.application.dto.GenerateDailyFortuneRequest;
import com.fortunelog.engine.application.dto.GenerateReportRequest;
import com.fortunelog.engine.domain.LunarDateConverter;
import com.fortunelog.engine.domain.SajuCalculator;
import com.fortunelog.engine.domain.model.ChartResult;
import com.fortunelog.engine.domain.model.DailyFortuneResult;
import com.fortunelog.engine.domain.model.ReportResult;
import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

@Service
public class EngineService {

    private static final DateTimeFormatter BIRTH_TIME_FORMATTER = DateTimeFormatter.ofPattern("H:mm");

    private final SajuCalculator sajuCalculator = new SajuCalculator();
    private final LunarDateConverter lunarDateConverter = new LunarDateConverter();
    private final SupabasePersistenceService persistenceService;

    public EngineService(SupabasePersistenceService persistenceService) {
        this.persistenceService = persistenceService;
    }

    public ChartResult calculateChart(String userId, CalculateChartRequest request) {
        LocalDate birthDate = resolveSolarBirthDate(request);
        LocalTime birthTime = request.unknownBirthTime()
                ? LocalTime.NOON
                : LocalTime.parse(request.birthTime(), BIRTH_TIME_FORMATTER);

        // Treat input date/time as local time in the provided timezone, then compare solar term boundaries in KST.
        ZoneId inputZone = ZoneId.of(request.birthTimezone());
        ZonedDateTime inputZdt = LocalDateTime.of(birthDate, birthTime).atZone(inputZone);
        ZonedDateTime kstZdt = inputZdt.withZoneSameInstant(ZoneId.of("Asia/Seoul"));

        SajuCalculator.SajuChart chart = sajuCalculator.calculate(
                kstZdt.toLocalDateTime(),
                request.unknownBirthTime()
        );

        String chartId = persistenceService.insertSajuChart(
                userId,
                request.birthProfileId(),
                chart.chart(),
                chart.fiveElements(),
                "v0.1.0"
        );

        return new ChartResult(chartId, "v0.1.0", chart.chart(), chart.fiveElements());
    }

    private LocalDate resolveSolarBirthDate(CalculateChartRequest request) {
        LocalDate inputDate = LocalDate.parse(request.birthDate());
        if ("solar".equalsIgnoreCase(request.calendarType())) {
            if (request.leapMonth()) {
                throw new IllegalArgumentException("leapMonth can be true only when calendarType is lunar");
            }
            return inputDate;
        }
        if ("lunar".equalsIgnoreCase(request.calendarType())) {
            try {
                return lunarDateConverter.toSolarDate(
                        inputDate.getYear(),
                        inputDate.getMonthValue(),
                        inputDate.getDayOfMonth(),
                        request.leapMonth()
                );
            } catch (IllegalArgumentException e) {
                throw new IllegalArgumentException("invalid lunar birthDate/leapMonth: " + e.getMessage(), e);
            }
        }
        throw new IllegalArgumentException("unsupported calendar type: " + request.calendarType());
    }

    public ReportResult generateReport(String userId, GenerateReportRequest request) {
        Map<String, Object> content = Map.of(
                "summary", "실행력은 강하지만 과부하 관리가 핵심입니다.",
                "strengths", List.of("빠른 판단", "높은 집중력"),
                "cautions", List.of("무리한 일정", "감정 과열"),
                "actions", List.of("오늘 1개 우선순위만 완료", "오후 30분 회복 시간 확보")
        );

        persistenceService.upsertNonDailyReport(
                userId,
                request.chartId(),
                request.reportType(),
                content,
                true,
                true
        );

        return new ReportResult(request.chartId(), request.reportType(), content);
    }

    public DailyFortuneResult generateDailyFortune(String userId, GenerateDailyFortuneRequest request) {
        Map<String, String> category = Map.of(
                "love", "대화의 온도를 낮추면 관계가 안정됩니다.",
                "work", "집중 시간대를 오전에 배치하세요.",
                "money", "소액 반복 지출 점검이 유리합니다.",
                "health", "수면 리듬을 우선 복구하세요."
        );
        List<String> actions = List.of(
                "중요한 결정은 오후로 미루기",
                "오늘의 지출 상한 정하기",
                "저녁 20분 산책"
        );

        persistenceService.upsertDailyFortuneReport(
                userId,
                request.chartId(),
                LocalDate.parse(request.date()),
                Map.of(
                        "date", request.date(),
                        "score", 74,
                        "category", category,
                        "actions", actions
                ),
                false,
                true
        );

        return new DailyFortuneResult(
                userId,
                LocalDate.parse(request.date()),
                74,
                category,
                actions
        );
    }
}
