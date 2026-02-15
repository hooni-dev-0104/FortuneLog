import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthContextFlow { login, signup, passwordReset, socialLogin }

class AuthErrorMapper {
  static bool isUserAlreadyRegisteredMessage(String message) {
    final m = message.toLowerCase();
    return m.contains('already registered') ||
        m.contains('user already registered') ||
        m.contains('user_already_exists') ||
        m.contains('user already exists');
  }

  static String userMessage(Object error, {required AuthContextFlow flow}) {
    if (error is AuthException) {
      final raw = error.message;
      if (kDebugMode) {
        debugPrint('[auth] ${flow.name} AuthException: $raw');
      }

      final m = raw.toLowerCase().trim();

      if (isUserAlreadyRegisteredMessage(raw)) {
        return '이미 가입된 이메일입니다.\n로그인 화면에서 로그인해주세요.';
      }

      if (m.contains('invalid login credentials') || m.contains('invalid credentials')) {
        return '이메일 또는 비밀번호가 올바르지 않습니다.\n다시 확인해주세요.';
      }

      if ((m.contains('email') && m.contains('not confirmed')) || (m.contains('email') && m.contains('confirm'))) {
        return '이메일 인증이 아직 완료되지 않았습니다.\n메일함에서 인증을 완료한 뒤 다시 시도해주세요.';
      }

      if (m.contains('password') && (m.contains('should be') || m.contains('at least'))) {
        return '비밀번호 형식을 확인해주세요.\n8자 이상으로 설정해주세요.';
      }

      if (m.contains('rate limit') || m.contains('too many')) {
        return '요청이 너무 많습니다.\n잠시 후 다시 시도해주세요.';
      }

      if (m.contains('network') || m.contains('socket') || m.contains('timed out') || m.contains('timeout')) {
        return '네트워크 연결이 불안정합니다.\n잠시 후 다시 시도해주세요.';
      }

      // Default: keep short, avoid leaking internal phrasing.
      return switch (flow) {
        AuthContextFlow.signup => '회원가입에 실패했습니다.\n입력값을 확인하고 다시 시도해주세요.',
        AuthContextFlow.login => '로그인에 실패했습니다.\n입력값을 확인하고 다시 시도해주세요.',
        AuthContextFlow.passwordReset => '비밀번호 재설정 요청에 실패했습니다.\n잠시 후 다시 시도해주세요.',
        AuthContextFlow.socialLogin => '소셜 로그인을 시작할 수 없습니다.\n잠시 후 다시 시도해주세요.',
      };
    }

    return switch (flow) {
      AuthContextFlow.signup => '회원가입 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      AuthContextFlow.login => '로그인 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      AuthContextFlow.passwordReset => '요청 처리 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      AuthContextFlow.socialLogin => '로그인을 시작할 수 없습니다.\n잠시 후 다시 시도해주세요.',
    };
  }
}

