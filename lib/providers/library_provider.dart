import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';

class LibraryProvider extends ChangeNotifier {
  final StorageService _storageService;

  List<MediaItem> _watchlist = [];
  List<Map<String, dynamic>> _history = [];

  LibraryProvider(this._storageService) {
    loadData();
  }

  List<MediaItem> get watchlist => _watchlist;
  List<Map<String, dynamic>> get history => _history;

  void loadData() {
    _watchlist = _storageService.getWatchlist();
    _history = _storageService.getHistory();
    notifyListeners();
  }

  bool isInWatchlist(MediaItem item) {
    return _watchlist.any((i) => i.id == item.id && i.mediaType == item.mediaType);
  }

  Future<void> toggleWatchlist(MediaItem item) async {
    await _storageService.toggleWatchlist(item);
    _watchlist = _storageService.getWatchlist();
    notifyListeners();
  }

  Future<void> recordWatchHistory(MediaItem item, {int season = 1, int episode = 1}) async {
    await _storageService.recordWatchHistory(item: item, season: season, episode: episode);
    _history = _storageService.getHistory();
    notifyListeners();
  }
}
