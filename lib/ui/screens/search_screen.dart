import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/media_item.dart';
import '../../providers/media_provider.dart';
import '../theme.dart';
import '../widgets/media_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _selectedFilter = 'all';

  static const List<String> _quickTags = [
    'Squid Game',
    'My Holo Love',
    'Are You Human',
    'Queen of Tears',
    'Crash Landing on You',
    'Lovely Runner',
    'Alchemy of Souls',
    'Black Mirror',
    'Solo Leveling',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      context.read<MediaProvider>().clearSearch();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<MediaProvider>().search(query);
      }
    });
  }

  void _selectQuickTag(String tag) {
    _controller.text = tag;
    setState(() {});
    context.read<MediaProvider>().search(tag);
  }

  List<MediaItem> _filterResults(List<MediaItem> list) {
    if (_selectedFilter == 'all') return list;
    return list.where((item) => item.mediaType.name == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaProvider>();
    final hasQuery = _controller.text.trim().isNotEmpty;
    final filteredResults = _filterResults(media.searchResults);
    final discoveryItems = [
      ...media.asianDramas.take(6),
      ...media.trending.take(6),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Explore & Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Search movies, dramas, series, or anime…',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                          context.read<MediaProvider>().clearSearch();
                        },
                      )
                    : null,
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 12),

            if (hasQuery) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Dramas', 'drama'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Movies', 'movie'),
                    const SizedBox(width: 8),
                    _buildFilterChip('TV Shows', 'tv'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Anime', 'anime'),
                  ],
                ),
              ),
            ],

            // Search Results or Discovery View
            Expanded(
              child: media.isSearching
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : !hasQuery
                      ? _buildDiscoveryView(discoveryItems)
                      : filteredResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 56,
                                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No matches found for "${_controller.text}"',
                                    style: const TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : _buildMediaGrid(filteredResults),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryView(List<MediaItem> discoveryItems) {
    return ListView(
      children: [
        const Text(
          'POPULAR SEARCHES',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickTags.map((tag) {
            return ActionChip(
              backgroundColor: AppTheme.surfaceLight,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              avatar: const Icon(Icons.trending_up_rounded, size: 14, color: AppTheme.primary),
              label: Text(
                tag,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              onPressed: () => _selectQuickTag(tag),
            );
          }).toList(),
        ),
        if (discoveryItems.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text(
            'RECOMMENDED FOR YOU',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.54,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: discoveryItems.length,
            itemBuilder: (context, index) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return MediaCard(
                    item: discoveryItems[index],
                    width: constraints.maxWidth,
                    height: constraints.maxHeight - 44,
                    margin: EdgeInsets.zero,
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMediaGrid(List<MediaItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
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

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    final activeColor = key == 'all' ? AppTheme.primary : AppTheme.colorForMediaType(key);
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
