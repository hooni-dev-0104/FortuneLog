package com.fortunelog.engine.application.dto;

import jakarta.validation.constraints.Size;

public record RequestAccountDeletionRequest(
        @Size(max = 500) String reason
) {
}
