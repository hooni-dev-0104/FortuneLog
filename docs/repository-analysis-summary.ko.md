# FortuneLog 저장소 분석 요약 (2026-03-20)

## 한눈에 보기
- 현재 저장소는 `apps/mobile`(Flutter), `services/engine-api`(Spring Boot), `infra/supabase/migrations`로 역할 분리가 비교적 명확합니다.
- CI도 모바일/엔진/정책 링크 모니터링으로 분리되어 있어 기본적인 품질 게이트는 마련되어 있습니다.
- 다만 **로컬 재현성**, **모바일 영역의 유지보수성/테스트 밀도**, **문서 최신성**에서 우선 개선이 필요합니다.

## 확인한 근거
- 저장소 구조: `apps/mobile`, `services/engine-api`, `infra/supabase/migrations`, `supabase/config.toml`
- 모바일 규모: Dart 소스 32개 / 10,716 lines, 테스트 4개 / 227 lines
- 엔진 규모: Java 소스 26개 / 3,873 lines, 테스트 10개 / 1,546 lines
- 대형 파일:
  - `apps/mobile/lib/features/dashboard/dashboard_page.dart` — 2,415 lines
  - `apps/mobile/lib/features/mypage/my_page.dart` — 625 lines
  - `apps/mobile/lib/features/birth/birth_input_page.dart` — 619 lines
  - `services/engine-api/src/main/java/com/fortunelog/engine/infra/supabase/SupabasePersistenceService.java` — 972 lines
  - `services/engine-api/src/main/java/com/fortunelog/engine/application/EngineService.java` — 654 lines
- 모바일 테스트 참조 검색에서 `DashboardPage`, `BirthInputPage`, `AppGate`, `LoginPage`, `SignupPage`, `DailyFortunePage` 관련 테스트 참조를 찾지 못함
- 문서 상태:
  - 루트 `README.md` 7 lines
  - `apps/mobile/README.md`는 기본 Flutter 템플릿 문구 유지
  - `docs/mobile-dev-test.ko.md`, `docs/social-login-setup.ko.md`에 `/Users/hooni/...` 절대 경로 포함
- 로컬 검증 상태:
  - `flutter --version` → `command not found`
  - `java -version` → Java 17만 설치됨
  - `services/engine-api/build.gradle.kts`는 Java toolchain 21 요구
  - `./gradlew test assemble --no-daemon` → Java 21 부재로 실패
- 릴리스 준비도:
  - `apps/mobile/android/app/build.gradle.kts`에 example `applicationId`와 debug signing TODO가 남아 있음

## 우선순위 권고

### P0 — 로컬 실행/검증 재현성부터 복구
**왜 먼저 해야 하나:** 지금은 CI가 요구하는 최소 런타임조차 로컬에 없는 상태여서, PR 전 검증 루프가 CI 의존적입니다.

**근거**
- 모바일: `flutter`/`dart` 미설치
- 엔진: Java 21 요구인데 로컬은 Java 17만 존재
- CI는 `.github/workflows/mobile-ci.yml`, `.github/workflows/engine-test.yml`에서 각각 Flutter / Java 21을 전제로 동작

**권고**
1. 루트에 단일 bootstrap 문서 또는 스크립트(`make bootstrap`, `just bootstrap`, 또는 `scripts/dev-check.sh`) 추가
2. Java 21 / Flutter 설치 여부를 사전 점검하는 환경 검증 스크립트 추가
3. PR 전 로컬 검증 명령을 루트 README에 통합

### P1 — 모바일 대형 화면을 분해하고 핵심 흐름 테스트를 보강
**왜 중요하나:** 현재 모바일 쪽은 큰 화면 파일에 로직과 UI가 함께 누적되어 있고, 테스트가 일부 정책/마이페이지/RevenueCat 중심으로만 존재합니다.

**근거**
- `dashboard_page.dart` 2,415 lines
- `my_page.dart` 625 lines
- `birth_input_page.dart` 619 lines
- 소스 32개 대비 테스트 4개
- 핵심 흐름(`DashboardPage`, `AppGate`, `LoginPage`, `SignupPage`, `DailyFortunePage`) 관련 테스트 참조 없음

**권고**
1. `dashboard_page.dart`부터 카드/섹션/데이터 로딩 책임을 분리
2. 로그인 → AppGate → birth profile 유무 분기 → 홈 진입 흐름을 위젯 테스트로 고정
3. 출생정보 입력/일일 운세/결제 상태 분기를 최소 회귀 세트로 추가

### P1 — 문서 드리프트를 줄여 신규 기여자 온보딩 비용 축소
**왜 중요하나:** 구현보다 문서가 더 많지만, 진입 문서가 비어 있거나 오래된 경로를 포함해 실제 실행 안내 신뢰도가 떨어집니다.

**근거**
- 루트 README 7 lines
- 모바일 README는 기본 Flutter 템플릿
- 일부 문서가 `/Users/hooni/...` 절대 경로 사용

**권고**
1. 루트 README에 저장소 개요, 각 서브프로젝트 실행법, 필수 버전, CI 체크를 추가
2. 모바일 README를 실제 앱 기준으로 교체
3. 문서 내 절대 경로를 상대 경로 기반 안내로 정리

### P2 — 엔진 서비스 경계와 운영 안전장치 강화
**왜 중요하나:** 엔진은 테스트 밀도는 모바일보다 낫지만, 일부 핵심 클래스가 커지고 운영 플래그가 코드 규약 수준에 머물러 있습니다.

**근거**
- `SupabasePersistenceService.java` 972 lines
- `EngineService.java` 654 lines
- `PaymentWebhookService.java` 571 lines
- `InsecureJwtDecoder`와 `ENGINE_INSECURE_JWT`는 "local dev only" 주석/로그는 있으나 프로필 강제는 없음

**권고**
1. persistence / webhook / report-generation 책임을 점진적으로 분리
2. `ENGINE_INSECURE_JWT=true`를 dev/test profile로만 허용하거나 부팅 시 강제 차단
3. 대형 서비스 파일 리팩터링 전에 현재 동작을 테스트로 더 고정

### P2 — Android 릴리스 설정 마무리
**왜 중요하나:** 코드 기능과 별개로 릴리스 경로가 아직 샘플 설정에 의존합니다.

**근거**
- `apps/mobile/android/app/build.gradle.kts`에 example `applicationId` 유지
- release가 debug signing 사용

**권고**
1. 실제 패키지 ID로 교체
2. 릴리스 서명 설정 분리
3. 배포 전용 체크리스트(패키지명/서명/스토어 메타데이터) 문서화

## 긍정 신호
- 기능/기술 스펙 문서(`docs/functional-spec.ko.md`, `docs/tech-spec.ko.md`)가 비교적 상세함
- 엔진 쪽은 테스트 파일 수가 소스 파일 수 대비 양호함
- GitHub Actions가 모바일/엔진/문서성 모니터링을 분리해 관리하고 있음

## 추천 실행 순서
1. 개발환경 bootstrap + README 정리
2. 모바일 핵심 흐름 테스트 추가
3. `dashboard_page.dart` 분해 시작
4. 엔진 대형 서비스 분리 및 insecure JWT 운영 가드 추가
5. Android 릴리스 설정 마무리
