import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fortune_log_mobile/core/credits/ai_request_store.dart';
import 'package:fortune_log_mobile/core/network/engine_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('parallel callers and retries share a durable request key', () async {
    final keys = await Future.wait(List.generate(
      8, (_) => AiRequestStore.getOrCreate('user', 'chart'),
    ));
    expect(keys.toSet(), hasLength(1));
    expect(await AiRequestStore.getOrCreate('user', 'chart'), keys.first);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('ai_request_v1:user:chart'), keys.first);
    expect(GenerateAiInterpretationRequestDto(chartId: 'chart', requestKey: keys.first)
        .toJson()['requestKey'], keys.first);
  });

  test('account/chart changes isolate requests; only confirmed completion retires a key', () async {
    final first = await AiRequestStore.getOrCreate('user', 'chart');
    expect(await AiRequestStore.getOrCreate('other', 'chart'), isNot(first));
    expect(await AiRequestStore.getOrCreate('user', 'other'), isNot(first));
    await AiRequestStore.complete('user', 'chart', 'stale-key');
    expect(await AiRequestStore.getOrCreate('user', 'chart'), first);
    await AiRequestStore.complete('user', 'chart', first);
    expect(await AiRequestStore.getOrCreate('user', 'chart'), isNot(first));
  });
}
