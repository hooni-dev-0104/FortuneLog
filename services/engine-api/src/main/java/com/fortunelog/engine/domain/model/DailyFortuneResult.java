package com.fortunelog.engine.domain.model;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public record DailyFortuneResult(
        String userId,
        LocalDate date,
        int score,
        Map<String, String> category,
        List<String> actions
) {
}
