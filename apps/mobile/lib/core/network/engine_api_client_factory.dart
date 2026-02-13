import 'engine_api_client.dart';
import 'http_engine_api_client.dart';
import 'supabase_access_token_provider.dart';

class EngineApiClientFactory {
  static EngineApiClient create({required String baseUrl}) {
    return HttpEngineApiClient(
      baseUrl: baseUrl,
      tokenProvider: const SupabaseAccessTokenProvider(),
    );
  }
}
