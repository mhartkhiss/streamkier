import 'dart:convert';
import 'package:http/http.dart' as http;

class AllMangaService {
  static const Map<String, String> hexMap = {
    "79": "A", "7a": "B", "7b": "C", "7c": "D", "7d": "E", "7e": "F", "7f": "G",
    "70": "H", "71": "I", "72": "J", "73": "K", "74": "L", "75": "M", "76": "N",
    "77": "O", "68": "P", "69": "Q", "6a": "R", "6b": "S", "6c": "T", "6d": "U",
    "6e": "V", "6f": "W", "60": "X", "61": "Y", "62": "Z", "59": "a", "5a": "b",
    "5b": "c", "5c": "d", "5d": "e", "5e": "f", "5f": "g", "50": "h", "51": "i",
    "52": "j", "53": "k", "54": "l", "55": "m", "56": "n", "57": "o", "48": "p",
    "49": "q", "4a": "r", "4b": "s", "4c": "t", "4d": "u", "4e": "v", "4f": "w",
    "40": "x", "41": "y", "42": "z", "08": "0", "09": "1", "0a": "2", "0b": "3",
    "0c": "4", "0d": "5", "0e": "6", "0f": "7", "00": "8", "01": "9", "15": "-",
    "16": ".", "67": "_", "46": "~", "02": ":", "17": "/", "07": "?", "1b": "#",
    "63": "[", "65": "]", "78": "@", "19": "!", "1c": "\$", "1e": "&", "10": "(",
    "11": ")", "12": "*", "13": "+", "14": ",", "03": ";", "05": "=", "1d": "%",
  };

  static String decodeAllanimeUrl(String encoded) {
    var raw = encoded;
    if (raw.startsWith("--")) raw = raw.substring(2);
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length - 1; i += 2) {
      final pair = raw.substring(i, i + 2);
      buffer.write(hexMap[pair] ?? pair);
    }
    return buffer.toString().replaceAll(r'\u002F', '/').replaceAll(r'\|', '');
  }

  /// Resolves the streaming link for an anime title and episode number
  Future<String?> resolveAnimeStream(String title, int episodeNum) async {
    try {
      // 1. Search for anime on AllAnime
      final searchUri = Uri.parse(
        'https://api.allanime.day/api?variables=${Uri.encodeComponent(jsonEncode({
          "search": {"query": title},
          "limit": 5,
          "page": 1,
          "translationType": "sub",
          "countryOrigin": "ALL",
        }))}&query=${Uri.encodeComponent('''
query(\$search: SearchInput, \$limit: Int, \$page: Int, \$translationType: VaildTranslationTypeEnumType, \$countryOrigin: VaildCountryEnumType) {
  shows(search: \$search, limit: \$limit, page: \$page, translationType: \$translationType, countryOrigin: \$countryOrigin) {
    edges {
      _id
      name
      availableEpisodesDetail
    }
  }
}
''')}',
      );

      final res = await http.get(searchUri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://allmanga.to',
      });

      if (res.statusCode != 200) return null;
      final searchData = jsonDecode(res.body);
      final edges = searchData['data']?['shows']?['edges'] as List? ?? [];
      if (edges.isEmpty) return null;

      final showId = edges[0]['_id'] as String;

      // 2. Fetch episode source
      final episodeUri = Uri.parse(
        'https://api.allanime.day/api?variables=${Uri.encodeComponent(jsonEncode({
          "showId": showId,
          "translationType": "sub",
          "episodeString": episodeNum.toString(),
        }))}&query=${Uri.encodeComponent('''
query(\$showId: String!, \$translationType: VaildTranslationTypeEnumType!, \$episodeString: String!) {
  episode(showId: \$showId, translationType: \$translationType, episodeString: \$episodeString) {
    sourceUrls
  }
}
''')}',
      );

      final epRes = await http.get(episodeUri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://allmanga.to',
      });

      if (epRes.statusCode != 200) return null;
      final epData = jsonDecode(epRes.body);
      final sourceUrls = epData['data']?['episode']?['sourceUrls'] as List? ?? [];

      for (final src in sourceUrls) {
        final rawUrl = src['sourceUrl']?.toString() ?? '';
        if (rawUrl.isNotEmpty) {
          final decoded = decodeAllanimeUrl(rawUrl);
          if (decoded.startsWith('http')) {
            return decoded;
          }
        }
      }
    } catch (_) {
      // Return null on scraping timeout or structure change
    }
    return null;
  }
}
