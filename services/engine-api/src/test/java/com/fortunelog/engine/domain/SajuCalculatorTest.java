package com.fortunelog.engine.domain;

import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SajuCalculatorTest {

    private final SajuCalculator calculator = new SajuCalculator();

    @Test
    void shouldUsePreviousYearPillarBeforeIpchunBoundary() {
        SajuCalculator.SajuChart before = calculator.calculate(
                LocalDateTime.of(2026, 2, 4, 9, 59),
                false
        );

        SajuCalculator.SajuChart after = calculator.calculate(
                LocalDateTime.of(2026, 2, 4, 10, 0),
                false
        );

        assertEquals("을사", before.chart().get("year"));
        assertEquals("병오", after.chart().get("year"));
    }

    @Test
    void shouldCalculateHourAsUnknownWhenUnknownBirthTime() {
        SajuCalculator.SajuChart chart = calculator.calculate(
                LocalDateTime.of(2026, 9, 1, 12, 0),
                true
        );

        assertEquals("미상", chart.chart().get("hour"));
    }

    @Test
    void shouldMatchReferenceServiceForKnownSolarBirthDateTime() {
        // External service screenshot reference:
        // Solar 1994-05-15 22:18 (KST) => 년주 갑술, 월주 기사, 일주 신축, 시주 기해
        SajuCalculator.SajuChart chart = calculator.calculate(
                LocalDateTime.of(1994, 5, 15, 22, 18),
                false
        );

        assertEquals("갑술", chart.chart().get("year"));
        assertEquals("기사", chart.chart().get("month"));
        assertEquals("신축", chart.chart().get("day"));
        assertEquals("기해", chart.chart().get("hour"));
    }
}
