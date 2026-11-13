enum MediaType { movie, tv, drama, anime }

class MediaItem {
  final String id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final MediaType mediaType;
  final double rating;
  final String? releaseDate;
  final List<String> genres;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final String source; // 'tmdb', 'anilist', 'cinemeta', or 'tvmaze'
  final String? tmdbId; // Resolved TMDB ID for streaming providers
  final String? imdbId; // Resolved IMDb ID (tt...) for metadata & streaming

  const MediaItem({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.mediaType,
    this.rating = 0.0,
    this.releaseDate,
    this.genres = const [],
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.source = 'tmdb',
    this.tmdbId,
    this.imdbId,
  });

  String get effectiveTmdbId {
    if (tmdbId != null && tmdbId!.isNotEmpty) return tmdbId!;
    if (source == 'tmdb') return id;
    if (imdbId != null && imdbId!.isNotEmpty) return imdbId!;
    if (id.startsWith('tt')) return id;
    return '';
  }

  MediaItem copyWith({
    String? id,
    String? title,
    String? overview,
    String? posterPath,
    String? backdropPath,
    MediaType? mediaType,
    double? rating,
    String? releaseDate,
    List<String>? genres,
    int? numberOfSeasons,
    int? numberOfEpisodes,
    String? source,
    String? tmdbId,
    String? imdbId,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      mediaType: mediaType ?? this.mediaType,
      rating: rating ?? this.rating,
      releaseDate: releaseDate ?? this.releaseDate,
      genres: genres ?? this.genres,
      numberOfSeasons: numberOfSeasons ?? this.numberOfSeasons,
      numberOfEpisodes: numberOfEpisodes ?? this.numberOfEpisodes,
      source: source ?? this.source,
      tmdbId: tmdbId ?? this.tmdbId,
      imdbId: imdbId ?? this.imdbId,
    );
  }

  String? get posterUrl {
    if (posterPath == null || posterPath!.isEmpty) return null;
    if (posterPath!.startsWith('http')) return posterPath;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  String? get backdropUrl {
    if (backdropPath == null || backdropPath!.isEmpty) return null;
    if (backdropPath!.startsWith('http')) return backdropPath;
    return 'https://image.tmdb.org/t/p/w1280$backdropPath';
  }

  String get year {
    if (releaseDate == null || releaseDate!.isEmpty) return '';
    return releaseDate!.split('-').first;
  }

  factory MediaItem.fromTmdbJson(Map<String, dynamic> json, {MediaType? explicitType}) {
    final isMovie = explicitType == MediaType.movie ||
        json['media_type'] == 'movie' ||
        json.containsKey('title');

    final title = json['title'] ?? json['name'] ?? 'Untitled';
    final releaseDate = json['release_date'] ?? json['first_air_date'] ?? '';

    List<String> parsedGenres = [];
    if (json['genres'] != null && json['genres'] is List) {
      parsedGenres = (json['genres'] as List)
          .map((g) => g['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final originCountries = (json['origin_country'] as List?)
            ?.map((c) => c.toString().toUpperCase())
            .toList() ??
        [];
    final genreIds = (json['genre_ids'] as List?)
            ?.map((g) => int.tryParse(g.toString()) ?? 0)
            .toList() ??
        [];
    final isAsianOrigin = originCountries.any(
      (c) => const {'KR', 'CN', 'JP', 'TW', 'TH', 'HK', 'PH'}.contains(c),
    );
    final hasDramaGenre = genreIds.contains(18) ||
        parsedGenres.any((g) => g.toLowerCase().contains('drama'));

    MediaType resolvedType;
    if (explicitType != null) {
      resolvedType = explicitType;
    } else if (isMovie) {
      resolvedType = MediaType.movie;
    } else if (isAsianOrigin && hasDramaGenre && !genreIds.contains(16)) {
      resolvedType = MediaType.drama;
    } else {
      resolvedType = MediaType.tv;
    }

    return MediaItem(
      id: json['id'].toString(),
      title: title,
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      mediaType: resolvedType,
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseDate: releaseDate,
      genres: parsedGenres,
      numberOfSeasons: json['number_of_seasons'],
      numberOfEpisodes: json['number_of_episodes'],
      source: 'tmdb',
      tmdbId: json['id'].toString(),
    );
  }

  factory MediaItem.fromCinemetaJson(
    Map<String, dynamic> json, {
    MediaType? explicitType,
  }) {
    final imdbId = (json['imdb_id'] ?? json['id'])?.toString() ?? '';
    final tmdbId = json['moviedb_id']?.toString();
    final rawGenres = json['genre'] ?? json['genres'];
    final genresList = (rawGenres is List)
        ? rawGenres.map((g) => g.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final country = (json['country'] ?? '').toString().toLowerCase();
    final isAsianDrama = country.contains('korea') ||
        country.contains('china') ||
        country.contains('japan') ||
        country.contains('taiwan') ||
        country.contains('thailand') ||
        country.contains('hong kong') ||
        country.contains('philippines');
    final hasDramaGenre = genresList.any((g) => g.toLowerCase().contains('drama'));

    MediaType resolvedType;
    if (explicitType != null) {
      resolvedType = explicitType;
    } else if (json['type'] == 'movie') {
      resolvedType = MediaType.movie;
    } else if (isAsianDrama || hasDramaGenre) {
      resolvedType = MediaType.drama;
    } else {
      resolvedType = MediaType.tv;
    }

    final rawYear = (json['releaseInfo'] ?? json['year'] ?? '').toString();
    final cleanYear = rawYear.split(RegExp(r'[-–]')).first.trim();
    final poster = json['poster']?.toString();
    final background = json['background']?.toString() ?? poster;
    final ratingVal = double.tryParse((json['imdbRating'] ?? '').toString()) ?? 0.0;

    return MediaItem(
      id: (tmdbId != null && tmdbId.isNotEmpty) ? tmdbId : imdbId,
      title: (json['name'] ?? json['title'] ?? 'Untitled').toString(),
      overview: (json['description'] ?? json['overview'] ?? '').toString(),
      posterPath: poster,
      backdropPath: background,
      mediaType: resolvedType,
      rating: ratingVal,
      releaseDate: cleanYear,
      genres: genresList,
      source: 'cinemeta',
      tmdbId: (tmdbId != null && tmdbId.isNotEmpty) ? tmdbId : null,
      imdbId: imdbId.isNotEmpty ? imdbId : null,
    );
  }

  factory MediaItem.fromTvMazeJson(
    Map<String, dynamic> json, {
    MediaType? explicitType,
  }) {
    final show = json.containsKey('show') && json['show'] is Map<String, dynamic>
        ? json['show'] as Map<String, dynamic>
        : json;

    final externals = show['externals'] as Map<String, dynamic>?;
    final imdbId = externals?['imdb']?.toString();
    final imageMap = show['image'] as Map<String, dynamic>?;
    final poster = imageMap?['original']?.toString() ?? imageMap?['medium']?.toString();
    final genresList = (show['genres'] as List?)
            ?.map((g) => g.toString())
            .toList() ??
        [];
    final language = (show['language'] ?? '').toString();
    if (language.isNotEmpty && !genresList.contains(language)) {
      genresList.insert(0, language);
    }

    final rawSummary = (show['summary'] ?? '').toString();
    final cleanSummary = rawSummary
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();

    final ratingMap = show['rating'] as Map<String, dynamic>?;
    final ratingVal = (ratingMap?['average'] as num?)?.toDouble() ?? 0.0;

    return MediaItem(
      id: show['id'].toString(),
      title: (show['name'] ?? 'Drama').toString(),
      overview: cleanSummary,
      posterPath: poster,
      backdropPath: poster,
      mediaType: explicitType ?? MediaType.drama,
      rating: ratingVal,
      releaseDate: show['premiered']?.toString(),
      genres: genresList,
      source: 'tvmaze',
      imdbId: (imdbId != null && imdbId.isNotEmpty) ? imdbId : null,
    );
  }

  factory MediaItem.fromAnilistJson(Map<String, dynamic> json) {
    final titleMap = json['title'] as Map<String, dynamic>?;
    final title = titleMap?['english'] ??
        titleMap?['romaji'] ??
        titleMap?['native'] ??
        'Anime';

    final coverImage = json['coverImage'] as Map<String, dynamic>?;
    final poster = coverImage?['extraLarge'] ?? coverImage?['large'];
    final banner = json['bannerImage'];

    final genresList = (json['genres'] as List?)
            ?.map((g) => g.toString())
            .toList() ??
        [];

    final startYear = json['startDate']?['year']?.toString();
    final format = (json['format'] ?? '').toString().toUpperCase();
    final nextAiringEp = json['nextAiringEpisode']?['episode'] as int?;
    final totalEps = (json['episodes'] as int?) ??
        (nextAiringEp != null && nextAiringEp > 1 ? nextAiringEp - 1 : null) ??
        (format == 'MOVIE' ? 1 : 12);

    return MediaItem(
      id: json['id'].toString(),
      title: title,
      overview: (json['description'] ?? '')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'\(Source:[^)]*\)', caseSensitive: false), '')
          .trim(),
      posterPath: poster,
      backdropPath: banner ?? poster,
      mediaType: MediaType.anime,
      rating: ((json['averageScore'] as num?)?.toDouble() ?? 0.0) / 10.0,
      releaseDate: startYear,
      genres: genresList,
      numberOfEpisodes: totalEps,
      source: 'anilist',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'overview': overview,
        'posterPath': posterPath,
        'backdropPath': backdropPath,
        'mediaType': mediaType.name,
        'rating': rating,
        'releaseDate': releaseDate,
        'genres': genres,
        'numberOfSeasons': numberOfSeasons,
        'numberOfEpisodes': numberOfEpisodes,
        'source': source,
        'tmdbId': tmdbId,
        'imdbId': imdbId,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'].toString(),
        title: json['title'] ?? '',
        overview: json['overview'] ?? '',
        posterPath: json['posterPath'],
        backdropPath: json['backdropPath'],
        mediaType: MediaType.values.firstWhere(
          (e) => e.name == json['mediaType'],
          orElse: () => MediaType.movie,
        ),
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        releaseDate: json['releaseDate'],
        genres: List<String>.from(json['genres'] ?? []),
        numberOfSeasons: json['numberOfSeasons'],
        numberOfEpisodes: json['numberOfEpisodes'],
        source: json['source'] ?? 'tmdb',
        tmdbId: json['tmdbId'],
        imdbId: json['imdbId'],
      );
}
