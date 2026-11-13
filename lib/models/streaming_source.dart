import 'media_item.dart';

enum SourceType { embed, direct }

class StreamingSource {
  final String id;
  final String name;
  final String description;
  final SourceType type;
  final bool isAnimeOnly;

  const StreamingSource({
    required this.id,
    required this.name,
    required this.description,
    this.type = SourceType.embed,
    this.isAnimeOnly = false,
  });

  String getUrl({
    required String tmdbId,
    required MediaType mediaType,
    int season = 1,
    int episode = 1,
  }) {
    switch (id) {
      case 'vidlink':
        if (mediaType == MediaType.movie) {
          return 'https://vidlink.pro/movie/$tmdbId?autoplay=true&primaryColor=E50914';
        }
        return 'https://vidlink.pro/tv/$tmdbId/$season/$episode?autoplay=true&primaryColor=E50914';

      case 'vidsrc':
        // Direct vidsrc.sh endpoint bypasses the slow vidsrc.to ad-script wrapper
        if (mediaType == MediaType.movie) {
          return 'https://vidsrc.sh/embed/movie/$tmdbId/';
        }
        return 'https://vidsrc.sh/embed/tv/$tmdbId/$season/$episode/';

      case 'autoembed':
      case 'videasy':
        if (mediaType == MediaType.movie) {
          return 'https://autoembed.co/movie/tmdb/$tmdbId';
        }
        return 'https://autoembed.co/tv/tmdb/$tmdbId-$season-$episode';

      case 'multiembed':
      case 'vidking':
        if (mediaType == MediaType.movie) {
          return 'https://multiembed.mov/?video_id=$tmdbId&tmdb=1';
        }
        return 'https://multiembed.mov/?video_id=$tmdbId&tmdb=1&s=$season&e=$episode';

      case '2embed':
      case 'allmanga':
        if (mediaType == MediaType.movie) {
          return 'https://www.2embed.cc/embed/$tmdbId';
        }
        return 'https://www.2embed.cc/embedtv/$tmdbId&s=$season&e=$episode';

      default:
        if (mediaType == MediaType.movie) {
          return 'https://vidlink.pro/movie/$tmdbId?autoplay=true&primaryColor=E50914';
        }
        return 'https://vidlink.pro/tv/$tmdbId/$season/$episode?autoplay=true&primaryColor=E50914';
    }
  }

  static const List<StreamingSource> allSources = [
    StreamingSource(
      id: 'vidlink',
      name: 'VidLink Pro (Fastest)',
      description: 'Ultra-fast HD streams with instant autoplay (Verified)',
    ),
    StreamingSource(
      id: 'autoembed',
      name: 'AutoEmbed (Reliable HD)',
      description: 'Verified fast HLS multi-server for Movies, TV & Dramas',
    ),
    StreamingSource(
      id: '2embed',
      name: '2Embed (Drama & Series)',
      description: 'Great coverage for K-Dramas, Asian dramas & series',
    ),
    StreamingSource(
      id: 'vidsrc',
      name: 'VidSrc (Backup)',
      description: 'Backup embed player with subtitle support',
    ),
  ];
}
