package com.fortunelog.engine.infra.supabase;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CommerceSchemaContractTest {

    private static final Path INITIAL_SCHEMA = Path.of(
            "..",
            "..",
            "infra",
            "supabase",
            "migrations",
            "202602130001_init_schema.sql"
    );
    private static final Path AI_CREDIT_LEDGER_SCHEMA = Path.of(
            "..",
            "..",
            "infra",
            "supabase",
            "migrations",
            "202606150001_ai_credit_ledger.sql"
    );

    private String sql;

    @BeforeEach
    void loadSchema() throws IOException {
        sql = Files.readString(INITIAL_SCHEMA);
    }

    @Test
    void shouldKeepOrderStatusLifecycleStatesForWebhookTransitions() {
        assertEquals(
                List.of("pending", "paid", "failed", "canceled"),
                enumValues("order_status")
        );
    }

    @Test
    void shouldKeepSubscriptionStatusLifecycleStatesForEntitlementPropagation() {
        assertEquals(
                List.of("active", "grace", "expired", "canceled"),
                enumValues("subscription_status")
        );
    }

    @Test
    void shouldKeepOrderProviderUniquenessConstraintForIdempotentUpserts() {
        assertTrue(
                sql.contains("unique (provider, provider_order_id)"),
                "orders table must keep unique(provider, provider_order_id)"
        );
    }

    @Test
    void shouldKeepReportVisibilityFlagForPaidEntitlementPropagation() {
        assertTrue(
                sql.contains("visible boolean not null default true"),
                "reports.visible default is required for entitlement visibility toggles"
        );
    }

    @Test
    void shouldKeepCreditPackFallbackPricesAlignedWithLaunchContract() throws IOException {
        String creditSql = Files.readString(AI_CREDIT_LEDGER_SCHEMA);

        assertTrue(creditSql.contains("('fortunelog_ai_credit_1', 'AI 사주풀이 1회권', 1500, 'KRW', 'one_time')"));
        assertTrue(creditSql.contains("('fortunelog_ai_credit_5', 'AI 사주풀이 5회권', 5500, 'KRW', 'one_time')"));
        assertTrue(creditSql.contains("('fortunelog_ai_credit_10', 'AI 사주풀이 10회권', 10000, 'KRW', 'one_time')"));
    }

    @Test
    void shouldDedupeCreditPackPurchaseGrantsByProviderOrder() throws IOException {
        String creditSql = Files.readString(AI_CREDIT_LEDGER_SCHEMA).toLowerCase();

        assertTrue(creditSql.contains("uq_credit_ledger_purchase_order"));
        assertTrue(creditSql.contains("on public.credit_ledger (source_provider, source_order_id, reason, credit_type)"));
        assertTrue(creditSql.contains("and reason = 'purchase'"));
    }

    private List<String> enumValues(String enumName) {
        Pattern blockPattern = Pattern.compile(
                "create\\s+type\\s+public\\." + Pattern.quote(enumName) + "\\s+as\\s+enum\\s*\\(([^;]+)\\);",
                Pattern.CASE_INSENSITIVE | Pattern.DOTALL
        );
        Matcher blockMatcher = blockPattern.matcher(sql);
        assertTrue(blockMatcher.find(), "enum not found: " + enumName);

        List<String> values = new ArrayList<>();
        Matcher valueMatcher = Pattern.compile("'([^']+)'").matcher(blockMatcher.group(1));
        while (valueMatcher.find()) {
            values.add(valueMatcher.group(1));
        }
        return values;
    }
}
