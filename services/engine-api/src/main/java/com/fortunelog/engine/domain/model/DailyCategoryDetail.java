package com.fortunelog.engine.domain.model;

import java.util.List;

public record DailyCategoryDetail(
        int score,
        String summary,
        List<String> good,
        List<String> cautions,
        List<String> actions
) {
}

