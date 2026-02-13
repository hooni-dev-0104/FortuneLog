import 'package:supabase_flutter/supabase_flutter.dart';

import 'http_engine_api_client.dart';

class SupabaseAccessTokenProvider implements AccessTokenProvider {
  const SupabaseAccessTokenProvider();

  @override
  Future<String?> getAccessToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken;
  }
}
