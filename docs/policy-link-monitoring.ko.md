# 정책 링크 모니터링 실행 가이드

FortuneLog 앱의 마이페이지에서 사용하는 정책 링크(이용약관 / 개인정보 처리방침 / 환불정책)가 정상 응답하는지 점검하는 스크립트입니다.

기본 대상 URL:

- 이용약관: `https://fortunelog.app/terms`
- 개인정보 처리방침: `https://fortunelog.app/privacy`
- 환불정책: `https://fortunelog.app/refund`

## 1. 기본 실행

저장소 루트에서 아래 명령을 실행합니다.

```bash
scripts/check-policy-links.sh
```

성공 시 각 URL의 최종 HTTP 상태 코드와 redirect 수를 출력하고, 하나라도 실패하면 종료 코드 `1`을 반환합니다.

## 2. URL 오버라이드

스테이징/임시 URL을 점검하려면 `--url <name>=<url>` 옵션을 반복해서 전달합니다.

```bash
scripts/check-policy-links.sh \
  --url terms=https://staging.fortunelog.app/terms \
  --url privacy=https://staging.fortunelog.app/privacy \
  --url refund=https://staging.fortunelog.app/refund
```

## 3. 환경 변수 오버라이드

앱에서 사용하는 정책 링크 환경 변수와 동일한 이름으로 기본값을 바꿀 수 있습니다.

```bash
export POLICY_TERMS_URL=https://staging.fortunelog.app/terms
export POLICY_PRIVACY_URL=https://staging.fortunelog.app/privacy
export POLICY_REFUND_URL=https://staging.fortunelog.app/refund
scripts/check-policy-links.sh
```

추가로 타임아웃도 조정할 수 있습니다.

```bash
export POLICY_LINK_CONNECT_TIMEOUT=5
export POLICY_LINK_MAX_TIME=15
scripts/check-policy-links.sh
```

## 4. 동작 기준

- HTTP `2xx`, `3xx` 응답: 성공
- `4xx`, `5xx`, DNS 오류, 연결 실패, 타임아웃: 실패
- Redirect가 있으면 최종 URL과 redirect 횟수를 함께 출력

## 5. CI/수동 점검 권장 시점

- 정책 페이지 배포 직후
- 앱 릴리스 전 체크리스트 수행 시점
- 도메인, CDN, 리다이렉트 규칙 변경 직후
