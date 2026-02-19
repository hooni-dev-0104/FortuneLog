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

## Endpoints

- `GET /engine/v1/health`
- `POST /engine/v1/charts:calculate`
- `POST /engine/v1/reports:generate`
- `POST /engine/v1/reports:interpret`
- `POST /engine/v1/fortunes:daily`
