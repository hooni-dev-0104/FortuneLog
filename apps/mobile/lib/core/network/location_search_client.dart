import 'dart:convert';

import 'package:http/http.dart' as http;

class LocationSuggestion {
  const LocationSuggestion({required this.label, required this.value});

  final String label;
  final String value;

  @override
  String toString() => label;
}

class LocationSearchClient {
  LocationSearchClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Nominatim is a convenient, keyless option for prototypes.
  // If we outgrow its usage policy / rate limits, swap this for a paid provider.
  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<LocationSuggestion>> searchKoreaCities(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '10',
        // Restrict to KR to match our current product assumptions.
        'countrycodes': 'kr',
        // Request Korean result strings when possible.
        'accept-language': 'ko',
        'q': q,
      },
    );

    final res = await _client.get(
      uri,
      headers: const {
        // Nominatim requires a valid UA; keep it stable and non-empty.
        'User-Agent': 'FortuneLog/0.1 (mobile)',
        'Accept': 'application/json',
        'Accept-Language': 'ko',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('location search failed: ${res.statusCode}');
    }

    final raw = jsonDecode(utf8.decode(res.bodyBytes));
    if (raw is! List) return const [];

    final out = <LocationSuggestion>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final displayName = item['display_name']?.toString().trim();
      final address = item['address'];
      if (displayName == null || displayName.isEmpty) continue;

      String city = '';
      String region = '';
      if (address is Map) {
        // Prefer larger "city" buckets; fall back to smaller or county-level.
        city = (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'] ??
                address['county'] ??
                '')
            .toString()
            .trim();
        region = (address['state'] ?? address['province'] ?? '').toString().trim();
      }

      final label = (city.isNotEmpty && region.isNotEmpty && city != region) ? '$city ($region)' : (city.isNotEmpty ? city : displayName.split(',').first);
      final value = city.isNotEmpty ? city : displayName.split(',').first.trim();
      out.add(LocationSuggestion(label: label, value: value));
    }

    // De-dup by value while preserving order.
    final seen = <String>{};
    return out.where((s) => seen.add(s.value)).toList(growable: false);
  }

  void dispose() {
    _client.close();
  }
}

