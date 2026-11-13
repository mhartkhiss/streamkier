import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/media_item.dart';
import '../screens/details_screen.dart';
import '../theme.dart';

class MediaCard extends StatelessWidget {
  final MediaItem item;
  final double width;
  final double height;
  final String? badgeText;
  final EdgeInsetsGeometry? margin;

  const MediaCard({
    super.key,
    required this.item,
    this.width = 132,
    this.height = 195,
    this.badgeText,
    this.margin,
  });

  String _getTypeLabel() {
    switch (item.mediaType) {
      case MediaType.movie:
        return 'MOVIE';
      case MediaType.tv:
        return 'SERIES';
      case MediaType.drama:
        return 'DRAMA';
      case MediaType.anime:
        return 'ANIME';
    }
  }

  Color _getTypeColor() {
    switch (item.mediaType) {
      case MediaType.movie:
        return AppTheme.primary;
      case MediaType.tv:
        return AppTheme.secondary;
      case MediaType.drama:
        return AppTheme.dramaColor;
      case MediaType.anime:
        return AppTheme.animeColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailsScreen(item: item),
            ),
          );
        },
        child: Container(
          width: width,
          margin: margin ?? const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          item.posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: item.posterUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 340,
                                  fadeInDuration: const Duration(milliseconds: 120),
                                  placeholder: (_, _) => const ColoredBox(
                                    color: AppTheme.surfaceLight,
                                  ),
                                  errorWidget: (_, _, _) => const Center(
                                    child: Icon(Icons.movie_outlined, color: AppTheme.textSecondary),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.movie_outlined, color: AppTheme.textSecondary),
                                ),
                        // Bottom vignette gradient
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 48,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.75),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 7,
                  left: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: _getTypeColor().withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _getTypeLabel(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (badgeText != null && badgeText!.isNotEmpty)
                  Positioned(
                    bottom: 7,
                    left: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (item.rating > 0)
                  Positioned(
                    bottom: 7,
                    right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white12, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: AppTheme.accent, size: 11),
                          const SizedBox(width: 2.5),
                          Text(
                            item.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (item.year.isNotEmpty)
              Text(
                item.year,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}
