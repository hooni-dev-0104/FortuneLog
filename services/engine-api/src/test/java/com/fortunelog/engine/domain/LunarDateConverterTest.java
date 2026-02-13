package com.fortunelog.engine.domain;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class LunarDateConverterTest {

    private final LunarDateConverter converter = new LunarDateConverter();

    @Test
    void shouldConvertKnownLunarDateToSolarDate() {
        // 2024 lunar new year: 2024-01-01 -> solar 2024-02-10
        LocalDate solar = converter.toSolarDate(2024, 1, 1, false);
        assertEquals(LocalDate.of(2024, 2, 10), solar);
    }

    @Test
    void shouldConvertMultipleKnownLunarNewYearDates() {
        assertEquals(LocalDate.of(2023, 1, 22), converter.toSolarDate(2023, 1, 1, false));
        assertEquals(LocalDate.of(2025, 1, 29), converter.toSolarDate(2025, 1, 1, false));
    }

    @Test
    void shouldConvertKnownLeapMonthDate() {
        // 2020 leap 4 month first day -> 2020-05-23
        assertEquals(LocalDate.of(2020, 5, 23), converter.toSolarDate(2020, 4, 1, true));
    }

    @Test
    void shouldRejectInvalidLeapMonthInput() {
        assertThrows(IllegalArgumentException.class, () ->
                converter.toSolarDate(2024, 1, 10, true)
        );
    }

    @Test
    void shouldRejectUnsupportedYear() {
        assertThrows(IllegalArgumentException.class, () ->
                converter.toSolarDate(1899, 1, 1, false)
        );
    }
}
