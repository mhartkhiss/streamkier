import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/episode.dart';
import '../models/media_item.dart';

class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  final String apiKey;

  TmdbService({required this.apiKey});

  Map<String, String> _buildHeaders() {
    if (apiKey.length > 50) {
      return {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };
    }
    return {'Content-Type': 'application/json'};
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final params = Map<String, String>.from(queryParams ?? {});
    if (apiKey.length <= 50) {
      params['api_key'] = apiKey;
    }
    return Uri.parse('$_baseUrl$path').replace(queryParameters: params);
  }

  bool get hasValidKey =>
      apiKey.trim().isNotEmpty && apiKey.trim() != 'e3f0efdcfb767eb2d8b5c9dc7265be00';

  Future<dynamic> _get(String path, [Map<String, String>? queryParams]) async {
    if (!hasValidKey) {
      return {'results': []};
    }
    final uri = _buildUri(path, queryParams);
    final response = await http.get(uri, headers: _buildHeaders());
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('TMDB API error ${response.statusCode}: ${response.body}');
    }
  }

  Future<List<MediaItem>> getTrending({String timeWindow = 'day'}) async {
    final data = await _get('/trending/all/$timeWindow');
    final results = data['results'] as List? ?? [];
    return results
        .where((item) => item['media_type'] == 'movie' || item['media_type'] == 'tv')
        .map((item) => MediaItem.fromTmdbJson(item))
        .toList();
  }

  Future<List<MediaItem>> getPopularMovies() async {
    final data = await _get('/movie/popular');
    final results = data['results'] as List? ?? [];
    return results
        .map((item) => MediaItem.fromTmdbJson(item, explicitType: MediaType.movie))
        .toList();
  }

  Future<List<MediaItem>> getPopularTv() async {
    final data = await _get('/tv/popular');
    final results = data['results'] as List? ?? [];
    return results
        .map((item) => MediaItem.fromTmdbJson(item, explicitType: MediaType.tv))
        .toList();
  }

  Future<List<MediaItem>> getPopularDramas() async {
    final data = await _get('/discover/tv', {
      'with_genres': '18',
      'with_origin_country': 'KR|CN|JP|TW|TH',
      'without_genres': '16',
      'sort_by': 'popularity.desc',
    });
    final results = data['results'] as List? ?? [];
    return results
        .map((item) => MediaItem.fromTmdbJson(item, explicitType: MediaType.drama))
        .toList();
  }

  Future<List<MediaItem>> getTopRatedMovies() async {
    final data = await _get('/movie/top_rated');
    final results = data['results'] as List? ?? [];
    return results
        .map((item) => MediaItem.fromTmdbJson(item, explicitType: MediaType.movie))
        .toList();
  }

  Future<List<MediaItem>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/search/multi', {'query': query});
    final results = data['results'] as List? ?? [];
    return results
        .where((item) => item['media_type'] == 'movie' || item['media_type'] == 'tv')
        .map((item) => MediaItem.fromTmdbJson(item))
        .toList();
  }

  Future<MediaItem> getMovieDetails(String id) async {
    final data = await _get('/movie/$id');
    return MediaItem.fromTmdbJson(data, explicitType: MediaType.movie);
  }

  Future<MediaItem> getTvDetails(String id) async {
    final data = await _get('/tv/$id');
    return MediaItem.fromTmdbJson(data, explicitType: MediaType.tv);
  }

  Future<List<Episode>> getSeasonEpisodes(String tvId, int seasonNumber) async {
    final data = await _get('/tv/$tvId/season/$seasonNumber');
    final episodes = data['episodes'] as List? ?? [];
    return episodes.map((e) => Episode.fromTmdbJson(e, seasonNumber)).toList();
  }

  Future<List<MediaItem>> getSimilar(MediaType type, String id) async {
    final endpoint = type == MediaType.movie ? '/movie/$id/similar' : '/tv/$id/similar';
    final data = await _get(endpoint);
    final results = data['results'] as List? ?? [];
    return results.map((item) => MediaItem.fromTmdbJson(item, explicitType: type)).toList();
  }
}
