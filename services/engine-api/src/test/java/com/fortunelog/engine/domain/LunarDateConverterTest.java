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
    void shouldRejectInvalidLeapMonthInput() {
        assertThrows(IllegalArgumentException.class, () ->
                converter.toSolarDate(2024, 1, 10, true)
        );
    }
}
