package com.fortunelog.engine.application.dto;

import jakarta.validation.constraints.NotBlank;

public record GenerateAiInterpretationRequest(
        @NotBlank String chartId
) {
}
