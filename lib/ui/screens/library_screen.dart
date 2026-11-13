import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/media_item.dart';
import '../../providers/library_provider.dart';
import '../theme.dart';
import '../widgets/media_card.dart';
import 'details_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('My Library'),
          bottom: const TabBar(
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(icon: Icon(Icons.bookmark), text: 'Watchlist'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _WatchlistView(),
            _HistoryView(),
          ],
        ),
      ),
    );
  }
}

class _WatchlistView extends StatelessWidget {
  const _WatchlistView();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final items = library.watchlist;

    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text(
              'Your Watchlist is empty',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Save shows & movies to watch later',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.54,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return MediaCard(
              item: items[index],
              width: constraints.maxWidth,
              height: constraints.maxHeight - 44,
              margin: EdgeInsets.zero,
            );
          },
        );
      },
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final history = library.history;

    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text(
              'No watch history yet',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Start playing content to track your progress',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[index];
        final item = MediaItem.fromJson(entry['item']);
        final season = entry['season'] ?? 1;
        final episode = entry['episode'] ?? 1;
        final badgeColor = AppTheme.colorForMediaType(item.mediaType.name);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailsScreen(item: item)),
              );
            },
            leading: item.posterUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: item.posterUrl!,
                      width: 46,
                      height: 68,
                      memCacheWidth: 140,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const Icon(Icons.movie_outlined),
                    ),
                  )
                : const Icon(Icons.movie_outlined),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.mediaType.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.mediaType == MediaType.movie
                        ? 'Movie'
                        : 'Season $season • Episode $episode',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            trailing: const Icon(
              Icons.play_circle_fill_rounded,
              color: AppTheme.primary,
              size: 30,
            ),
          ),
        );
      },
    );
  }
}
