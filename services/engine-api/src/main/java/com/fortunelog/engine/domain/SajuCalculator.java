package com.fortunelog.engine.domain;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;

public class SajuCalculator {

    private static final String[] STEMS = {"갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"};
    private static final String[] BRANCHES = {"자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"};

    private static final int[] STEM_ELEMENTS = {
            0, 0, // 갑, 을 -> wood
            1, 1, // 병, 정 -> fire
            2, 2, // 무, 기 -> earth
            3, 3, // 경, 신 -> metal
            4, 4  // 임, 계 -> water
    };

    private static final int[] BRANCH_ELEMENTS = {
            4, // 자 -> water
            2, // 축 -> earth
            0, // 인 -> wood
            0, // 묘 -> wood
            2, // 진 -> earth
            1, // 사 -> fire
            1, // 오 -> fire
            2, // 미 -> earth
            3, // 신 -> metal
            3, // 유 -> metal
            2, // 술 -> earth
            4  // 해 -> water
    };

    // Calibrated against external manse-ryeok references:
    // 1984-01-31 (Gregorian) is a 갑자(甲子) day.
    private static final LocalDate REFERENCE_GAPJA_DAY = LocalDate.of(1984, 1, 31);

    public SajuChart calculate(
            LocalDateTime birthDateTime,
            boolean unknownBirthTime
    ) {
        Pillar year = calculateYearPillar(birthDateTime);
        int monthOrder = monthOrderBySolarTerm(birthDateTime);
        Pillar month = calculateMonthPillar(year.stemIndex(), monthOrder);
        Pillar day = calculateDayPillar(birthDateTime.toLocalDate());
        Pillar hour = unknownBirthTime ? null : calculateHourPillar(day.stemIndex(), birthDateTime.getHour());

        Map<String, String> chart = new LinkedHashMap<>();
        chart.put("year", formatPillar(year));
        chart.put("month", formatPillar(month));
        chart.put("day", formatPillar(day));
        chart.put("hour", hour == null ? "미상" : formatPillar(hour));

        Map<String, Integer> fiveElements = aggregateFiveElements(year, month, day, hour);

        return new SajuChart(chart, fiveElements);
    }

    private Pillar calculateYearPillar(LocalDateTime birthDateTime) {
        LocalDateTime ipchun = termDateTime(birthDateTime.getYear(), 2, 4, 10);
        int year = birthDateTime.isBefore(ipchun) ? birthDateTime.getYear() - 1 : birthDateTime.getYear();

        int baseYear = 1984; // 갑자년
        int offset = Math.floorMod(year - baseYear, 60);
        return new Pillar(offset % 10, offset % 12);
    }

    private Pillar calculateMonthPillar(int yearStemIndex, int monthOrderFromIn) {
        int monthBranchIndex = Math.floorMod(2 + (monthOrderFromIn - 1), 12); // 인월 시작
        int monthStemStartAtIn = switch (yearStemIndex) {
            case 0, 5 -> 2; // 갑/기 -> 병
            case 1, 6 -> 4; // 을/경 -> 무
            case 2, 7 -> 6; // 병/신 -> 경
            case 3, 8 -> 8; // 정/임 -> 임
            case 4, 9 -> 0; // 무/계 -> 갑
            default -> throw new IllegalStateException("invalid year stem index: " + yearStemIndex);
        };

        int monthStemIndex = Math.floorMod(monthStemStartAtIn + (monthOrderFromIn - 1), 10);
        return new Pillar(monthStemIndex, monthBranchIndex);
    }

    private Pillar calculateDayPillar(LocalDate birthDate) {
        long days = ChronoUnit.DAYS.between(REFERENCE_GAPJA_DAY, birthDate);
        int cycleIndex = Math.floorMod((int) days, 60);
        return new Pillar(cycleIndex % 10, cycleIndex % 12);
    }

    private Pillar calculateHourPillar(int dayStemIndex, int birthHour) {
        int hourBranchIndex = Math.floorMod((birthHour + 1) / 2, 12);
        int hourStemStartAtJa = switch (dayStemIndex) {
            case 0, 5 -> 0; // 갑/기일 자시 시작 갑
            case 1, 6 -> 2; // 을/경일 자시 시작 병
            case 2, 7 -> 4; // 병/신일 자시 시작 무
            case 3, 8 -> 6; // 정/임일 자시 시작 경
            case 4, 9 -> 8; // 무/계일 자시 시작 임
            default -> throw new IllegalStateException("invalid day stem index: " + dayStemIndex);
        };

        int hourStemIndex = Math.floorMod(hourStemStartAtJa + hourBranchIndex, 10);
        return new Pillar(hourStemIndex, hourBranchIndex);
    }

    private int monthOrderBySolarTerm(LocalDateTime dateTime) {
        int year = dateTime.getYear();

        LocalDateTime ipchun = termDateTime(year, 2, 4, 10);
        LocalDateTime gyeongchip = termDateTime(year, 3, 6, 5);
        LocalDateTime cheongmyeong = termDateTime(year, 4, 5, 11);
        LocalDateTime ibha = termDateTime(year, 5, 6, 4);
        LocalDateTime mangjong = termDateTime(year, 6, 6, 6);
        LocalDateTime soseo = termDateTime(year, 7, 7, 17);
        LocalDateTime ibchu = termDateTime(year, 8, 8, 3);
        LocalDateTime baengno = termDateTime(year, 9, 8, 5);
        LocalDateTime hanro = termDateTime(year, 10, 8, 17);
        LocalDateTime ibdong = termDateTime(year, 11, 7, 18);
        LocalDateTime daeseol = termDateTime(year, 12, 7, 11);
        LocalDateTime sohan = termDateTime(year, 1, 6, 6);

        if (!dateTime.isBefore(ipchun) && dateTime.isBefore(gyeongchip)) return 1;   // 인
        if (!dateTime.isBefore(gyeongchip) && dateTime.isBefore(cheongmyeong)) return 2; // 묘
        if (!dateTime.isBefore(cheongmyeong) && dateTime.isBefore(ibha)) return 3; // 진
        if (!dateTime.isBefore(ibha) && dateTime.isBefore(mangjong)) return 4; // 사
        if (!dateTime.isBefore(mangjong) && dateTime.isBefore(soseo)) return 5; // 오
        if (!dateTime.isBefore(soseo) && dateTime.isBefore(ibchu)) return 6; // 미
        if (!dateTime.isBefore(ibchu) && dateTime.isBefore(baengno)) return 7; // 신
        if (!dateTime.isBefore(baengno) && dateTime.isBefore(hanro)) return 8; // 유
        if (!dateTime.isBefore(hanro) && dateTime.isBefore(ibdong)) return 9; // 술
        if (!dateTime.isBefore(ibdong) && dateTime.isBefore(daeseol)) return 10; // 해
        if (!dateTime.isBefore(daeseol) || dateTime.isBefore(sohan)) return 11; // 자
        return 12; // 축 (1/6 ~ 2/3)
    }

    private LocalDateTime termDateTime(int year, int month, int day, int hour) {
        return LocalDateTime.of(year, month, day, hour, 0);
    }

    private Map<String, Integer> aggregateFiveElements(Pillar year, Pillar month, Pillar day, Pillar hour) {
        int[] counts = new int[5];
        addPillarElements(counts, year);
        addPillarElements(counts, month);
        addPillarElements(counts, day);
        if (hour != null) {
            addPillarElements(counts, hour);
        }

        Map<String, Integer> result = new LinkedHashMap<>();
        result.put("wood", counts[0]);
        result.put("fire", counts[1]);
        result.put("earth", counts[2]);
        result.put("metal", counts[3]);
        result.put("water", counts[4]);
        return result;
    }

    private void addPillarElements(int[] counts, Pillar pillar) {
        counts[STEM_ELEMENTS[pillar.stemIndex()]] += 1;
        counts[BRANCH_ELEMENTS[pillar.branchIndex()]] += 1;
    }

    private String formatPillar(Pillar pillar) {
        return STEMS[pillar.stemIndex()] + BRANCHES[pillar.branchIndex()];
    }

    public record SajuChart(Map<String, String> chart, Map<String, Integer> fiveElements) {
    }

    private record Pillar(int stemIndex, int branchIndex) {
    }
}
