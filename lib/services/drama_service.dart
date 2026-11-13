import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/episode.dart';
import '../models/media_item.dart';

class DramaService {
  static const String _cinemetaBase = 'https://v3-cinemeta.strem.io';
  static const String _tvmazeBase = 'https://api.tvmaze.com';

  // Cache of resolved details & seasons per item key (imdbId or id)
  static final Map<String, ({MediaItem details, Map<int, List<Episode>> seasons})>
      _detailsCache = {};

  /// Curated fan-favorite Asian Dramas (K-Dramas, C-Dramas, J-Dramas) with pre-resolved
  /// TMDB and IMDb IDs for instant browsing and 1-click streaming without an API key.
  static final List<MediaItem> _featuredAsianDramas = [
    const MediaItem(
      id: '93405',
      tmdbId: '93405',
      imdbId: 'tt10919420',
      title: 'Squid Game',
      overview:
          'Hundreds of cash-strapped players accept a strange invitation to compete in children\'s games. Inside, a tempting prize awaits with deadly high stakes.',
      posterPath: 'https://images.metahub.space/poster/small/tt10919420/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt10919420/img',
      mediaType: MediaType.drama,
      rating: 7.9,
      releaseDate: '2021',
      genres: ['K-Drama', 'Thriller', 'Mystery'],
      numberOfSeasons: 3,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '215720',
      tmdbId: '215720',
      imdbId: 'tt27668559',
      title: 'Queen of Tears',
      overview:
          'The queen of department stores and the prince of supermarkets weather a marital crisis—until love miraculously begins to bloom again.',
      posterPath: 'https://images.metahub.space/poster/small/tt27668559/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt27668559/img',
      mediaType: MediaType.drama,
      rating: 8.3,
      releaseDate: '2024',
      genres: ['K-Drama', 'Romance', 'Comedy'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '94796',
      tmdbId: '94796',
      imdbId: 'tt10850932',
      title: 'Crash Landing on You',
      overview:
          'A South Korean chaebol heiress makes an emergency paragliding landing in North Korea and falls in love with an army officer who decides to help her hide.',
      posterPath: 'https://images.metahub.space/poster/small/tt10850932/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt10850932/img',
      mediaType: MediaType.drama,
      rating: 8.7,
      releaseDate: '2019',
      genres: ['K-Drama', 'Romance', 'Drama'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '230923',
      tmdbId: '230923',
      imdbId: 'tt31495564',
      title: 'Lovely Runner',
      overview:
          'Devastated by the tragic loss of her favorite star, a devoted fan travels back in time to 2008 determined to change his fate.',
      posterPath: 'https://images.metahub.space/poster/small/tt31495564/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt31495564/img',
      mediaType: MediaType.drama,
      rating: 8.6,
      releaseDate: '2024',
      genres: ['K-Drama', 'Romance', 'Fantasy'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '135157',
      tmdbId: '135157',
      imdbId: 'tt20859920',
      title: 'Alchemy of Souls',
      overview:
          'A powerful sorceress in a blind woman\'s body encounters a man from a prestigious family, who wants her help to change his destiny.',
      posterPath: 'https://images.metahub.space/poster/small/tt20859920/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt20859920/img',
      mediaType: MediaType.drama,
      rating: 8.7,
      releaseDate: '2022',
      genres: ['K-Drama', 'Fantasy', 'Romance'],
      numberOfSeasons: 2,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '136283',
      tmdbId: '136283',
      imdbId: 'tt21344706',
      title: 'The Glory',
      overview:
          'Years after surviving horrific abuse in high school, a woman puts an elaborate revenge scheme in motion to make the perpetrators pay for their crimes.',
      posterPath: 'https://images.metahub.space/poster/small/tt21344706/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt21344706/img',
      mediaType: MediaType.drama,
      rating: 8.1,
      releaseDate: '2022',
      genres: ['K-Drama', 'Thriller', 'Drama'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '67915',
      tmdbId: '67915',
      imdbId: 'tt5994364',
      title: 'Guardian: The Lonely and Great God (Goblin)',
      overview:
          'In his quest for abride to break his cursed immortality, a 939-year-old guardian of souls meets a grim reaper and a sprightly student with a tragic past.',
      posterPath: 'https://images.metahub.space/poster/small/tt5994364/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt5994364/img',
      mediaType: MediaType.drama,
      rating: 8.6,
      releaseDate: '2016',
      genres: ['K-Drama', 'Fantasy', 'Romance'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '117376',
      tmdbId: '117376',
      imdbId: 'tt13433812',
      title: 'Vincenzo',
      overview:
          'During a visit to his motherland, a Korean-Italian mafia lawyer gives an unrivaled conglomerate a taste of its own medicine with a side of justice.',
      posterPath: 'https://images.metahub.space/poster/small/tt13433812/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt13433812/img',
      mediaType: MediaType.drama,
      rating: 8.4,
      releaseDate: '2021',
      genres: ['K-Drama', 'Crime', 'Comedy'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '110316',
      tmdbId: '110316',
      imdbId: 'tt10795658',
      title: 'Alice in Borderland',
      overview:
          'An obsessed gamer and two friends find themselves in a parallel Tokyo, where they must compete in a series of sadistic games to survive.',
      posterPath: 'https://images.metahub.space/poster/small/tt10795658/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt10795658/img',
      mediaType: MediaType.drama,
      rating: 7.7,
      releaseDate: '2020',
      genres: ['J-Drama', 'Sci-Fi', 'Thriller'],
      numberOfSeasons: 2,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '99966',
      tmdbId: '99966',
      imdbId: 'tt14169960',
      title: 'All of Us Are Dead',
      overview:
          'A high school becomes ground zero for a zombie virus outbreak. Trapped students must fight their way out—or turn into one of the rabid infected.',
      posterPath: 'https://images.metahub.space/poster/small/tt14169960/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt14169960/img',
      mediaType: MediaType.drama,
      rating: 7.5,
      releaseDate: '2022',
      genres: ['K-Drama', 'Action', 'Thriller'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '210733',
      tmdbId: '210733',
      imdbId: 'tt27995594',
      title: 'Hidden Love',
      overview:
          'Sang Zhi falls in love with Duan Jiaxu, a boy who often comes to her house to play games in her older brother\'s room, and their bond blossoms years later.',
      posterPath: 'https://images.metahub.space/poster/small/tt27995594/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt27995594/img',
      mediaType: MediaType.drama,
      rating: 8.5,
      releaseDate: '2023',
      genres: ['C-Drama', 'Romance', 'Youth'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '154825',
      tmdbId: '154825',
      imdbId: 'tt17513352',
      title: 'Business Proposal',
      overview:
          'In disguise as her friend, Ha-ri shows up to a blind date to scare him away. But plans go awry when he turns out to be her CEO—and makes a proposal.',
      posterPath: 'https://images.metahub.space/poster/small/tt17513352/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt17513352/img',
      mediaType: MediaType.drama,
      rating: 8.1,
      releaseDate: '2022',
      genres: ['K-Drama', 'Romance', 'Comedy'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
  ];

  /// Fetches popular/trending Drama series from Cinemeta (no API key needed).
  Future<List<MediaItem>> getTrendingDramas() async {
    try {
      final response = await http
          .get(Uri.parse('$_cinemetaBase/catalog/series/top/genre=Drama.json'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final metas = data['metas'] as List? ?? [];
        final parsed = metas
            .whereType<Map<String, dynamic>>()
            .where((m) => (m['name'] ?? '').toString() != '#DUPE#')
            .map((m) => MediaItem.fromCinemetaJson(m, explicitType: MediaType.drama))
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}
    return _featuredAsianDramas;
  }

  /// Curated AI & Sci-Fi Dramas (K-Drama & Global AI/Android/Robotics/Cyber Dramas)
  /// with pre-resolved TMDB and IMDb IDs for instant 1-click streaming.
  static final List<MediaItem> _featuredAiDramas = [
    const MediaItem(
      id: '96648',
      tmdbId: '96648',
      imdbId: 'tt11580874',
      title: 'My Holo Love',
      overview:
          'A lonely woman with face blindness finds a kindred spirit when she gets to know a humanlike AI hologram modeled after its prickly creator.',
      posterPath: 'https://images.metahub.space/poster/small/tt11580874/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt11580874/img',
      mediaType: MediaType.drama,
      rating: 7.7,
      releaseDate: '2020',
      genres: ['AI Drama', 'K-Drama', 'Sci-Fi', 'Romance'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '79430',
      tmdbId: '79430',
      imdbId: 'tt7225520',
      title: 'Are You Human?',
      overview:
          'When a young heir falls into a coma, his mother—a brilliant AI scientist—builds an android replica named Nam Shin III to take his place.',
      posterPath: 'https://images.metahub.space/poster/small/tt7225520/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt7225520/img',
      mediaType: MediaType.drama,
      rating: 8.0,
      releaseDate: '2018',
      genres: ['AI Drama', 'K-Drama', 'Sci-Fi', 'Romance'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '75219',
      tmdbId: '75219',
      imdbId: 'tt7521816',
      title: 'I Am Not a Robot',
      overview:
          'A wealthy young man with a severe allergy to other people falls in love with a woman who is pretending to be an advanced humanoid AI robot.',
      posterPath: 'https://images.metahub.space/poster/small/tt7521816/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt7521816/img',
      mediaType: MediaType.drama,
      rating: 8.1,
      releaseDate: '2017',
      genres: ['AI Drama', 'K-Drama', 'Romance', 'Comedy'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '101608',
      tmdbId: '101608',
      imdbId: 'tt12058860',
      title: 'SF8',
      overview:
          'An anthology sci-fi drama series exploring AI caregiving robots, virtual reality, android detectives, and humanity in a near-future Korea.',
      posterPath: 'https://images.metahub.space/poster/small/tt12058860/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt12058860/img',
      mediaType: MediaType.drama,
      rating: 7.2,
      releaseDate: '2020',
      genres: ['AI Drama', 'K-Drama', 'Sci-Fi'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '246672',
      tmdbId: '246672',
      imdbId: 'tt30988739',
      title: 'Cassandra',
      overview:
          'A family moves into Germany\'s oldest smart home—unaware that the house is controlled by Cassandra, a ruthless 1970s AI assistant determined never to be abandoned again.',
      posterPath: 'https://images.metahub.space/poster/small/tt30988739/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt30988739/img',
      mediaType: MediaType.drama,
      rating: 7.4,
      releaseDate: '2025',
      genres: ['AI Drama', 'Thriller', 'Sci-Fi'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '155533',
      tmdbId: '155533',
      imdbId: 'tt18070898',
      title: 'Sunny',
      overview:
          'An American woman living in Kyoto whose husband and son vanish in a mysterious plane crash is given Sunny, a domestic AI robot made by her husband\'s electronics company.',
      posterPath: 'https://images.metahub.space/poster/small/tt18070898/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt18070898/img',
      mediaType: MediaType.drama,
      rating: 7.1,
      releaseDate: '2024',
      genres: ['AI Drama', 'Mystery', 'Sci-Fi'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '42009',
      tmdbId: '42009',
      imdbId: 'tt2085059',
      title: 'Black Mirror',
      overview:
          'Over the last ten years, artificial intelligence and technology have transformed almost every aspect of our lives before we\'ve had time to stop and question it.',
      posterPath: 'https://images.metahub.space/poster/small/tt2085059/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt2085059/img',
      mediaType: MediaType.drama,
      rating: 8.7,
      releaseDate: '2011',
      genres: ['AI Drama', 'Sci-Fi', 'Thriller'],
      numberOfSeasons: 7,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '63247',
      tmdbId: '63247',
      imdbId: 'tt0475784',
      title: 'Westworld',
      overview:
          'A dark odyssey about the dawn of artificial consciousness and the evolution of sin in a futuristic theme park populated by AI hosts.',
      posterPath: 'https://images.metahub.space/poster/small/tt0475784/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt0475784/img',
      mediaType: MediaType.drama,
      rating: 8.5,
      releaseDate: '2016',
      genres: ['AI Drama', 'Sci-Fi', 'Mystery'],
      numberOfSeasons: 4,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '62699',
      tmdbId: '62699',
      imdbId: 'tt4122068',
      title: 'Humans',
      overview:
          'In a parallel present where the latest must-have gadget for any busy family is a Synth—a highly-developed robotic AI servant eerily similar to a real human.',
      posterPath: 'https://images.metahub.space/poster/small/tt4122068/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt4122068/img',
      mediaType: MediaType.drama,
      rating: 7.9,
      releaseDate: '2015',
      genres: ['AI Drama', 'Sci-Fi', 'Drama'],
      numberOfSeasons: 3,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '88046',
      tmdbId: '88046',
      imdbId: 'tt9140342',
      title: 'Better Than Us',
      overview:
          'A family on the brink of splitting up becomes the owners of Arisa, a cutting-edge empathetic AI android being hunted by a powerful corporation and homicide detectives.',
      posterPath: 'https://images.metahub.space/poster/small/tt9140342/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt9140342/img',
      mediaType: MediaType.drama,
      rating: 7.4,
      releaseDate: '2018',
      genres: ['AI Drama', 'Sci-Fi', 'Thriller'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '108545',
      tmdbId: '108545',
      imdbId: 'tt13016388',
      title: '3 Body Problem',
      overview:
          'Across continents and decades, five brilliant friends make earth-shattering discoveries in AI, quantum physics, and virtual reality as the laws of science unravel.',
      posterPath: 'https://images.metahub.space/poster/small/tt13016388/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt13016388/img',
      mediaType: MediaType.drama,
      rating: 7.7,
      releaseDate: '2024',
      genres: ['AI Drama', 'Sci-Fi', 'Mystery'],
      numberOfSeasons: 1,
      source: 'cinemeta',
    ),
    const MediaItem(
      id: '95396',
      tmdbId: '95396',
      imdbId: 'tt11280740',
      title: 'Severance',
      overview:
          'Mark leads a team of office workers whose memories have been surgically divided between their work and personal lives by a mysterious biotech corporation.',
      posterPath: 'https://images.metahub.space/poster/small/tt11280740/img',
      backdropPath: 'https://images.metahub.space/background/medium/tt11280740/img',
      mediaType: MediaType.drama,
      rating: 8.7,
      releaseDate: '2022',
      genres: ['AI Drama', 'Sci-Fi', 'Thriller'],
      numberOfSeasons: 2,
      source: 'cinemeta',
    ),
  ];

  /// Returns curated and live-enriched AI & Sci-Fi Dramas.
  Future<List<MediaItem>> getAiDramas() async {
    return List<MediaItem>.from(_featuredAiDramas);
  }

  /// Fetches Asian Dramas (K-Dramas, C-Dramas, J-Dramas) combining featured classics
  /// with live airing Asian dramas from TVMaze.
  Future<List<MediaItem>> getAsianDramas() async {
    final List<MediaItem> combined = List<MediaItem>.from(_featuredAsianDramas);
    final seenTitles = combined.map((e) => e.title.toLowerCase()).toSet();

    try {
      final response = await http
          .get(Uri.parse('$_tvmazeBase/schedule/web'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final list = jsonDecode(response.body) as List? ?? [];
        for (final entry in list) {
          final show = entry['_embedded']?['show'] as Map<String, dynamic>?;
          if (show == null) continue;
          final lang = (show['language'] ?? '').toString();
          if (!const {'Korean', 'Chinese', 'Japanese', 'Thai'}.contains(lang)) {
            continue;
          }
          final item = MediaItem.fromTvMazeJson(show, explicitType: MediaType.drama);
          final key = item.title.toLowerCase();
          if (item.posterPath != null && !seenTitles.contains(key)) {
            seenTitles.add(key);
            combined.add(item);
          }
        }
      }
    } catch (_) {}

    return combined;
  }

  /// Key-free fallback for Popular Movies using Cinemeta.
  Future<List<MediaItem>> getPopularMoviesFallback() async {
    try {
      final response = await http
          .get(Uri.parse('$_cinemetaBase/catalog/movie/top.json'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final metas = data['metas'] as List? ?? [];
        return metas
            .whereType<Map<String, dynamic>>()
            .take(30)
            .map((m) => MediaItem.fromCinemetaJson(m, explicitType: MediaType.movie))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Key-free fallback for Popular TV Shows using Cinemeta.
  Future<List<MediaItem>> getPopularTvFallback() async {
    try {
      final response = await http
          .get(Uri.parse('$_cinemetaBase/catalog/series/top.json'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final metas = data['metas'] as List? ?? [];
        return metas
            .whereType<Map<String, dynamic>>()
            .take(30)
            .map((m) => MediaItem.fromCinemetaJson(m, explicitType: MediaType.tv))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Searches Dramas, TV Series, and Movies across TVMaze and Cinemeta without an API key.
  Future<List<MediaItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final encoded = Uri.encodeComponent(trimmed);

    final results = await Future.wait([
      _searchTvMaze(encoded),
      _searchCinemeta('series', encoded),
      _searchCinemeta('movie', encoded),
    ]);

    final List<MediaItem> merged = [];
    final Set<String> seen = {};

    for (final list in results) {
      for (final item in list) {
        if (item.title == '#DUPE#') continue;
        final key = '${item.title.toLowerCase()}_${item.mediaType.name}';
        if (!seen.contains(key)) {
          seen.add(key);
          merged.add(item);
        }
      }
    }
    return merged;
  }

  Future<List<MediaItem>> _searchTvMaze(String encodedQuery) async {
    try {
      final response = await http
          .get(Uri.parse('$_tvmazeBase/search/shows?q=$encodedQuery'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final list = jsonDecode(response.body) as List? ?? [];
        return list.whereType<Map<String, dynamic>>().map((entry) {
          final show = entry['show'] as Map<String, dynamic>? ?? entry;
          final lang = (show['language'] ?? '').toString();
          final genres = (show['genres'] as List?)?.map((g) => g.toString()).toList() ?? [];
          final isDrama = const {'Korean', 'Chinese', 'Japanese', 'Thai'}.contains(lang) ||
              genres.any((g) => g.toLowerCase().contains('drama') || g.toLowerCase().contains('romance'));
          return MediaItem.fromTvMazeJson(
            show,
            explicitType: isDrama ? MediaType.drama : MediaType.tv,
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<MediaItem>> _searchCinemeta(String type, String encodedQuery) async {
    try {
      final response = await http
          .get(Uri.parse('$_cinemetaBase/catalog/$type/top/search=$encodedQuery.json'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final metas = data['metas'] as List? ?? [];
        return metas
            .whereType<Map<String, dynamic>>()
            .where((m) => (m['name'] ?? '').toString() != '#DUPE#')
            .map((m) => MediaItem.fromCinemetaJson(m))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Resolves full details, TMDB ID, and all seasons/episodes for a Drama, TV Show, or Movie.
  Future<({MediaItem details, Map<int, List<Episode>> seasons})?> getDetailsAndSeasons(
    MediaItem item,
  ) async {
    final cacheKey = item.imdbId ?? '${item.source}_${item.id}';
    if (_detailsCache.containsKey(cacheKey)) {
      return _detailsCache[cacheKey];
    }

    String? imdbId = item.imdbId ?? (item.id.startsWith('tt') ? item.id : null);

    // If from TVMaze without imdbId, try searching Cinemeta by title to find imdbId/tmdbId
    if (imdbId == null || imdbId.isEmpty) {
      final searchMatches = await _searchCinemeta(
        item.mediaType == MediaType.movie ? 'movie' : 'series',
        Uri.encodeComponent(item.title),
      );
      if (searchMatches.isNotEmpty) {
        imdbId = searchMatches.first.imdbId;
      }
    }

    final Map<int, List<Episode>> seasonsMap = {};
    MediaItem updatedItem = item;

    if (imdbId != null && imdbId.isNotEmpty) {
      try {
        final metaType = item.mediaType == MediaType.movie ? 'movie' : 'series';
        final response = await http
            .get(Uri.parse('$_cinemetaBase/meta/$metaType/$imdbId.json'))
            .timeout(const Duration(seconds: 6));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          final meta = data['meta'] as Map<String, dynamic>?;
          if (meta != null) {
            final parsedMeta = MediaItem.fromCinemetaJson(
              meta,
              explicitType: item.mediaType,
            );

            final videos = meta['videos'] as List? ?? [];
            for (final v in videos.whereType<Map<String, dynamic>>()) {
              final ep = Episode.fromCinemetaJson(v);
              if (ep.seasonNumber <= 0) continue; // Skip specials (Season 0)
              seasonsMap.putIfAbsent(ep.seasonNumber, () => []).add(ep);
            }

            for (final list in seasonsMap.values) {
              list.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
            }

            updatedItem = item.copyWith(
              overview: parsedMeta.overview.isNotEmpty ? parsedMeta.overview : item.overview,
              posterPath: item.posterPath ?? parsedMeta.posterPath,
              backdropPath: parsedMeta.backdropPath ?? item.backdropPath,
              rating: parsedMeta.rating > 0 ? parsedMeta.rating : item.rating,
              releaseDate: (item.releaseDate == null || item.releaseDate!.isEmpty)
                  ? parsedMeta.releaseDate
                  : item.releaseDate,
              genres: parsedMeta.genres.isNotEmpty ? parsedMeta.genres : item.genres,
              numberOfSeasons: seasonsMap.isNotEmpty ? seasonsMap.keys.length : item.numberOfSeasons,
              tmdbId: parsedMeta.tmdbId ?? item.tmdbId,
              imdbId: imdbId,
            );
          }
        }
      } catch (_) {}
    }

    // Fallback to TVMaze episodes if seasonsMap is still empty and source is tvmaze
    if (seasonsMap.isEmpty && item.source == 'tvmaze') {
      try {
        final response = await http
            .get(Uri.parse('$_tvmazeBase/shows/${item.id}/episodes'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final list = jsonDecode(response.body) as List? ?? [];
          for (final e in list.whereType<Map<String, dynamic>>()) {
            final ep = Episode.fromTvMazeJson(e);
            if (ep.seasonNumber <= 0) continue;
            seasonsMap.putIfAbsent(ep.seasonNumber, () => []).add(ep);
          }
          if (seasonsMap.isNotEmpty) {
            updatedItem = updatedItem.copyWith(
              numberOfSeasons: seasonsMap.keys.length,
            );
          }
        }
      } catch (_) {}
    }

    final result = (details: updatedItem, seasons: seasonsMap);
    _detailsCache[cacheKey] = result;
    return result;
  }
}
