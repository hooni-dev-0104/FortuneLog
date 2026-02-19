package com.fortunelog.engine.application;

import com.fortunelog.engine.application.dto.CalculateChartRequest;
import com.fortunelog.engine.application.dto.GenerateAiInterpretationRequest;
import com.fortunelog.engine.application.dto.GenerateDailyFortuneRequest;
import com.fortunelog.engine.application.dto.GenerateReportRequest;
import com.fortunelog.engine.common.ApiClientException;
import com.fortunelog.engine.domain.LunarDateConverter;
import com.fortunelog.engine.domain.SajuCalculator;
import com.fortunelog.engine.domain.model.ChartResult;
import com.fortunelog.engine.domain.model.DailyCategoryDetail;
import com.fortunelog.engine.domain.model.DailyFortuneResult;
import com.fortunelog.engine.domain.model.ReportResult;
import com.fortunelog.engine.infra.llm.GeminiAnalysisClient;
import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;
import org.springframework.http.HttpStatus;
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
    private final GeminiAnalysisClient geminiAnalysisClient;

    public EngineService(
            SupabasePersistenceService persistenceService,
            GeminiAnalysisClient geminiAnalysisClient
    ) {
        this.persistenceService = persistenceService;
        this.geminiAnalysisClient = geminiAnalysisClient;
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
                EngineVersion.CURRENT
        );

        return new ChartResult(chartId, EngineVersion.CURRENT, chart.chart(), chart.fiveElements());
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
        // MVP: canned content. Next iteration should use chart/five-elements + target date.
        Map<String, String> category = Map.of(
                "money", "지출 관리가 성과로 이어지는 하루입니다.",
                "love", "관계는 속도보다 톤 조절이 중요합니다.",
                "work", "오전 집중, 오후 정리가 유리합니다.",
                "health", "컨디션은 수면/수분이 좌우합니다."
        );

        Map<String, DailyCategoryDetail> details = Map.of(
                "money", new DailyCategoryDetail(
                        72,
                        "소액 반복 지출이 누적되기 쉬워요.",
                        List.of("필수 지출만 남기면 마음이 편해집니다.", "작은 절약이 하루의 주도권을 줍니다."),
                        List.of("충동 구매", "구독/배달 같은 자동 지출"),
                        List.of("오늘 예산 상한 1개 정하기", "구독 1개 점검하기")
                ),
                "love", new DailyCategoryDetail(
                        70,
                        "연애/결혼 모두 '말투'가 핵심입니다.",
                        List.of("상대 입장을 요약해 주면 갈등이 줄어듭니다.", "연락 타이밍은 '짧게, 자주'가 좋아요."),
                        List.of("단정적인 표현", "감정 누적 후 폭발"),
                        List.of("요청은 한 문장으로", "대화 전 10초 멈춤")
                ),
                "work", new DailyCategoryDetail(
                        78,
                        "가장 잘 풀리는 시간대를 선점하세요.",
                        List.of("짧은 집중 블록이 성과를 만듭니다.", "정리 시간이 있으면 피로가 줄어요."),
                        List.of("멀티태스킹", "오후에 중요한 의사결정"),
                        List.of("오전 90분 집중 블록", "오늘 Top3만 완료")
                ),
                "health", new DailyCategoryDetail(
                        68,
                        "회복이 곧 생산성입니다.",
                        List.of("가벼운 움직임이 머리를 맑게 해요.", "수분을 챙기면 피로가 덜합니다."),
                        List.of("수면 부족", "카페인 과다"),
                        List.of("물 2잔 먼저", "저녁 20분 산책")
                )
        );

        String summary = "실행력은 좋지만, 컨디션과 지출 관리가 관건입니다.";
        List<String> actions = List.of(
                "오늘 예산 상한 정하기",
                "오전 90분 집중 블록 만들기",
                "저녁 20분 산책"
        );

        persistenceService.upsertDailyFortuneReport(
                userId,
                request.chartId(),
                LocalDate.parse(request.date()),
                Map.of(
                        "date", request.date(),
                        "score", 74,
                        "summary", summary,
                        "category", category,
                        "categoryDetails", details,
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
                details,
                summary,
                actions
        );
    }

    public ReportResult generateAiInterpretation(String userId, GenerateAiInterpretationRequest request) {
        var snapshot = persistenceService.findChartSnapshot(userId, request.chartId());
        if (snapshot == null) {
            throw new ApiClientException(
                    "CHART_NOT_FOUND",
                    HttpStatus.NOT_FOUND,
                    "사주 차트를 먼저 계산해주세요."
            );
        }

        Map<String, Object> content = geminiAnalysisClient.generateSajuInterpretation(
                snapshot.chart(),
                snapshot.fiveElements()
        );

        persistenceService.upsertNonDailyReport(
                userId,
                request.chartId(),
                "ai_interpretation",
                content,
                true,
                true
        );

        return new ReportResult(request.chartId(), "ai_interpretation", content);
    }
}
