package com.fortunelog.engine.domain.model;

import java.util.Map;

public record ReportResult(
        String chartId,
        String reportType,
        Map<String, Object> content
) {
}
