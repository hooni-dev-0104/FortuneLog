# FortuneLog 기능 명세서 (MVP)

- 문서 버전: v0.1
- 작성일: 2026-02-13
- 대상: iOS/Android 모바일 앱
- 문서 목적: 사주 앱 MVP 개발을 위한 기능/데이터/API 기준 정의

## 1. 제품 개요

### 1.1 목표
- 사용자가 출생 정보를 입력하면 신뢰 가능한 사주 기반 해석을 즉시 제공한다.
- 무료 핵심 경험 후 유료 상세 리포트/구독으로 전환을 만든다.
- 일간 재방문(오늘 운세 확인)을 유도한다.

### 1.2 타깃 사용자
- 20~30대 사주 입문자
- 짧고 이해하기 쉬운 해석 + 행동 가이드를 원하는 사용자

### 1.3 MVP 범위
- 회원가입/로그인
- 출생정보 입력 및 저장
- 사주 원국 계산(연/월/일/시 천간지지, 오행 분포)
- 핵심 리포트(성향, 연애, 직업/재물)
- 오늘 운세(짧은 실천 문장)
- 결제(단건 상품 1종), 구독(월간 1종)
- 알림(오늘 운세 푸시)

## 2. 사용자 시나리오

### 2.1 신규 사용자
1. 앱 설치 후 온보딩 확인
2. 가입/로그인
3. 출생정보 입력(양력/음력, 윤달, 출생시간, 출생지)
4. 결과 요약 화면 확인
5. 상세 리포트 일부 잠금 해제 안내 확인
6. 결제 후 상세 리포트 열람

### 2.2 재방문 사용자
1. 푸시 알림 클릭
2. 오늘 운세 화면 진입
3. 행동 가이드 확인
4. 필요 시 추가 상품(궁합/심화 리포트) 구매 진입

## 3. 화면 및 기능 명세

## 3.1 온보딩
- 목적: 앱 가치 전달 + 고지
- 기능:
  - 3장 슬라이드(서비스 소개, 데이터 활용, 결과 성격)
  - 필수 고지: "본 결과는 참고용 해석이며 의학/법률/투자 판단을 대체하지 않음"
  - 시작하기 버튼

## 3.2 인증(로그인/회원가입)
- 방식: 이메일 + 소셜(Apple/Google 중 최소 1개)
- 기능:
  - 회원가입/로그인/로그아웃
  - 약관 동의(필수/선택 분리)
  - 탈퇴

## 3.3 출생정보 입력
- 필수 입력:
  - 생년월일
  - 성별
  - 양력/음력
  - 윤달 여부(음력 선택 시)
  - 출생시간(미상 옵션 제공)
  - 출생지(국가/도시)
- 검증:
  - 미래 시각 입력 불가
  - 음력+윤달 조합 유효성 체크
  - 출생지 기반 시간대 자동 매핑
- 저장:
  - 사용자 프로필에 암호화 저장

## 3.4 결과 대시보드(요약)
- 구성:
  - 사주팔자(연/월/일/시)
  - 오행 균형 시각화(목/화/토/금/수)
  - 한 줄 요약 3개(성향, 관계, 커리어)
  - 오늘의 키워드
- 기능:
  - 상세 리포트 진입
  - 결과 카드 공유(이미지)

## 3.5 상세 리포트
- 탭:
  - 성향 분석
  - 연애/대인
  - 직업/재물
- 섹션 구조(공통):
  - 해석 요약
  - 강점
  - 주의 포인트
  - 행동 가이드(오늘/이번주 실행 항목)
- 접근 제어:
  - 무료: 요약 노출
  - 유료: 전체 노출

## 3.6 오늘 운세
- 구성:
  - 오늘 점수(0~100)
  - 영역별 운세(연애/일/재물/건강)
  - 실천 문장 3개
- 기능:
  - 날짜별 히스토리(최근 7일)
  - 푸시 알림 시간 설정

## 3.7 결제/구독
- 상품:
  - 단건: 상세 리포트 잠금해제
  - 구독: 월간 심화 리포트 + 오늘 운세 확장 코멘트
- 기능:
  - 결제 상태 반영
  - 구독 갱신/해지 안내
  - 환불 정책 링크

## 3.8 마이페이지
- 기능:
  - 내 출생정보 수정
  - 구매 내역/구독 상태
  - 알림 설정
  - 약관/개인정보 처리방침
  - 문의하기

## 4. 계산 엔진 요구사항

### 4.1 입력 처리
- 출생지 기반 타임존 변환 지원
- 음력/양력 변환 및 윤달 처리
- 절기 기준 월주 산정

### 4.2 산출 데이터
- 사주팔자(천간/지지)
- 십성/오행 분포
- 대운/세운(월간 리포트 계산에 사용)

### 4.3 예외 처리
- 출생시간 미상 시 "3주(자/축/...) 범위 기반 확률형 해석" 또는 "시간 미포함 해석" 제공
- 계산 실패 시 재시도 및 사용자 안내 문구 표시

## 5. API 명세(초안)

### 5.1 인증
- `POST /v1/auth/signup`
- `POST /v1/auth/login`
- `POST /v1/auth/logout`

### 5.2 프로필/출생정보
- `GET /v1/me`
- `PUT /v1/me/birth-info`
- `GET /v1/me/birth-info`

### 5.3 사주 계산/리포트
- `POST /v1/saju/calculate`
- `GET /v1/reports/summary`
- `GET /v1/reports/detail?type=personality|relationship|career`
- `GET /v1/fortune/today`
- `GET /v1/fortune/history?days=7`

### 5.4 결제/구독
- `GET /v1/products`
- `POST /v1/payments/checkout`
- `GET /v1/payments/status/{orderId}`
- `GET /v1/subscription`
- `POST /v1/subscription/cancel`

### 5.5 응답 공통 규칙
- `requestId` 포함
- 실패 시 표준 에러 코드 반환
- 개인정보 필드 마스킹

## 6. 데이터 모델(초안)

### 6.1 users
- id (UUID)
- email
- auth_provider
- created_at
- status

### 6.2 birth_profiles
- id (UUID)
- user_id (FK)
- birth_datetime_local
- birth_timezone
- birth_location
- calendar_type (solar/lunar)
- leap_month (boolean)
- gender
- unknown_birth_time (boolean)

### 6.3 saju_charts
- id (UUID)
- user_id (FK)
- chart_json
- five_elements_json
- calculated_at
- engine_version

### 6.4 reports
- id (UUID)
- user_id (FK)
- report_type (summary/personality/relationship/career/daily)
- content_json
- is_paid_content
- generated_at

### 6.5 payments
- id (UUID)
- user_id (FK)
- product_id
- amount
- currency
- status
- paid_at

### 6.6 subscriptions
- id (UUID)
- user_id (FK)
- plan_code
- status
- started_at
- expires_at

## 7. 분석 이벤트 명세

- `onboarding_completed`
- `signup_completed`
- `birth_info_saved`
- `saju_calculated`
- `report_summary_viewed`
- `report_paywall_viewed`
- `checkout_started`
- `purchase_completed`
- `daily_fortune_viewed`
- `push_opened`

필수 파라미터:
- user_id
- session_id
- timestamp
- platform (ios/android)

## 8. 비기능 요구사항

- 성능:
  - 사주 계산 API P95 2초 이내
  - 주요 화면 첫 진입 3초 이내
- 가용성:
  - 월 가용성 99.5% 이상
- 보안:
  - 전송 구간 TLS
  - 민감 정보 암호화 저장
  - 최소 권한 접근 제어
- 로깅:
  - 오류 로그 + requestId 추적 가능

## 9. 정책/컴플라이언스

- 고지 문구 필수 노출:
  - "결과는 참고용 해석이며 중요한 결정은 전문가 상담 권장"
- 연령/민감정보 처리 고지
- 개인정보 처리방침/이용약관/환불정책 링크 제공

## 10. 출시 기준(Definition of Done)

- 핵심 플로우(가입 -> 출생정보 입력 -> 계산 -> 리포트 조회 -> 결제) 정상 동작
- 크래시 프리 세션 99% 이상(내부 테스트 기준)
- 결제 상태 동기화 검증 완료
- 정책 문구/약관 링크 QA 완료
- 이벤트 수집 대시보드 확인 가능

## 11. 출시 이후 우선순위(Next)

- 궁합 리포트
- 월간 운세 캘린더
- 해석 문장 개인화(AI 보정)
- A/B 테스트(요약 톤, 페이월 위치, 가격)
