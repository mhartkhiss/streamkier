import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/media_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/media_provider.dart';
import '../theme.dart';
import '../widgets/media_card.dart';
import '../widgets/media_row.dart';
import 'details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _heroPageController = PageController();
  int _currentHeroIndex = 0;

  @override
  void dispose() {
    _heroPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaProvider>();
    final library = context.watch<LibraryProvider>();

    if (media.isLoading && media.trending.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (media.errorMessage != null && media.trending.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(media.errorMessage!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => media.fetchHomeContent(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final featuredList = (media.filteredTrending.isNotEmpty
            ? media.filteredTrending
            : media.trending)
        .take(5)
        .toList();

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: () => media.fetchHomeContent(),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Featured Carousel ────────────────────────────────
            if (featuredList.isNotEmpty)
              _buildFeaturedCarousel(context, featuredList, library),

            // ── Category Filters ──────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  _buildCategoryChip(
                    context,
                    'All',
                    'all',
                    Icons.grid_view_rounded,
                    media.selectedCategory,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    context,
                    'Dramas',
                    'drama',
                    Icons.theater_comedy_rounded,
                    media.selectedCategory,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    context,
                    'Movies',
                    'movie',
                    Icons.local_movies_rounded,
                    media.selectedCategory,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    context,
                    'TV Shows',
                    'tv',
                    Icons.tv_rounded,
                    media.selectedCategory,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    context,
                    'Anime',
                    'anime',
                    Icons.auto_awesome_rounded,
                    media.selectedCategory,
                  ),
                ],
              ),
            ),

            // ── Continue Watching (History) ───────────────────────────
            if (library.history.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.history_rounded, color: AppTheme.secondary, size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Continue Watching',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 245,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: library.history.length,
                  itemBuilder: (context, index) {
                    final entry = library.history[index];
                    final item = MediaItem.fromJson(entry['item']);
                    final s = entry['season'] ?? 1;
                    final e = entry['episode'] ?? 1;
                    final badge = item.mediaType == MediaType.movie ? null : 'S$s • E$e';
                    return MediaCard(item: item, badgeText: badge);
                  },
                ),
              ),
            ],

            // ── Trending Section ──────────────────────────────────────
            MediaRow(
              title: 'Trending Today',
              items: media.filteredTrending,
              icon: Icons.trending_up_rounded,
              iconColor: AppTheme.primary,
            ),

            // ── Asian & K-Dramas ──────────────────────────────────────
            if (media.selectedCategory == 'all' || media.selectedCategory == 'drama')
              MediaRow(
                title: 'Asian & K-Dramas',
                items: media.asianDramas,
                icon: Icons.theater_comedy_rounded,
                iconColor: AppTheme.dramaColor,
              ),

            // ── AI & Sci-Fi Dramas ────────────────────────────────────
            if (media.selectedCategory == 'all' || media.selectedCategory == 'drama')
              MediaRow(
                title: 'AI & Sci-Fi Dramas',
                items: media.aiDramas,
                icon: Icons.smart_toy_rounded,
                iconColor: AppTheme.secondary,
              ),

            // ── Trending Dramas ───────────────────────────────────────
            if (media.selectedCategory == 'all' || media.selectedCategory == 'drama')
              MediaRow(
                title: 'Popular Drama Series',
                items: media.topDramas,
                icon: Icons.live_tv_rounded,
                iconColor: AppTheme.dramaColor,
              ),

            // ── Popular Movies ────────────────────────────────────────
            if (media.selectedCategory == 'all' || media.selectedCategory == 'movie')
              MediaRow(
                title: 'Popular Movies',
                items: media.popularMovies,
                icon: Icons.local_movies_rounded,
                iconColor: AppTheme.primary,
              ),

            // ── Popular TV Series ─────────────────────────────────────
            if (media.selectedCategory == 'all' || media.selectedCategory == 'tv')
              MediaRow(
                title: 'Popular TV Shows',
                items: media.popularTv,
                icon: Icons.tv_rounded,
                iconColor: AppTheme.secondary,
              ),

            // ── Top Anime ─────────────────────────────────────────────
            if (media.selectedCategory == 'all' || media.selectedCategory == 'anime') ...[
              MediaRow(
                title: 'Trending Anime',
                items: media.topAnime,
                icon: Icons.auto_awesome_rounded,
                iconColor: AppTheme.animeColor,
              ),
              MediaRow(
                title: 'All-Time Popular Anime',
                items: media.popularAnime,
                icon: Icons.whatshot_rounded,
                iconColor: AppTheme.animeColor,
              ),
              MediaRow(
                title: 'Top Rated Anime',
                items: media.topRatedAnime,
                icon: Icons.workspace_premium_rounded,
                iconColor: AppTheme.animeColor,
              ),
            ],

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCarousel(
    BuildContext context,
    List<MediaItem> items,
    LibraryProvider library,
  ) {
    final safeIndex = _currentHeroIndex < items.length ? _currentHeroIndex : 0;

    return Column(
      children: [
        SizedBox(
          height: 390,
          child: PageView.builder(
            controller: _heroPageController,
            itemCount: items.length,
            onPageChanged: (idx) => setState(() => _currentHeroIndex = idx),
            itemBuilder: (context, index) {
              return _buildFeaturedHeroItem(context, items[index], library);
            },
          ),
        ),
        if (items.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final isActive = i == safeIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primary : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildFeaturedHeroItem(
    BuildContext context,
    MediaItem item,
    LibraryProvider library,
  ) {
    final isSaved = library.isInWatchlist(item);
    final badgeColor = AppTheme.colorForMediaType(item.mediaType.name);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailsScreen(item: item)),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: AppTheme.surface,
            child: item.backdropUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.backdropUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 960,
                    fadeInDuration: const Duration(milliseconds: 150),
                    errorWidget: (_, _, _) => const SizedBox(),
                  )
                : null,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.background.withValues(alpha: 0.25),
                  Colors.transparent,
                  AppTheme.background.withValues(alpha: 0.82),
                  AppTheme.background,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.25, 0.72, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        item.mediaType.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (item.rating > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: AppTheme.accent, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              item.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (item.year.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        item.year,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                if (item.genres.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.genres.take(3).join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  item.overview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Watch Now'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DetailsScreen(item: item)),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: Icon(
                        isSaved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                        size: 18,
                        color: isSaved ? AppTheme.primary : Colors.white,
                      ),
                      label: Text(isSaved ? 'Saved' : 'Watchlist'),
                      onPressed: () => library.toggleWatchlist(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String label,
    String categoryKey,
    IconData icon,
    String activeCategory,
  ) {
    final isSelected = activeCategory == categoryKey;
    final activeColor = categoryKey == 'all'
        ? AppTheme.primary
        : AppTheme.colorForMediaType(categoryKey);

    return GestureDetector(
      onTap: () {
        setState(() => _currentHeroIndex = 0);
        if (_heroPageController.hasClients) {
          _heroPageController.jumpToPage(0);
        }
        context.read<MediaProvider>().setCategory(categoryKey);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.07),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
