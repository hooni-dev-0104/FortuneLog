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
import com.fortunelog.engine.infra.llm.OpenAiAnalysisClient;
import com.fortunelog.engine.infra.supabase.SupabasePersistenceService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class EngineService {
    private static final Logger log = LoggerFactory.getLogger(EngineService.class);

    private static final DateTimeFormatter BIRTH_TIME_FORMATTER = DateTimeFormatter.ofPattern("H:mm");

    private final SajuCalculator sajuCalculator = new SajuCalculator();
    private final LunarDateConverter lunarDateConverter = new LunarDateConverter();
    private final SupabasePersistenceService persistenceService;
    private final OpenAiAnalysisClient openAiAnalysisClient;

    public EngineService(
            SupabasePersistenceService persistenceService,
            OpenAiAnalysisClient openAiAnalysisClient
    ) {
        this.persistenceService = persistenceService;
        this.openAiAnalysisClient = openAiAnalysisClient;
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
        LocalDate targetDate = LocalDate.parse(request.date());
        var snapshot = persistenceService.findChartSnapshot(userId, request.chartId());
        if (snapshot == null) {
            throw new ApiClientException(
                    "CHART_NOT_FOUND",
                    HttpStatus.NOT_FOUND,
                    "사주 차트를 먼저 계산해주세요."
            );
        }

        var fiveElements = snapshot.fiveElements();
        String dominant = dominantElement(fiveElements);
        String weak = weakestElement(fiveElements);
        String dayPillar = snapshot.chart().getOrDefault("day", "-");
        String chartSignature = String.join("|",
                snapshot.chart().getOrDefault("year", "-"),
                snapshot.chart().getOrDefault("month", "-"),
                snapshot.chart().getOrDefault("day", "-"),
                snapshot.chart().getOrDefault("hour", "-")
        );
        int variationNonce = (int) (System.nanoTime() & 0x7fffffff);

        int dayFactor = targetDate.getDayOfWeek().getValue() - 4; // -3 ~ +3
        int baseSeed = (request.chartId() + "|" + chartSignature + "|" + targetDate + "|" + variationNonce).hashCode();
        int baseScore = clamp(
                62
                        + fiveElements.getOrDefault(dominant, 0) * 3
                        - fiveElements.getOrDefault(weak, 0) * 2
                        + dayFactor
                        + jitter(baseSeed, -4, 4),
                48,
                92
        );

        int moneyScore = clamp(baseScore + categoryOffset(dominant, "money") + jitter(baseSeed ^ 0x11A, -5, 5), 45, 95);
        int loveScore = clamp(baseScore + categoryOffset(dominant, "love") + jitter(baseSeed ^ 0x22B, -5, 5), 45, 95);
        int workScore = clamp(baseScore + categoryOffset(dominant, "work") + jitter(baseSeed ^ 0x33C, -5, 5), 45, 95);
        int healthScore = clamp(baseScore + categoryOffset(dominant, "health") + jitter(baseSeed ^ 0x44D, -5, 5), 45, 95);

        Map<String, DailyCategoryDetail> details = Map.of(
                "money", buildDailyCategoryDetail("money", moneyScore, dominant, weak, dayPillar, baseSeed ^ 0x101),
                "love", buildDailyCategoryDetail("love", loveScore, dominant, weak, dayPillar, baseSeed ^ 0x202),
                "work", buildDailyCategoryDetail("work", workScore, dominant, weak, dayPillar, baseSeed ^ 0x303),
                "health", buildDailyCategoryDetail("health", healthScore, dominant, weak, dayPillar, baseSeed ^ 0x404)
        );

        Map<String, String> category = Map.of(
                "money", details.get("money").summary(),
                "love", details.get("love").summary(),
                "work", details.get("work").summary(),
                "health", details.get("health").summary()
        );

        int totalScore = clamp((moneyScore + loveScore + workScore + healthScore) / 4, 45, 95);
        String summaryLead = pickOne(List.of(
                "오늘은 흐름을 빠르게 타는 날입니다.",
                "오늘은 균형을 잡으면 성과가 커지는 날입니다.",
                "오늘은 선택과 집중이 잘 맞는 날입니다.",
                "오늘은 리듬을 정리할수록 운이 붙는 날입니다."
        ), baseSeed ^ 0x77A);
        String summary = summaryLead + " "
                + elementKo(dominant) + " 기운이 중심이 되고, "
                + "일주(" + dayPillar + ") 흐름상 " + elementKo(weak) + " 기운 보완이 포인트입니다.";
        List<String> actions = List.of(
                details.get("money").actions().get(0),
                details.get("love").actions().get(0),
                details.get("work").actions().get(0),
                details.get("health").actions().get(0)
        );

        persistenceService.upsertDailyFortuneReport(
                userId,
                request.chartId(),
                targetDate,
                Map.of(
                        "date", request.date(),
                        "score", totalScore,
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
                targetDate,
                totalScore,
                category,
                details,
                summary,
                actions
        );
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

    private int categoryOffset(String dominantElement, String category) {
        return switch (dominantElement) {
            case "wood" -> switch (category) {
                case "work" -> 3;
                case "health" -> 2;
                case "love" -> 1;
                default -> 0;
            };
            case "fire" -> switch (category) {
                case "love" -> 3;
                case "money" -> 2;
                case "work" -> 1;
                default -> -1;
            };
            case "earth" -> switch (category) {
                case "money" -> 3;
                case "health" -> 2;
                case "work" -> 1;
                default -> 0;
            };
            case "metal" -> switch (category) {
                case "money" -> 2;
                case "work" -> 2;
                case "health" -> 1;
                default -> 0;
            };
            case "water" -> switch (category) {
                case "work" -> 3;
                case "love" -> 2;
                case "money" -> 1;
                default -> 0;
            };
            default -> 0;
        };
    }

    private DailyCategoryDetail buildDailyCategoryDetail(
            String category,
            int score,
            String dominant,
            String weak,
            String dayPillar,
            int seed
    ) {
        String dominantKo = elementKo(dominant);
        String weakKo = elementKo(weak);
        String summary = switch (category) {
            case "money" -> pickOne(List.of(
                    dominantKo + " 기운이 자금 흐름을 움직입니다. " + weakKo + " 기운 보완이 지출 안정에 도움이 됩니다.",
                    dominantKo + " 기운이 수입/지출 판단을 빠르게 만듭니다. 무리한 지출만 피하면 안정적입니다.",
                    dominantKo + " 기운이 재무 결정의 속도를 올립니다. 작은 절약 습관이 특히 효과적입니다."
            ), seed ^ 0x701);
            case "love" -> pickOne(List.of(
                    dominantKo + " 기운이 대화의 온도를 높입니다. 감정 표현은 부드럽게 조절하는 편이 좋습니다.",
                    dominantKo + " 기운으로 관계 반응이 빨라집니다. 말의 톤을 한 단계 낮추면 더 좋습니다.",
                    dominantKo + " 기운이 관계 주도권을 줍니다. 상대 속도를 존중하면 흐름이 안정됩니다."
            ), seed ^ 0x702);
            case "work" -> pickOne(List.of(
                    dominantKo + " 기운으로 실행력이 살아납니다. 일주(" + dayPillar + ") 흐름상 우선순위 정리가 성과를 키웁니다.",
                    dominantKo + " 기운이 업무 추진력을 올립니다. 일주(" + dayPillar + ") 기준으론 멀티태스킹보다 단일 집중이 유리합니다.",
                    dominantKo + " 기운이 실행 속도를 밀어줍니다. 핵심 1개 과업부터 처리하면 효율이 좋습니다."
            ), seed ^ 0x703);
            case "health" -> pickOne(List.of(
                    dominantKo + " 기운이 활력을 주지만, " + weakKo + " 기운이 약하면 회복 루틴이 더 중요해집니다.",
                    dominantKo + " 기운으로 체력 반응이 빠릅니다. " + weakKo + " 기운 보완을 위해 수면·수분 관리가 핵심입니다.",
                    dominantKo + " 기운이 활동성을 높입니다. 과로를 막는 휴식 타이밍을 미리 잡아두세요."
            ), seed ^ 0x704);
            default -> "오늘의 흐름을 참고해 균형 있게 움직여보세요.";
        };

        List<String> goodPool = switch (category) {
            case "money" -> List.of(
                    "고정 지출을 정리하면 체감 여유가 생깁니다.",
                    "소액 절약이 누적 성과로 이어집니다.",
                    "수입/지출을 한 번에 보는 습관이 유리합니다.",
                    "가격 비교 후 하루 뒤 결제하면 실수가 줄어듭니다.",
                    "예산을 먼저 정하면 소비 만족도가 높아집니다."
            );
            case "love" -> List.of(
                    "짧고 따뜻한 표현이 관계를 안정시킵니다.",
                    "상대의 입장을 먼저 요약하면 오해가 줄어듭니다.",
                    "연락 리듬을 일정하게 가져가면 신뢰가 높아집니다.",
                    "즉답보다 맥락 설명이 관계를 부드럽게 만듭니다.",
                    "기대치를 짧게 공유하면 갈등이 줄어듭니다."
            );
            case "work" -> List.of(
                    "중요도 높은 1개 과업에 집중하면 성과가 빠릅니다.",
                    "오전 집중 블록이 생산성을 끌어올립니다.",
                    "핵심 결정은 근거를 짧게 정리해 공유하면 좋습니다.",
                    "반복 업무를 먼저 끝내면 오후 효율이 좋아집니다.",
                    "완벽함보다 완료 기준을 정하면 속도가 붙습니다."
            );
            case "health" -> List.of(
                    "가벼운 걷기와 스트레칭이 컨디션을 살립니다.",
                    "수분 섭취를 먼저 챙기면 피로가 완만해집니다.",
                    "식사 리듬을 일정하게 유지하면 집중력이 좋아집니다.",
                    "잠깐의 햇빛 노출이 생체 리듬을 돕습니다.",
                    "짧은 호흡 정리가 긴장 완화에 유리합니다."
            );
            default -> List.of("기본 루틴을 지키면 흐름이 안정됩니다.");
        };

        List<String> cautionPool = switch (category) {
            case "money" -> List.of(
                    "계획 없는 소액 결제 반복",
                    "즉흥적인 비교·추가 구매",
                    "구독/자동결제 점검 누락",
                    "할인 문구에 급히 반응하는 소비",
                    "단기 기분전환성 지출 누적"
            );
            case "love" -> List.of(
                    "단정적인 표현으로 말끝이 강해지는 것",
                    "감정 누적 후 한 번에 폭발하는 반응",
                    "상대 확인 없이 결론을 먼저 내리는 습관",
                    "대화 타이밍을 놓친 뒤 장기 침묵",
                    "상대의 표현을 빠르게 오해하는 반응"
            );
            case "work" -> List.of(
                    "동시다발 작업으로 집중 분산",
                    "마감 직전 급한 의사결정",
                    "우선순위 없이 할 일을 늘리는 것",
                    "회의가 길어져 실행 시간이 줄어드는 것",
                    "검토 없이 바로 배포/제출하는 습관"
            );
            case "health" -> List.of(
                    "수면 시간 불규칙",
                    "카페인·당류 과다 섭취",
                    "오랜 시간 같은 자세 유지",
                    "식사 간격이 지나치게 길어지는 것",
                    "회복 시간 없이 연속 일정 소화"
            );
            default -> List.of("과한 무리와 급한 결정");
        };

        List<String> actionPool = switch (category) {
            case "money" -> List.of(
                    "오늘 지출 상한 1개만 먼저 정하기",
                    "자동결제 목록 1개 점검하기",
                    "불필요한 소비 1건만 미루기",
                    "결제 전 장바구니에서 1개 빼보기",
                    "현금흐름 메모 3줄 작성하기"
            );
            case "love" -> List.of(
                    "요청은 한 문장으로 부드럽게 전달하기",
                    "중요 대화 전 10초 멈추고 톤 점검하기",
                    "감사/칭찬 메시지 1회 먼저 보내기",
                    "오해 가능 문장을 질문형으로 바꾸기",
                    "오늘 연락 리듬(시간대) 하나 정하기"
            );
            case "work" -> List.of(
                    "오늘 Top 3 중 1순위부터 90분 집중하기",
                    "회의 전 결정 항목 3개 미리 적기",
                    "오후에는 정리·마감 작업으로 전환하기",
                    "메신저 확인 시간을 2회로 제한하기",
                    "완료 기준을 먼저 정의하고 시작하기"
            );
            case "health" -> List.of(
                    "물 2잔 먼저 마시기",
                    "저녁 20분 가볍게 걷기",
                    "잠들기 1시간 전 화면 사용 줄이기",
                    "오전/오후 1회씩 목·어깨 스트레칭",
                    "카페인 컵 수를 하루 1잔 줄이기"
            );
            default -> List.of("작은 실행 1개부터 시작하기");
        };

        return new DailyCategoryDetail(
                score,
                summary,
                pickN(goodPool, seed ^ 0x51, 2),
                pickN(cautionPool, seed ^ 0x52, 2),
                pickN(actionPool, seed ^ 0x53, 2)
        );
    }

    private List<String> pickN(List<String> source, int seed, int count) {
        if (source == null || source.isEmpty() || count <= 0) {
            return List.of();
        }
        int limit = Math.min(count, source.size());
        int start = Math.floorMod(seed, source.size());
        List<String> out = new java.util.ArrayList<>(limit);
        for (int i = 0; i < limit; i++) {
            out.add(source.get((start + i) % source.size()));
        }
        return out;
    }

    private String pickOne(List<String> source, int seed) {
        if (source == null || source.isEmpty()) {
            return "";
        }
        int idx = Math.floorMod(seed, source.size());
        return source.get(idx);
    }

    private int jitter(int seed, int min, int max) {
        int width = max - min + 1;
        return min + Math.floorMod(seed, width);
    }

    private int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
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

    public ReportResult generateAiInterpretation(String userId, GenerateAiInterpretationRequest request) {
        var snapshot = persistenceService.findChartSnapshot(userId, request.chartId());
        if (snapshot == null) {
            throw new ApiClientException(
                    "CHART_NOT_FOUND",
                    HttpStatus.NOT_FOUND,
                    "사주 차트를 먼저 계산해주세요."
            );
        }

        Map<String, Object> content = openAiAnalysisClient.generateSajuInterpretation(
                snapshot.chart(),
                snapshot.fiveElements()
        );
        content = new LinkedHashMap<>(content);
        content.put("analysisInput", buildAiAnalysisInput(snapshot.chart(), snapshot.fiveElements()));
        content.put("analysisInputText", buildAiAnalysisInputText(snapshot.chart(), snapshot.fiveElements()));

        try {
            persistenceService.upsertNonDailyReport(
                    userId,
                    request.chartId(),
                    "ai_interpretation",
                    content,
                    true,
                    true
            );
        } catch (IllegalStateException e) {
            // Do not fail user-facing generation when persistence schema is behind (e.g. enum/index mismatch).
            // Client can still render the returned content immediately.
            log.warn("ai interpretation persistence skipped due to storage error: {}", e.getMessage());
        }

        return new ReportResult(request.chartId(), "ai_interpretation", content);
    }

    private Map<String, Object> buildAiAnalysisInput(Map<String, String> chart, Map<String, Integer> fiveElements) {
        String year = valueOrDash(chart.get("year"));
        String month = valueOrDash(chart.get("month"));
        String day = valueOrDash(chart.get("day"));
        String hour = valueOrDash(chart.get("hour"));

        String gender = firstNonBlank(chart.get("gender"), "미제공");
        String name = firstNonBlank(chart.get("name"), chart.get("profileName"), "미제공");
        String age = firstNonBlank(chart.get("age"), "미제공");
        String birthDateTime = firstNonBlank(
                chart.get("birthDatetimeLocal"),
                chart.get("birth_datetime_local"),
                chart.get("birthDateTime"),
                chart.get("birth_datetime"),
                "미제공"
        );
        String tenGodStem = firstNonBlank(chart.get("tenGodStems"), chart.get("ten_god_stems"), "미제공");
        String tenGodBranch = firstNonBlank(chart.get("tenGodBranches"), chart.get("ten_god_branches"), "미제공");
        String twelveStates = firstNonBlank(chart.get("twelveStates"), chart.get("twelve_states"), "미제공");

        Map<String, Object> systemGuide = new LinkedHashMap<>();
        systemGuide.put("title", "시스템 가이드: FortuneLog");
        systemGuide.put("items", List.of(
                "본 분석은 'FortuneLog'의 정밀한 로직으로 산출된 데이터를 바탕으로 합니다.",
                "제공된 사주 정보는 검증된 값이므로 다시 계산하지 말고, 이 데이터를 절대적 기준으로 해석하십시오.",
                "답변 시작 시 'FortuneLog'앱의 데이터를 바탕으로 해석함을 가볍게 언급하며, 전문가의 품격에 맞는 존댓말로 답변해 주십시오."
        ));

        Map<String, Object> sajuInfo = new LinkedHashMap<>();
        sajuInfo.put("gender", gender);
        sajuInfo.put("name", name);
        sajuInfo.put("age", age);
        sajuInfo.put("birthDateTime", birthDateTime);
        sajuInfo.put("pillars", Map.of(
                "year", year,
                "month", month,
                "day", day,
                "hour", hour
        ));
        sajuInfo.put("tenGodStem", tenGodStem);
        sajuInfo.put("tenGodBranch", tenGodBranch);
        sajuInfo.put("twelveStates", twelveStates);
        sajuInfo.put("fiveElements", Map.of(
                "wood", fiveElements.getOrDefault("wood", 0),
                "fire", fiveElements.getOrDefault("fire", 0),
                "earth", fiveElements.getOrDefault("earth", 0),
                "metal", fiveElements.getOrDefault("metal", 0),
                "water", fiveElements.getOrDefault("water", 0)
        ));

        Map<String, Object> questions = new LinkedHashMap<>();
        questions.put("title", "질문 사항");
        questions.put("items", List.of(
                "일간과 일주를 중심으로 본연의 기질과 중심 성격을 설명해 주십시오.",
                "월지에 배정된 기운과 전체적인 십성의 흐름을 바탕으로, 이 사주가 사회에서 어떤 환경에 놓이기 쉬우며 어떤 방식으로 역량을 발휘하는지 분석해 주십시오.",
                "주어진 십성 구성에서 나타나는 특징적인 장단점과 그에 따른 인생 흐름의 특성을 분석해 주십시오.",
                "제공된 오행 분포 수치를 절대적 기준으로 삼아, 부족하거나 과한 기운을 조절할 수 있는 실생활의 보완책(색상, 습관 등)을 제안해 주십시오.",
                "재물운, 연애·결혼운, 직업 적성, 건강운 등 주요 영역을 주어진 데이터를 근거로 종합 해석해 주십시오.",
                "전체적인 사주 구성의 균형을 맞추기 위해 이 사주가 지향해야 할 삶의 태도와 핵심적인 조언을 들려주십시오."
        ));

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("version", "fortune-log-ai-input-v1");
        payload.put("systemGuide", systemGuide);
        payload.put("sajuInfo", sajuInfo);
        payload.put("questions", questions);
        return payload;
    }

    private String buildAiAnalysisInputText(Map<String, String> chart, Map<String, Integer> fiveElements) {
        String year = valueOrDash(chart.get("year"));
        String month = valueOrDash(chart.get("month"));
        String day = valueOrDash(chart.get("day"));
        String hour = valueOrDash(chart.get("hour"));

        String gender = firstNonBlank(chart.get("gender"), "미제공");
        String name = firstNonBlank(chart.get("name"), chart.get("profileName"), "미제공");
        String age = firstNonBlank(chart.get("age"), "미제공");
        String birthDateTime = firstNonBlank(
                chart.get("birthDatetimeLocal"),
                chart.get("birth_datetime_local"),
                chart.get("birthDateTime"),
                chart.get("birth_datetime"),
                "미제공"
        );
        String tenGodStem = firstNonBlank(chart.get("tenGodStems"), chart.get("ten_god_stems"), "미제공");
        String tenGodBranch = firstNonBlank(chart.get("tenGodBranches"), chart.get("ten_god_branches"), "미제공");
        String twelveStates = firstNonBlank(chart.get("twelveStates"), chart.get("twelve_states"), "미제공");

        int wood = fiveElements.getOrDefault("wood", 0);
        int fire = fiveElements.getOrDefault("fire", 0);
        int earth = fiveElements.getOrDefault("earth", 0);
        int metal = fiveElements.getOrDefault("metal", 0);
        int water = fiveElements.getOrDefault("water", 0);

        return """
                [시스템 가이드: FortuneLog]
                1. 본 분석은 'FortuneLog'의 정밀한 로직으로 산출된 데이터를 바탕으로 합니다.
                2. 제공된 사주 정보는 검증된 값이므로 다시 계산하지 말고, 이 데이터를 절대적 기준으로 해석하십시오.
                3. 답변 시작 시 'FortuneLog'앱의 데이터를 바탕으로 해석함을 가볍게 언급하며, 전문가의 품격에 맞는 존댓말로 답변해 주십시오.
                
                [사주 정보] - 프로필 설정자의 사주 정보
                -성별 : %s
                -성함 : %s
                -나이 : %s
                -생년월일시 : %s
                -사주팔자 : 년주(%s), 월주(%s), 일주(%s), 시주(%s)
                -십성(천간) : %s
                -십성(지지) : %s
                -십이운성 : %s
                -오행 분포 : 木 %d , 火 %d , 土 %d , 金 %d , 水 %d
                
                [질문 사항]
                위 데이터를 바탕으로 명리학 전문가의 관점에서 다음 사항을 상세히 분석해 주십시오.
                1. 일간과 일주를 중심으로 본연의 기질과 중심 성격을 설명해 주십시오.
                2. 월지에 배정된 기운과 전체적인 십성의 흐름을 바탕으로, 이 사주가 사회에서 어떤 환경에 놓이기 쉬우며 어떤 방식으로 역량을 발휘하는지 분석해 주십시오.
                3. 주어진 십성 구성에서 나타나는 특징적인 장단점과 그에 따른 인생 흐름의 특성을 분석해 주십시오.
                4. 제공된 오행 분포 수치를 절대적 기준으로 삼아, 부족하거나 과한 기운을 조절할 수 있는 실생활의 보완책(색상, 습관 등)을 제안해 주십시오.
                5. 재물운, 연애·결혼운, 직업 적성, 건강운 등 주요 영역을 주어진 데이터를 근거로 종합 해석해 주십시오.
                6. 전체적인 사주 구성의 균형을 맞추기 위해 이 사주가 지향해야 할 삶의 태도와 핵심적인 조언을 들려주십시오.
                """.formatted(
                gender, name, age, birthDateTime, year, month, day, hour, tenGodStem, tenGodBranch, twelveStates,
                wood, fire, earth, metal, water
        );
    }

    private String firstNonBlank(String... values) {
        if (values == null || values.length == 0) {
            return "-";
        }
        for (String value : values) {
            if (value != null && !value.trim().isEmpty()) {
                return value.trim();
            }
        }
        return "-";
    }

    private String valueOrDash(String value) {
        if (value == null || value.trim().isEmpty()) {
            return "-";
        }
        return value.trim();
    }
}
