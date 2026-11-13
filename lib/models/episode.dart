class Episode {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String overview;
  final String? stillPath;
  final String? airDate;

  const Episode({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    required this.overview,
    this.stillPath,
    this.airDate,
  });

  String? get stillUrl {
    if (stillPath == null || stillPath!.isEmpty) return null;
    if (stillPath!.startsWith('http')) return stillPath;
    return 'https://image.tmdb.org/t/p/w500$stillPath';
  }

  factory Episode.fromTmdbJson(Map<String, dynamic> json, int seasonNum) {
    return Episode(
      id: json['id'] ?? 0,
      episodeNumber: json['episode_number'] ?? 1,
      seasonNumber: seasonNum,
      name: json['name'] ?? 'Episode ${json['episode_number'] ?? 1}',
      overview: json['overview'] ?? '',
      stillPath: json['still_path'],
      airDate: json['air_date'],
    );
  }

  factory Episode.forAnime(int epNum, {int seasonNum = 1, String? name}) {
    return Episode(
      id: seasonNum * 10000 + epNum,
      episodeNumber: epNum,
      seasonNumber: seasonNum,
      name: name ?? 'Episode $epNum',
      overview: '',
      stillPath: null,
      airDate: null,
    );
  }

  factory Episode.fromCinemetaJson(Map<String, dynamic> json) {
    final epNum = (json['number'] ?? json['episode'] ?? 1) as int;
    final sNum = (json['season'] ?? 1) as int;
    final rawDate = (json['firstAired'] ?? json['released'] ?? '').toString();
    final cleanDate = rawDate.isNotEmpty ? rawDate.split('T').first : null;
    return Episode(
      id: (json['tvdb_id'] as int?) ?? (sNum * 1000 + epNum),
      episodeNumber: epNum,
      seasonNumber: sNum,
      name: (json['name'] ?? json['title'] ?? 'Episode $epNum').toString(),
      overview: (json['overview'] ?? json['description'] ?? '').toString(),
      stillPath: json['thumbnail']?.toString(),
      airDate: cleanDate,
    );
  }

  factory Episode.fromTvMazeJson(Map<String, dynamic> json) {
    final epNum = (json['number'] as int?) ?? 1;
    final sNum = (json['season'] as int?) ?? 1;
    final imageMap = json['image'] as Map<String, dynamic>?;
    final still = imageMap?['medium']?.toString() ?? imageMap?['original']?.toString();
    final rawSummary = (json['summary'] ?? '').toString();
    final cleanSummary = rawSummary.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return Episode(
      id: (json['id'] as int?) ?? (sNum * 1000 + epNum),
      episodeNumber: epNum,
      seasonNumber: sNum,
      name: (json['name'] ?? 'Episode $epNum').toString(),
      overview: cleanSummary,
      stillPath: still,
      airDate: json['airdate']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'episodeNumber': episodeNumber,
        'seasonNumber': seasonNumber,
        'name': name,
        'overview': overview,
        'stillPath': stillPath,
        'airDate': airDate,
      };

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        id: json['id'] ?? 0,
        episodeNumber: json['episodeNumber'] ?? 1,
        seasonNumber: json['seasonNumber'] ?? 1,
        name: json['name'] ?? '',
        overview: json['overview'] ?? '',
        stillPath: json['stillPath'],
        airDate: json['airDate'],
      );
}
