package com.fortunelog.engine.application.dto;

import jakarta.validation.constraints.NotBlank;

public record GenerateReportRequest(
        @NotBlank String chartId,
        @NotBlank String reportType
) {
}
