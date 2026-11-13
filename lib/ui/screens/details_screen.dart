import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/episode.dart';
import '../../models/media_item.dart';
import '../../models/streaming_source.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/anilist_service.dart';
import '../../services/drama_service.dart';
import '../../services/tmdb_service.dart';
import '../theme.dart';
import '../widgets/media_row.dart';
import 'player_screen.dart';

class DetailsScreen extends StatefulWidget {
  final MediaItem item;

  const DetailsScreen({super.key, required this.item});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late MediaItem _item;
  List<Episode> _episodes = [];
  Map<int, List<Episode>> _cachedSeasons = {};
  List<MediaItem> _similar = [];
  int _selectedSeason = 1;
  int _totalSeasons = 1;
  bool _isLoadingDetails = false;
  bool _isLoadingEpisodes = false;
  bool _isSynopsisExpanded = false;
  late StreamingSource _selectedSource;

  @override
  void initState() {
    super.initState();
    _item = widget.item;

    final defaultSourceId = context.read<SettingsProvider>().defaultSource;
    _selectedSource = StreamingSource.allSources.firstWhere(
      (s) => s.id == defaultSourceId,
      orElse: () => StreamingSource.allSources.first,
    );

    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoadingDetails = true);
    final tmdb = context.read<TmdbService>();
    final dramaService = context.read<DramaService>();

    try {
      if (_item.mediaType == MediaType.anime) {
        final totalEps = _item.numberOfEpisodes ?? 12;
        setState(() {
          _episodes = List.generate(
            totalEps,
            (i) => Episode.forAnime(i + 1),
          );
        });

        final anilist = context.read<AnilistService>();
        final mapping = await anilist.resolveAnimeMapping(_item.id);
        final mappedSeason = mapping?.season ?? 1;

        if (mounted && mapping != null) {
          setState(() {
            _item = _item.copyWith(
              tmdbId: mapping.tmdbId ?? _item.tmdbId,
              imdbId: mapping.imdbId ?? _item.imdbId,
            );
            _selectedSeason = mappedSeason;
            _episodes = List.generate(
              totalEps,
              (i) => Episode.forAnime(i + 1, seasonNum: mappedSeason),
            );
          });
        }

        // Also enrich with Cinemeta multi-season episodes when available
        if (_item.imdbId != null || _item.effectiveTmdbId.isEmpty) {
          final resolved = await dramaService.getDetailsAndSeasons(_item);
          if (mounted && resolved != null && resolved.seasons.isNotEmpty) {
            final seasons = resolved.seasons;
            final targetEps = seasons[mappedSeason] ??
                seasons[1] ??
                seasons.values.first;
            // Use Cinemeta seasons unless AniList has a much larger continuous episode count (e.g. One Piece)
            if (seasons.length > 1 || targetEps.length >= totalEps) {
              setState(() {
                _item = _item.copyWith(
                  tmdbId: resolved.details.tmdbId ?? _item.tmdbId,
                  imdbId: resolved.details.imdbId ?? _item.imdbId,
                  numberOfSeasons: seasons.keys.length,
                );
                _cachedSeasons = seasons;
                _totalSeasons = seasons.keys.reduce((a, b) => a > b ? a : b);
                _selectedSeason = seasons.containsKey(mappedSeason) ? mappedSeason : 1;
                _episodes = targetEps;
              });
            }
          }
        }
        return;
      }

      if (_item.mediaType == MediaType.drama || _item.source != 'tmdb') {
        final resolved = await dramaService.getDetailsAndSeasons(_item);
        if (mounted && resolved != null) {
          final seasons = resolved.seasons;
          final firstSeasonEps = seasons[1] ??
              (seasons.isNotEmpty ? seasons.values.first : <Episode>[]);
          setState(() {
            _item = resolved.details;
            _cachedSeasons = seasons;
            _totalSeasons = seasons.isNotEmpty
                ? seasons.keys.reduce((a, b) => a > b ? a : b)
                : (_item.numberOfSeasons ?? 1);
            _episodes = firstSeasonEps.isNotEmpty
                ? firstSeasonEps
                : (_item.mediaType == MediaType.movie
                    ? []
                    : List.generate(
                        _item.numberOfEpisodes ?? 16,
                        (i) => Episode.forAnime(i + 1),
                      ));
          });
          return;
        }
      }

      if (_item.mediaType == MediaType.movie) {
        final details = await tmdb.getMovieDetails(_item.effectiveTmdbId);
        final similar = await tmdb.getSimilar(MediaType.movie, _item.effectiveTmdbId);
        if (mounted) {
          setState(() {
            _item = details;
            _similar = similar;
          });
        }
      } else {
        final details = await tmdb.getTvDetails(_item.effectiveTmdbId);
        final similar = await tmdb.getSimilar(MediaType.tv, _item.effectiveTmdbId);
        if (mounted) {
          setState(() {
            _item = details.copyWith(mediaType: _item.mediaType);
            _similar = similar;
            _totalSeasons = details.numberOfSeasons ?? 1;
          });
          _loadSeasonEpisodes(1);
        }
      }
    } catch (_) {
      // Fallback to DramaService/Cinemeta when TMDB fails
      try {
        final resolved = await dramaService.getDetailsAndSeasons(_item);
        if (mounted && resolved != null) {
          final seasons = resolved.seasons;
          final firstSeasonEps = seasons[1] ??
              (seasons.isNotEmpty ? seasons.values.first : <Episode>[]);
          setState(() {
            _item = resolved.details;
            _cachedSeasons = seasons;
            _totalSeasons = seasons.isNotEmpty
                ? seasons.keys.reduce((a, b) => a > b ? a : b)
                : (_item.numberOfSeasons ?? 1);
            if (_item.mediaType != MediaType.movie) {
              _episodes = firstSeasonEps.isNotEmpty
                  ? firstSeasonEps
                  : List.generate(
                      _item.numberOfEpisodes ?? 16,
                      (i) => Episode.forAnime(i + 1),
                    );
            }
          });
        }
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _loadSeasonEpisodes(int seasonNum) async {
    if (_cachedSeasons.containsKey(seasonNum) && _cachedSeasons[seasonNum]!.isNotEmpty) {
      setState(() {
        _selectedSeason = seasonNum;
        _episodes = _cachedSeasons[seasonNum]!;
      });
      return;
    }

    setState(() {
      _selectedSeason = seasonNum;
      _isLoadingEpisodes = true;
    });

    final tmdb = context.read<TmdbService>();
    try {
      final eps = await tmdb.getSeasonEpisodes(_item.effectiveTmdbId, seasonNum);
      if (mounted) setState(() => _episodes = eps);
    } catch (_) {
      if (mounted) {
        setState(() {
          _episodes = _cachedSeasons[seasonNum] ??
              List.generate(16, (i) => Episode.forAnime(i + 1));
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingEpisodes = false);
    }
  }

  void _playMedia({Episode? episode}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          item: _item,
          episode: episode,
          source: _selectedSource,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final isWatchlist = library.isInWatchlist(_item);
    final badgeColor = AppTheme.colorForMediaType(_item.mediaType.name);

    final historyEntry = library.history.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e != null && e['id'].toString() == _item.id,
          orElse: () => null,
        );
    final savedSeason = historyEntry?['season'] as int?;
    final savedEpisode = historyEntry?['episode'] as int?;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Collapsible Backdrop App Bar with Poster Overlay
          SliverAppBar(
            expandedHeight: 310,
            pinned: true,
            backgroundColor: AppTheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_item.backdropUrl != null)
                    CachedNetworkImage(
                      imageUrl: _item.backdropUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 960,
                      errorWidget: (_, _, _) => Container(color: AppTheme.surface),
                    )
                  else
                    Container(color: AppTheme.surface),
                  // Dark Vignette Gradient
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.background.withValues(alpha: 0.25),
                          Colors.transparent,
                          AppTheme.background.withValues(alpha: 0.88),
                          AppTheme.background,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.3, 0.78, 1.0],
                      ),
                    ),
                  ),
                  // Poster + Quick Info Overlay at bottom of hero
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_item.posterUrl != null)
                          Container(
                            width: 92,
                            height: 136,
                            margin: const EdgeInsets.only(right: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: CachedNetworkImage(
                                imageUrl: _item.posterUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 260,
                                errorWidget: (_, _, _) => Container(color: AppTheme.surfaceLight),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  _item.mediaType.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (_item.year.isNotEmpty)
                                    Text(
                                      _item.year,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (_item.rating > 0)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, color: AppTheme.accent, size: 15),
                                        const SizedBox(width: 3),
                                        Text(
                                          _item.rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (_totalSeasons > 1 || _item.numberOfSeasons != null)
                                    Text(
                                      '${_totalSeasons > 1 ? _totalSeasons : _item.numberOfSeasons} Season${(_totalSeasons > 1 ? _totalSeasons : (_item.numberOfSeasons ?? 1)) > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: isWatchlist ? 'Remove from Watchlist' : 'Add to Watchlist',
                icon: Icon(
                  isWatchlist ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isWatchlist ? AppTheme.primary : Colors.white,
                ),
                onPressed: () => library.toggleWatchlist(_item),
              ),
            ],
          ),

          // Metadata & Controls Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingDetails)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10.0),
                      child: LinearProgressIndicator(color: AppTheme.primary, minHeight: 2),
                    ),
                  const SizedBox(height: 8),

                  // Genres
                  if (_item.genres.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _item.genres.map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            border: Border.all(color: Colors.white12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            g,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Watch Buttons & Source Selector
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: Text(
                            _item.mediaType == MediaType.movie
                                ? 'Watch Movie'
                                : (savedSeason != null && savedEpisode != null)
                                    ? 'Resume S$savedSeason E$savedEpisode'
                                    : 'Play S$_selectedSeason E1',
                          ),
                          onPressed: () {
                            if (_item.mediaType != MediaType.movie &&
                                savedSeason != null &&
                                savedEpisode != null) {
                              final matchEp = _episodes.cast<Episode?>().firstWhere(
                                    (e) =>
                                        e?.seasonNumber == savedSeason &&
                                        e?.episodeNumber == savedEpisode,
                                    orElse: () => Episode(
                                      id: savedEpisode,
                                      episodeNumber: savedEpisode,
                                      seasonNumber: savedSeason,
                                      name: 'Episode $savedEpisode',
                                      overview: '',
                                    ),
                                  );
                              _playMedia(episode: matchEp);
                            } else {
                              _playMedia(
                                episode: _episodes.isNotEmpty ? _episodes.first : null,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<StreamingSource>(
                        tooltip: 'Select Server',
                        initialValue: _selectedSource,
                        onSelected: (s) => setState(() => _selectedSource = s),
                        itemBuilder: (_) => StreamingSource.allSources
                            .where((s) => !s.isAnimeOnly || _item.mediaType == MediaType.anime)
                            .map((source) => PopupMenuItem(
                                  value: source,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        source.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                      ),
                                      Text(
                                        source.description,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.dns_rounded, size: 16, color: Colors.white70),
                              const SizedBox(width: 6),
                              Text(
                                _selectedSource.name.split(' ').first,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Overview / Expandable Synopsis
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setState(() => _isSynopsisExpanded = !_isSynopsisExpanded),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.overview.isNotEmpty ? _item.overview : 'No description available.',
                          maxLines: _isSynopsisExpanded ? 20 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (_item.overview.length > 140)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _isSynopsisExpanded ? 'Show less' : 'Read more',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // TV / Drama / Anime Episodes Section
                  if (_item.mediaType != MediaType.movie) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Episodes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_episodes.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_episodes.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (_totalSeasons > 1) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_totalSeasons, (i) {
                            final sNum = i + 1;
                            final isSelected = _selectedSeason == sNum;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _loadSeasonEpisodes(sNum),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.primary : Colors.white10,
                                    ),
                                  ),
                                  child: Text(
                                    'Season $sNum',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    if (_isLoadingEpisodes)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        ),
                      )
                    else if (_episodes.isEmpty)
                      const Text(
                        'No episodes found for this season.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                  ],
                ],
              ),
            ),
          ),

          // Lazy Virtualized Episode List (prevents lag on 100-1,100+ episode shows)
          if (_item.mediaType != MediaType.movie && !_isLoadingEpisodes && _episodes.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList.builder(
                itemCount: _episodes.length,
                itemBuilder: (context, index) {
                  final ep = _episodes[index];
                  final isLastWatched =
                      savedSeason == ep.seasonNumber && savedEpisode == ep.episodeNumber;
                  return RepaintBoundary(
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isLastWatched
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : AppTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isLastWatched
                              ? AppTheme.primary.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: ListTile(
                        onTap: () => _playMedia(episode: ep),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        leading: ep.stillUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: ep.stillUrl!,
                                  width: 88,
                                  height: 54,
                                  memCacheWidth: 240,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Container(
                                    width: 88,
                                    height: 54,
                                    color: AppTheme.surfaceLight,
                                    child: const Icon(Icons.play_circle_outline, size: 22),
                                  ),
                                ),
                              )
                            : Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'E${ep.episodeNumber}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${ep.episodeNumber}. ${ep.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (isLastWatched)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LAST PLAYED',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        subtitle: ep.overview.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  ep.overview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              )
                            : null,
                        trailing: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: AppTheme.primary,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Similar Media Footer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_similar.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    MediaRow(title: 'You May Also Like', items: _similar),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
