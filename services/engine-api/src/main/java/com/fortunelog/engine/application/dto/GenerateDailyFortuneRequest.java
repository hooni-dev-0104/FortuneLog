package com.fortunelog.engine.application.dto;

import jakarta.validation.constraints.NotBlank;

public record GenerateDailyFortuneRequest(
        @NotBlank String userId,
        @NotBlank String chartId,
        @NotBlank String date
) {
}
