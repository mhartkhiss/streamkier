import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streambert_flutter/main.dart';
import 'package:streambert_flutter/models/media_item.dart';
import 'package:streambert_flutter/models/streaming_source.dart';
import 'package:streambert_flutter/providers/library_provider.dart';
import 'package:streambert_flutter/providers/media_provider.dart';
import 'package:streambert_flutter/providers/settings_provider.dart';
import 'package:streambert_flutter/services/ad_blocker_service.dart';
import 'package:streambert_flutter/services/anilist_service.dart';
import 'package:streambert_flutter/services/drama_service.dart';
import 'package:streambert_flutter/services/storage_service.dart';
import 'package:streambert_flutter/services/tmdb_service.dart';

void main() {
  setUpAll(() {
    // Allow live HTTP requests in tests to verify real APIs without keys
    HttpOverrides.global = null;
  });

  group('Key-Free DramaService & MediaProvider Live Tests', () {
    late DramaService dramaService;

    setUp(() {
      dramaService = DramaService();
    });

    test('1. getAsianDramas returns K-Dramas, C-Dramas, and J-Dramas without API key', () async {
      final dramas = await dramaService.getAsianDramas();
      expect(dramas, isNotEmpty);
      expect(dramas.every((d) => d.mediaType == MediaType.drama), isTrue);

      final first = dramas.first;
      // ignore: avoid_print
      print('Loaded ${dramas.length} Asian dramas. First: ${first.title} (TMDB: ${first.effectiveTmdbId}, IMDb: ${first.imdbId})');
      expect(first.effectiveTmdbId, isNotEmpty);
      expect(first.posterUrl, isNotNull);
    });

    test('2. getTrendingDramas fetches live dramas from Cinemeta without API key', () async {
      final trendingDramas = await dramaService.getTrendingDramas();
      expect(trendingDramas, isNotEmpty);
      // ignore: avoid_print
      print('Loaded ${trendingDramas.length} trending dramas. Sample: ${trendingDramas.take(3).map((d) => "${d.title} (${d.effectiveTmdbId})").join(", ")}');
      expect(trendingDramas.first.mediaType, equals(MediaType.drama));
      expect(trendingDramas.first.effectiveTmdbId, isNotEmpty);
    });

    test('3. getDetailsAndSeasons resolves episodes and TMDB ID for a K-Drama without API key', () async {
      final dramas = await dramaService.getAsianDramas();
      final cloy = dramas.firstWhere((d) => d.title.contains('Crash Landing on You'));

      final resolved = await dramaService.getDetailsAndSeasons(cloy);
      expect(resolved, isNotNull);
      expect(resolved!.details.effectiveTmdbId, equals('94796'));
      expect(resolved.seasons, isNotEmpty);
      expect(resolved.seasons[1], isNotNull);
      expect(resolved.seasons[1]!.length, greaterThanOrEqualTo(10));

      final ep1 = resolved.seasons[1]!.first;
      // ignore: avoid_print
      print('Resolved "${resolved.details.title}" -> TMDB ID: ${resolved.details.effectiveTmdbId}, Seasons: ${resolved.seasons.length}, S1 Episodes: ${resolved.seasons[1]!.length} (E1: "${ep1.name}")');

      // Verify streaming URLs generated for S1E1
      final vidsrc = StreamingSource.allSources.firstWhere((s) => s.id == 'vidsrc');
      final twoEmbed = StreamingSource.allSources.firstWhere((s) => s.id == '2embed');

      final vidsrcUrl = vidsrc.getUrl(
        tmdbId: resolved.details.effectiveTmdbId,
        mediaType: resolved.details.mediaType,
        season: 1,
        episode: 1,
      );
      final twoEmbedUrl = twoEmbed.getUrl(
        tmdbId: resolved.details.effectiveTmdbId,
        mediaType: resolved.details.mediaType,
        season: 1,
        episode: 1,
      );

      // ignore: avoid_print
      print('VidSrc Stream URL: $vidsrcUrl');
      // ignore: avoid_print
      print('2Embed Stream URL: $twoEmbedUrl');

      expect(vidsrcUrl, equals('https://vidsrc.to/embed/tv/94796/1/1'));
      expect(twoEmbedUrl, equals('https://www.2embed.cc/embedtv/94796&s=1&e=1'));
    });

    test('4. Search finds dramas across TVMaze and Cinemeta without API key', () async {
      final results = await dramaService.search('Queen of Tears');
      expect(results, isNotEmpty);
      // ignore: avoid_print
      print('Search "Queen of Tears" returned ${results.length} results. Top match: ${results.first.title} (${results.first.mediaType.name})');
      expect(
        results.any((r) => r.title.toLowerCase().contains('queen of tears')),
        isTrue,
      );
    });

    test('5. MediaProvider.fetchHomeContent loads Dramas, Movies, TV, and Anime with empty TMDB API key', () async {
      final provider = MediaProvider(
        tmdbService: TmdbService(apiKey: ''), // Explicitly empty API key
        anilistService: AnilistService(),
        dramaService: dramaService,
      );

      await provider.fetchHomeContent();

      // ignore: avoid_print
      print(
        'MediaProvider (Key-Free) -> '
        'Trending: ${provider.trending.length}, '
        'Asian Dramas: ${provider.asianDramas.length}, '
        'Top Dramas: ${provider.topDramas.length}, '
        'Movies: ${provider.popularMovies.length}, '
        'TV: ${provider.popularTv.length}, '
        'Anime: ${provider.topAnime.length}',
      );

      expect(provider.errorMessage, isNull);
      expect(provider.asianDramas, isNotEmpty);
      expect(provider.topDramas, isNotEmpty);
      expect(provider.popularMovies, isNotEmpty);
      expect(provider.popularTv, isNotEmpty);
      expect(provider.topAnime, isNotEmpty);
      expect(provider.popularAnime, isNotEmpty);
      expect(provider.topRatedAnime, isNotEmpty);
      expect(provider.trending, isNotEmpty);

      // Verify ongoing anime (One Piece, ID 21) gets >1000 episodes and multi-season mapping works
      final anilist = AnilistService();
      final onePiece = await anilist.getAnimeDetails(21);
      expect(onePiece, isNotNull);
      expect(onePiece!.numberOfEpisodes, greaterThan(1000));

      final jjkS2Mapping = await anilist.resolveAnimeMapping('145064');
      expect(jjkS2Mapping, isNotNull);
      expect(jjkS2Mapping!.tmdbId, equals('95479'));
      expect(jjkS2Mapping.season, equals(2));

      // Test switching category to 'drama'
      provider.setCategory('drama');
      expect(provider.selectedCategory, equals('drama'));
      expect(provider.filteredTrending.every((m) => m.mediaType == MediaType.drama), isTrue);
    });
  });

  testWidgets('6. UI smoke test: STREAMKIER header and Dramas filter chip render', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
          ChangeNotifierProvider(create: (_) => LibraryProvider(storageService)),
          Provider(create: (_) => TmdbService(apiKey: '')),
          Provider(create: (_) => AnilistService()),
          Provider(create: (_) => DramaService()),
          ChangeNotifierProvider(
            create: (ctx) => MediaProvider(
              tmdbService: ctx.read<TmdbService>(),
              anilistService: ctx.read<AnilistService>(),
              dramaService: ctx.read<DramaService>(),
            ),
          ),
        ],
        child: const StreambertApp(),
      ),
    );

    expect(find.text('STREAMKIER'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Dramas'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('TV Shows'), findsOneWidget);
    expect(find.text('Anime'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);

    expect(
      AdBlockerService.isBlockedUrl('https://www.youtube.com/api/stats/ads?ver=2'),
      isTrue,
    );
    expect(
      AdBlockerService.isBlockedUrl('https://www.youtube.com/pagead/interaction/'),
      isTrue,
    );

    await tester.tap(find.text('Dramas'));
    await tester.pump();
  });
}
