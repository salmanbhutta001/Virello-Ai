import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches real Google Trends directly from the phone.
///
/// Why client-side? Google blocks data-center IPs (like Railway/VPS).
/// The phone has a residential IP, so Google serves real trend data.
/// No API key needed — uses Google's public daily trends endpoint.
class TrendsService {
  static const _baseUrl = 'https://trends.google.com/trends/api/dailytrends';

  /// Fetch trending searches for a region (ISO code, e.g. "US", "PK").
  /// Returns a list of {query, source, geo, type} maps.
  /// Returns empty list (never fake data) if Google is unreachable.
  static Future<List<Map<String, String>>> fetchTrends({
    String geo = 'US',
    int limit = 10,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl?hl=en-US&tz=-300&geo=${geo.toUpperCase()}');
      final resp = await http.get(url, headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return [];

      // Google prefixes JSON with )]}', — strip it
      var body = resp.body.trim();
      if (body.startsWith(")]}'")) {
        body = body.substring(4).trim();
      }

      final data = json.decode(body) as Map<String, dynamic>;
      final days = data['default']?['trendingSearchesDays'] as List? ?? [];

      final trends = <Map<String, String>>[];
      for (final day in days) {
        final searches = (day as Map)['trendingSearches'] as List? ?? [];
        for (final s in searches) {
          final title = (s as Map)['title']?['query'] as String?;
          if (title != null && title.trim().isNotEmpty) {
            trends.add({
              'query': title.trim(),
              'source': 'Google Trends',
              'geo': geo.toUpperCase(),
              'type': 'trend',
            });
            if (trends.length >= limit) break;
          }
        }
        if (trends.length >= limit) break;
      }
      return trends;
    } catch (_) {
      // Network blocked, parse failed, etc. — honest empty, never fake.
      return [];
    }
  }
}
