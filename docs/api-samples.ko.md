# FortuneLog API 샘플 (MVP)

- 작성일: 2026-02-13
- 기준: `docs/functional-spec.ko.md`, `docs/tech-spec.ko.md`

## 1. Engine API

Base URL:
- Dev: `https://engine-dev.example.com`
- Prod: `https://engine.example.com`

Header:
- `Authorization: Bearer <supabase_access_token>`
- `Content-Type: application/json`

## 1.1 차트 계산

`POST /engine/v1/charts:calculate`

Request:
```json
{
  "userId": "8f3f3d27-4ac9-4ab1-a4f2-5d4c3aa93b1a",
  "birthProfileId": "d9f9c85b-40d4-4f03-a0cb-1e8476ad95f8",
  "birthDate": "1994-11-21",
  "birthTime": "14:30",
  "birthTimezone": "Asia/Seoul",
  "birthLocation": "Seoul, KR",
  "calendarType": "solar",
  "leapMonth": false,
  "gender": "female",
  "unknownBirthTime": false
}
```

Response 200:
```json
{
  "chartId": "0b3d45a2-fc2b-4abf-9926-615ea3fcd912",
  "engineVersion": "v0.1.0",
  "chart": {
    "year": "갑자",
    "month": "을축",
    "day": "병인",
    "hour": "정묘"
  },
  "fiveElements": {
    "wood": 2,
    "fire": 1,
    "earth": 1,
    "metal": 0,
    "water": 2
  }
}
```

## 1.2 리포트 생성

`POST /engine/v1/reports:generate`

Request:
```json
{
  "userId": "8f3f3d27-4ac9-4ab1-a4f2-5d4c3aa93b1a",
  "chartId": "0b3d45a2-fc2b-4abf-9926-615ea3fcd912",
  "reportType": "career"
}
```

Response 200:
```json
{
  "chartId": "0b3d45a2-fc2b-4abf-9926-615ea3fcd912",
  "reportType": "career",
  "content": {
    "summary": "실행력은 강하지만 과부하 관리가 핵심입니다.",
    "strengths": ["빠른 판단", "높은 집중력"],
    "cautions": ["무리한 일정", "감정 과열"],
    "actions": ["오늘 1개 우선순위만 완료", "오후 30분 회복 시간 확보"]
  }
}
```

## 1.3 오늘 운세 생성

`POST /engine/v1/fortunes:daily`

Request:
```json
{
  "userId": "8f3f3d27-4ac9-4ab1-a4f2-5d4c3aa93b1a",
  "chartId": "0b3d45a2-fc2b-4abf-9926-615ea3fcd912",
  "date": "2026-02-13"
}
```

Response 200:
```json
{
  "userId": "8f3f3d27-4ac9-4ab1-a4f2-5d4c3aa93b1a",
  "date": "2026-02-13",
  "score": 74,
  "category": {
    "love": "대화의 온도를 낮추면 관계가 안정됩니다.",
    "work": "집중 시간대를 오전에 배치하세요.",
    "money": "소액 반복 지출 점검이 유리합니다.",
    "health": "수면 리듬을 우선 복구하세요."
  },
  "actions": [
    "중요한 결정은 오후로 미루기",
    "오늘의 지출 상한 정하기",
    "저녁 20분 산책"
  ]
}
```

## 2. Supabase DB Access 예시

## 2.1 내 출생정보 저장

`upsert public.birth_profiles`

Payload:
```json
{
  "user_id": "8f3f3d27-4ac9-4ab1-a4f2-5d4c3aa93b1a",
  "birth_datetime_local": "1994-11-21T14:30:00",
  "birth_timezone": "Asia/Seoul",
  "birth_location": "Seoul, KR",
  "calendar_type": "solar",
  "is_leap_month": false,
  "gender": "female",
  "unknown_birth_time": false
}
```

## 2.2 내 리포트 조회

`select * from public.reports where user_id = auth.uid() order by created_at desc`

- RLS로 타 사용자 데이터는 자동 차단됨

## 3. 표준 에러 응답

Response 400/401/500:
```json
{
  "requestId": "2db5d6f4-0bf1-4ac8-b00d-6f6a6a0d9f12",
  "code": "BIRTH_INFO_INVALID",
  "message": "invalid lunar/leap month combination"
}
```

## 4. 이벤트 트래킹 페이로드 예시

`purchase_completed`

```json
{
  "user_id": "8f3f3d27-4ac9-4ab1-a4f2-5d4c3aa93b1a",
  "product_code": "report_unlock_v1",
  "amount": 4900,
  "currency": "KRW",
  "platform": "ios",
  "timestamp": "2026-02-13T11:23:34+09:00"
}
```
