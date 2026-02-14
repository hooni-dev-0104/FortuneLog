# 소셜 로그인 실제 동작 설정 (Supabase + Flutter)

## 1) 앱 실행 전 로컬 설정

`/Users/hooni/FortuneLog/apps/mobile/.env` 파일을 만들고 아래 3개를 채웁니다.

```env
SUPABASE_URL=https://gcddzpfzjcstypegmmnj.supabase.co
SUPABASE_ANON_KEY=<YOUR_ANON_KEY>
AUTH_REDIRECT_TO=io.supabase.flutter://login-callback/
```

실행:

```bash
cd /Users/hooni/FortuneLog/apps/mobile
./scripts/run_ios_dev.sh
```

## 2) Supabase 대시보드 설정

1. `Authentication > URL Configuration`
2. `Site URL`은 기본값 유지
3. `Additional Redirect URLs`에 아래 추가

```text
io.supabase.flutter://login-callback/
```

## 3) Google 로그인 설정 (필수)

1. Google Cloud Console에서 OAuth Client 생성
2. Authorized redirect URI에 아래 추가

```text
https://gcddzpfzjcstypegmmnj.supabase.co/auth/v1/callback
```

3. Supabase `Authentication > Providers > Google`에서 Enable 후 Client ID/Secret 입력

## 4) Kakao 로그인 설정 (필수)

1. Kakao Developers에서 앱 생성, Redirect URI에 아래 추가

```text
https://gcddzpfzjcstypegmmnj.supabase.co/auth/v1/callback
```

2. Supabase `Authentication > Providers > Kakao`에서 Enable 후 REST API Key/Secret 입력

## 5) 앱에서 테스트 순서

1. 앱 로그인 화면 진입
2. Google 또는 Kakao 아이콘 버튼 탭
3. 브라우저 인증 완료 후 앱으로 자동 복귀
4. 로그인 성공 시 홈 화면으로 이동 확인

## 6) 문제 발생 시 점검

- `AUTH_REDIRECT_TO` 값과 Supabase Additional Redirect URL이 완전히 동일한지 확인
- Google/Kakao provider가 Supabase에서 Enable 상태인지 확인
- Provider 콘솔 Redirect URI가 Supabase callback URL과 일치하는지 확인
- 오류 박스의 `requestId` 값으로 서버 로그 추적
