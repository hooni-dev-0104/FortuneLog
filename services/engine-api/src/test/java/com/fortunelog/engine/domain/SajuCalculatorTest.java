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
}
