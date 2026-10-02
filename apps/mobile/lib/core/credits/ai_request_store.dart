import 'package:shared_preferences/shared_preferences.dart';

import '../network/request_id.dart';

/// Keeps an unfinished generation stable across timeouts and app restarts.
/// Keys are scoped by account and chart; no interpretation/birth data is stored.
class AiRequestStore {
  static final Map<String, Future<String>> _inFlight = {};

  static String _slot(String userId, String chartId) =>
      'ai_request_v1:$userId:$chartId';

  static Future<String> getOrCreate(String userId, String chartId) {
    final slot = _slot(userId, chartId);
    return _inFlight.putIfAbsent(slot, () async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final existing = preferences.getString(slot);
        if (existing != null) return existing;
        final key = generateRequestId();
        if (!await preferences.setString(slot, key)) {
          throw StateError('요청을 안전하게 보관하지 못했습니다. 다시 시도해주세요.');
        }
        return key;
      } finally {
        _inFlight.remove(slot);
      }
    });
  }

  static Future<void> complete(String userId, String chartId, String key) async {
    final preferences = await SharedPreferences.getInstance();
    final slot = _slot(userId, chartId);
    if (preferences.getString(slot) == key) {
      await preferences.remove(slot);
    }
  }
}
