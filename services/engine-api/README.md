# engine-api

Spring Boot service for saju chart calculation and report generation.

## Requirements

- Java 21
- Gradle 8+

## Run

```bash
cd services/engine-api
./gradlew bootRun
```

If wrapper is not generated yet:

```bash
gradle wrapper
./gradlew bootRun
```

## PR CI preflight (engine-api)

For engine-related PRs, GitHub Actions runs these checks:

1. `./gradlew test --no-daemon`
2. `./gradlew assemble --no-daemon` (PR build gate)

Run the same commands locally before opening a PR:

```bash
cd services/engine-api
./gradlew test --no-daemon
./gradlew assemble --no-daemon
```

`assemble` is intended as a pull-request build gate to catch packaging/build issues before merge.

## Premium AI credits (beta)

Endpoint:

- `GET /engine/v1/credits` — returns authenticated user's credit balances.
- `POST /engine/v1/reports:interpret` — accepts `{ "chartId": "<uuid>", "requestKey": "<uuid>" }`. Keep the same request key until the result is confirmed; a new explicit generation needs a new key. Missing/invalid keys return HTTP 400.
- Completed requests replay their original content before checking credits, even after a newer generation or a lost response. One key binds to one user and chart; conflicting reuse returns HTTP 409 `AI_REQUEST_CONFLICT`.
- A verified OpenAI result is saved and charged atomically once. Free fallback is saved only in the request journal (`creditCharged=false`); it never overwrites a paid report or consumes a credit. Duplicate attempts replay that same free result.
- New requests without credit return HTTP 402 `AI_CREDIT_REQUIRED`. Unconfirmed storage/transport outcomes return HTTP 503 `AI_RESULT_UNCONFIRMED`: retry the same key, never assume a failed HTTP response means no commit.
- `/reports:generate` remains closed (`REPORT_NOT_READY`) until personalized detail types are verified. A restrictive RLS policy also hides legacy fixed examples from direct mobile Data API reads.

### Migration and verification gate

Apply `202610020001_ai_request_idempotency.sql` and `202610020002_hide_unverified_reports.sql` through the approved DB migration process **before** deploying this engine/mobile contract. The legacy finalize RPC is revoked to prevent old clients from bypassing idempotency. The migrations were authored offline because CLI scaffolding was blocked in the saved cloud environment; no production database was touched.

The request journal is service-role-only. Completed snapshots remain immutable even when the displayed report changes; chart/profile deletion cascades journal deletion. Pending request keys are retained for retry; a production retention policy for abandoned requests is still a release follow-up.

From the repository root, `bash scripts/test-ai-credit-db.sh` creates an isolated, disposable PostgreSQL container with no published ports, applies the entire migration chain, and tests duplicate/concurrent requests, atomic rollback, replay, ownership, deactivation, deletion and legacy visibility. It does not use project credentials. Local DB tests passed on 2026-10-02; Java/Flutter execution still requires CI confirmation.

The `fix/credits-and-report-safety` push triggers engine test/assemble plus isolated DB tests, and mobile analyze/tests/debug APK. These branch checks do not deploy, create signing keys or use live payments.

Credit packs:

- `fortunelog_ai_credit_1`: 1 AI saju interpretation credit, fallback price 1,500 KRW
- `fortunelog_ai_credit_5`: 5 credits, fallback price 5,500 KRW
- `fortunelog_ai_credit_10`: 10 credits, fallback price 10,000 KRW

## RevenueCat webhook (beta)

Endpoint:

- `POST /engine/v1/payments:webhook`

Environment:

- `REVENUECAT_WEBHOOK_AUTH`: RevenueCat webhook Authorization header value
- `PAYMENT_WEBHOOK_SECRET`: legacy generic webhook HMAC secret (backward compatibility)

## Account deletion worker (beta)

Environment:

- `ACCOUNT_DELETION_WORKER_ENABLED` (default `true`)
- `ACCOUNT_DELETION_WORKER_BATCH_SIZE` (default `20`)
- `ACCOUNT_DELETION_WORKER_FIXED_DELAY_MS` (default `30000`)

## Endpoints

- `GET /engine/v1/health`
- `GET /engine/v1/credits`
- `POST /engine/v1/charts:calculate`
- `POST /engine/v1/reports:generate`
- `POST /engine/v1/reports:interpret`
- `POST /engine/v1/fortunes:daily`
- `POST /engine/v1/accounts:deletion-request`
