package com.fortunelog.engine.domain.model;

import java.util.Map;

public record ChartResult(
        String chartId,
        String engineVersion,
        Map<String, String> chart,
        Map<String, Integer> fiveElements
) {
}
