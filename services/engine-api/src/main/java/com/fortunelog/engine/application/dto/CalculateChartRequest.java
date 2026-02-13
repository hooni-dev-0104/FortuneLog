package com.fortunelog.engine.application.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CalculateChartRequest(
        @NotBlank String userId,
        @NotBlank String birthDate,
        @NotBlank String birthTime,
        @NotBlank String birthTimezone,
        @NotBlank String birthLocation,
        @NotBlank String calendarType,
        boolean leapMonth,
        @NotBlank String gender,
        @NotNull Boolean unknownBirthTime
) {
}
