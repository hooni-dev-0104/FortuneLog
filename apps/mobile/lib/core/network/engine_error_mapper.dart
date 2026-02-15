import 'package:flutter/foundation.dart';

import 'http_engine_api_client.dart';

class EngineErrorMapper {
  static String userMessage(EngineApiException e) {
    if (kDebugMode) {
      debugPrint('[engine-api] error code=${e.code} status=${e.statusCode} msg=${e.message}');
    }

    switch (e.code) {
      case 'VALIDATION_ERROR':
        return '입력값을 확인해주세요.\n(생년월일/출생시간/양·음력/윤달/성별/출생지)';
      case 'UNAUTHORIZED':
        return '로그인이 필요합니다. 다시 로그인해주세요.';
      case 'NETWORK_ERROR':
        return '운세 계산 서버에 연결할 수 없습니다.\n잠시 후 다시 시도해주세요.';
      case 'BIRTH_INFO_INVALID':
        return '입력된 출생정보를 확인해주세요.';
      default:
        // Avoid leaking internal phrasing like "request validation failed" to users.
        final msg = e.message.trim();
        if (msg.toLowerCase() == 'request validation failed') {
          return '입력값을 확인해주세요.';
        }
        return msg.isEmpty ? '요청 처리에 실패했습니다. 잠시 후 다시 시도해주세요.' : msg;
    }
  }
}

