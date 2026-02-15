import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/engine_api_client.dart';

class SajuChartPersistence {
  static Future<void> ensureSavedFromResponse({
    required SupabaseClient supabase,
    required String userId,
    required String birthProfileId,
    required ChartResponseDto response,
  }) async {
    // If the engine already persisted it (or another run did), don't insert again.
    final rows = await supabase
        .from('saju_charts')
        .select('id')
        .eq('user_id', userId)
        .eq('birth_profile_id', birthProfileId)
        .eq('engine_version', response.engineVersion)
        .order('created_at', ascending: false)
        .limit(1);

    if ((rows as List).isNotEmpty) return;

    await supabase.from('saju_charts').insert({
      'user_id': userId,
      'birth_profile_id': birthProfileId,
      'chart_json': response.chart,
      'five_elements_json': response.fiveElements,
      'engine_version': response.engineVersion,
    });
  }
}

