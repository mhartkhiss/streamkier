import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/anilist_service.dart';
import '../services/drama_service.dart';
import '../services/tmdb_service.dart';

class MediaProvider extends ChangeNotifier {
  final TmdbService _tmdbService;
  final AnilistService _anilistService;
  final DramaService _dramaService;

  List<MediaItem> _trending = [];
  List<MediaItem> _popularMovies = [];
  List<MediaItem> _popularTv = [];
  List<MediaItem> _asianDramas = [];
  List<MediaItem> _aiDramas = [];
  List<MediaItem> _topDramas = [];
  List<MediaItem> _topAnime = [];
  List<MediaItem> _popularAnime = [];
  List<MediaItem> _topRatedAnime = [];

  List<MediaItem> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  String _selectedCategory = 'all'; // 'all', 'drama', 'movie', 'tv', 'anime'

  MediaProvider({
    required TmdbService tmdbService,
    required AnilistService anilistService,
    DramaService? dramaService,
  })  : _tmdbService = tmdbService,
        _anilistService = anilistService,
        _dramaService = dramaService ?? DramaService();

  List<MediaItem> get trending => _trending;
  List<MediaItem> get popularMovies => _popularMovies;
  List<MediaItem> get popularTv => _popularTv;
  List<MediaItem> get asianDramas => _asianDramas;
  List<MediaItem> get aiDramas => _aiDramas;
  List<MediaItem> get topDramas => _topDramas;
  List<MediaItem> get topAnime => _topAnime;
  List<MediaItem> get popularAnime => _popularAnime;
  List<MediaItem> get topRatedAnime => _topRatedAnime;
  List<MediaItem> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;

  List<MediaItem> get filteredTrending {
    if (_selectedCategory == 'drama') {
      return _asianDramas.isNotEmpty ? _asianDramas : _topDramas;
    } else if (_selectedCategory == 'movie') {
      final movies = _trending.where((m) => m.mediaType == MediaType.movie).toList();
      return movies.isNotEmpty ? movies : _popularMovies;
    } else if (_selectedCategory == 'tv') {
      final shows = _trending.where((m) => m.mediaType == MediaType.tv).toList();
      return shows.isNotEmpty ? shows : _popularTv;
    } else if (_selectedCategory == 'anime') {
      return _topAnime;
    }
    return _trending;
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> fetchHomeContent() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch key-free Drama and Anime feeds in parallel
      final keyFreeResults = await Future.wait([
        _dramaService.getAsianDramas().catchError((_) => <MediaItem>[]),
        _dramaService.getTrendingDramas().catchError((_) => <MediaItem>[]),
        _anilistService.getTrendingAnime().catchError((_) => <MediaItem>[]),
        _anilistService.getPopularAnime().catchError((_) => <MediaItem>[]),
        _anilistService.getTopRatedAnime().catchError((_) => <MediaItem>[]),
        _dramaService.getAiDramas().catchError((_) => <MediaItem>[]),
      ]);

      _asianDramas = keyFreeResults[0];
      _topDramas = keyFreeResults[1];
      _topAnime = keyFreeResults[2];
      _popularAnime = keyFreeResults[3];
      _topRatedAnime = keyFreeResults[4];
      _aiDramas = keyFreeResults[5];

      try {
        final tmdbResults = await Future.wait([
          _tmdbService.getTrending(),
          _tmdbService.getPopularMovies(),
          _tmdbService.getPopularTv(),
          _tmdbService.getPopularDramas(),
        ]);
        _trending = tmdbResults[0];
        _popularMovies = tmdbResults[1];
        _popularTv = tmdbResults[2];
        if (tmdbResults[3].isNotEmpty) {
          final seen = _asianDramas.map((d) => d.title.toLowerCase()).toSet();
          for (final item in tmdbResults[3]) {
            if (!seen.contains(item.title.toLowerCase())) {
              _asianDramas.add(item);
            }
          }
        }
      } catch (_) {
        // Handled by empty check below
      }

      // If TMDB returned empty (blank key) or threw (invalid key), use key-free fallbacks
      if (_popularMovies.isEmpty || _popularTv.isEmpty) {
        final fallbackResults = await Future.wait([
          _dramaService.getPopularMoviesFallback(),
          _dramaService.getPopularTvFallback(),
        ]);
        if (_popularMovies.isEmpty) _popularMovies = fallbackResults[0];
        if (_popularTv.isEmpty) _popularTv = fallbackResults[1];
      }

      if (_trending.isEmpty) {
        final List<MediaItem> combinedTrending = [
          ..._asianDramas.take(6),
          ..._topDramas.take(6),
          ..._popularMovies.take(4),
          ..._topAnime.take(4),
        ];

        if (combinedTrending.isNotEmpty) {
          _trending = combinedTrending;
        } else {
          _errorMessage = 'Failed to load content. Check your internet connection.';
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _dramaService.search(query).catchError((_) => <MediaItem>[]),
        _tmdbService.search(query).catchError((_) => <MediaItem>[]),
        _anilistService.searchAnime(query).catchError((_) => <MediaItem>[]),
      ]);

      final dramaAndGeneralResults = results[0];
      final tmdbResults = results[1];
      final animeResults = results[2];

      final List<MediaItem> merged = [];
      final Set<String> seen = {};

      for (final item in [...tmdbResults, ...dramaAndGeneralResults, ...animeResults]) {
        final key = '${item.title.toLowerCase()}_${item.mediaType.name}';
        if (!seen.contains(key)) {
          seen.add(key);
          merged.add(item);
        }
      }

      _searchResults = merged;
    } catch (_) {
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }
}
