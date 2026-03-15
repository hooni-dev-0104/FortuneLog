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
- `POST /engine/v1/charts:calculate`
- `POST /engine/v1/reports:generate`
- `POST /engine/v1/reports:interpret`
- `POST /engine/v1/fortunes:daily`
- `POST /engine/v1/accounts:deletion-request`
