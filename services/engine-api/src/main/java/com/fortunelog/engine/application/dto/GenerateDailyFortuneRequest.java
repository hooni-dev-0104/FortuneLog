package com.fortunelog.engine.application.dto;

import jakarta.validation.constraints.NotBlank;

public record GenerateDailyFortuneRequest(
        @NotBlank String chartId,
        @NotBlank String date
) {
}
