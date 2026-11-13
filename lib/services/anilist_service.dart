import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

class AnilistService {
  static const String _endpoint = 'https://graphql.anilist.co';

  static const String _mediaFields = '''
      id
      format
      title { romaji english native }
      description(asHtml: false)
      coverImage { extraLarge large }
      bannerImage
      genres
      averageScore
      episodes
      nextAiringEpisode { episode }
      startDate { year }
''';

  static const String _trendingQuery = '''
query (\$page: Int, \$perPage: Int) {
  Page(page: \$page, perPage: \$perPage) {
    media(type: ANIME, sort: TRENDING_DESC, isAdult: false) {
$_mediaFields
    }
  }
}
''';

  static const String _popularQuery = '''
query (\$page: Int, \$perPage: Int) {
  Page(page: \$page, perPage: \$perPage) {
    media(type: ANIME, sort: POPULARITY_DESC, isAdult: false) {
$_mediaFields
    }
  }
}
''';

  static const String _topRatedQuery = '''
query (\$page: Int, \$perPage: Int) {
  Page(page: \$page, perPage: \$perPage) {
    media(type: ANIME, sort: SCORE_DESC, isAdult: false) {
$_mediaFields
    }
  }
}
''';

  static const String _searchQuery = '''
query (\$search: String, \$page: Int, \$perPage: Int) {
  Page(page: \$page, perPage: \$perPage) {
    media(search: \$search, type: ANIME, sort: SEARCH_MATCH, isAdult: false) {
$_mediaFields
    }
  }
}
''';

  static const String _detailsQuery = '''
query (\$id: Int) {
  Media(id: \$id, type: ANIME) {
$_mediaFields
  }
}
''';

  Future<List<MediaItem>> getTrendingAnime({int page = 1, int perPage = 30}) async {
    return _fetchPage(_trendingQuery, {'page': page, 'perPage': perPage});
  }

  Future<List<MediaItem>> getPopularAnime({int page = 1, int perPage = 30}) async {
    return _fetchPage(_popularQuery, {'page': page, 'perPage': perPage});
  }

  Future<List<MediaItem>> getTopRatedAnime({int page = 1, int perPage = 30}) async {
    return _fetchPage(_topRatedQuery, {'page': page, 'perPage': perPage});
  }

  Future<List<MediaItem>> _fetchPage(String query, Map<String, dynamic> variables) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'query': query,
        'variables': variables,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      final mediaList = json['data']?['Page']?['media'] as List? ?? [];
      return mediaList.map((m) => MediaItem.fromAnilistJson(m)).toList();
    }
    return [];
  }

  Future<List<MediaItem>> searchAnime(String query, {int page = 1, int perPage = 20}) async {
    if (query.trim().isEmpty) return [];
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'query': _searchQuery,
        'variables': {'search': query, 'page': page, 'perPage': perPage},
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      final mediaList = json['data']?['Page']?['media'] as List? ?? [];
      return mediaList.map((m) => MediaItem.fromAnilistJson(m)).toList();
    }
    return [];
  }

  Future<MediaItem?> getAnimeDetails(int id) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'query': _detailsQuery,
        'variables': {'id': id},
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      final media = json['data']?['Media'];
      if (media != null) {
        return MediaItem.fromAnilistJson(media);
      }
    }
    return null;
  }

  static final Map<String, ({String? tmdbId, String? imdbId, int season})> _mappingCache = {};

  /// Resolves an AniList ID to its TMDB ID, IMDb ID, and mapped TMDB season number.
  Future<({String? tmdbId, String? imdbId, int season})?> resolveAnimeMapping(
    String anilistId,
  ) async {
    if (_mappingCache.containsKey(anilistId)) {
      return _mappingCache[anilistId];
    }
    try {
      final res = await http
          .get(Uri.parse('https://arm.haglund.dev/api/v2/ids?source=anilist&id=$anilistId'))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final tmdb = data?['themoviedb']?.toString();
        final imdb = data?['imdb']?.toString();
        final season = (data?['themoviedb-season'] as int?) ??
            (data?['thetvdb-season'] as int?) ??
            1;
        if ((tmdb != null && tmdb.isNotEmpty && tmdb != '0') ||
            (imdb != null && imdb.isNotEmpty)) {
          final result = (
            tmdbId: (tmdb != null && tmdb != '0') ? tmdb : null,
            imdbId: imdb,
            season: season > 0 ? season : 1,
          );
          _mappingCache[anilistId] = result;
          return result;
        }
      }

      // Fallback: check related anime (e.g. prequel or parent franchise entry)
      final idInt = int.tryParse(anilistId);
      if (idInt != null) {
        final detailsRes = await http
            .post(
              Uri.parse(_endpoint),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({
                'query': '''
query (\$id: Int) {
  Media(id: \$id) {
    relations {
      edges {
        node { id }
      }
    }
  }
}
''',
                'variables': {'id': idInt},
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (detailsRes.statusCode == 200) {
          final json = jsonDecode(detailsRes.body);
          final edges = json['data']?['Media']?['relations']?['edges'] as List? ?? [];
          for (final edge in edges) {
            final relId = edge['node']?['id']?.toString();
            if (relId != null && relId.isNotEmpty) {
              final relRes = await http
                  .get(Uri.parse('https://arm.haglund.dev/api/v2/ids?source=anilist&id=$relId'))
                  .timeout(const Duration(seconds: 3));
              if (relRes.statusCode == 200) {
                final relData = jsonDecode(relRes.body);
                final relTmdb = relData?['themoviedb']?.toString();
                final relImdb = relData?['imdb']?.toString();
                if ((relTmdb != null && relTmdb.isNotEmpty && relTmdb != '0') ||
                    (relImdb != null && relImdb.isNotEmpty)) {
                  final result = (
                    tmdbId: (relTmdb != null && relTmdb != '0') ? relTmdb : null,
                    imdbId: relImdb,
                    season: 1,
                  );
                  _mappingCache[anilistId] = result;
                  return result;
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // Return null on lookup timeout
    }
    return null;
  }

  Future<String?> resolveTmdbId(String anilistId) async {
    final mapping = await resolveAnimeMapping(anilistId);
    return mapping?.tmdbId ?? mapping?.imdbId;
  }
}
