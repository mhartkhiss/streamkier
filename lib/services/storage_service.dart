import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

class StorageService {
  static const String _keyApiKey = 'streambert_tmdb_api_key';
  static const String _keyDefaultSource = 'streambert_default_source';
  static const String _keyWatchlist = 'streambert_watchlist';
  static const String _keyHistory = 'streambert_history';
  static const String _keyAdsBlocked = 'streambert_ads_blocked';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // TMDB API Key (Optional; empty by default since app works key-free)
  String getTmdbApiKey() {
    final stored = _prefs.getString(_keyApiKey) ?? '';
    if (stored == 'e3f0efdcfb767eb2d8b5c9dc7265be00') {
      return '';
    }
    return stored;
  }

  Future<void> setTmdbApiKey(String key) async {
    await _prefs.setString(_keyApiKey, key.trim());
  }

  // Default streaming source
  String getDefaultSource() {
    return _prefs.getString(_keyDefaultSource) ?? 'vidlink';
  }

  Future<void> setDefaultSource(String sourceId) async {
    await _prefs.setString(_keyDefaultSource, sourceId);
  }

  // Watchlist
  List<MediaItem> getWatchlist() {
    final raw = _prefs.getStringList(_keyWatchlist) ?? [];
    return raw
        .map((item) {
          try {
            return MediaItem.fromJson(jsonDecode(item));
          } catch (_) {
            return null;
          }
        })
        .whereType<MediaItem>()
        .toList();
  }

  Future<void> toggleWatchlist(MediaItem item) async {
    final list = getWatchlist();
    final index = list.indexWhere((i) => i.id == item.id && i.mediaType == item.mediaType);
    if (index >= 0) {
      list.removeAt(index);
    } else {
      list.insert(0, item);
    }
    final encoded = list.map((i) => jsonEncode(i.toJson())).toList();
    await _prefs.setStringList(_keyWatchlist, encoded);
  }

  bool isInWatchlist(String id, MediaType type) {
    final list = getWatchlist();
    return list.any((i) => i.id == id && i.mediaType == type);
  }

  // Watch History
  List<Map<String, dynamic>> getHistory() {
    final raw = _prefs.getStringList(_keyHistory) ?? [];
    return raw
        .map((item) {
          try {
            return jsonDecode(item) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> recordWatchHistory({
    required MediaItem item,
    int season = 1,
    int episode = 1,
  }) async {
    final history = getHistory();
    history.removeWhere((entry) => entry['id'] == item.id);
    history.insert(0, {
      'id': item.id,
      'item': item.toJson(),
      'season': season,
      'episode': episode,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    // Keep max 50 items
    if (history.length > 50) history.removeLast();
    final encoded = history.map((e) => jsonEncode(e)).toList();
    await _prefs.setStringList(_keyHistory, encoded);
  }

  // Ad stats
  int getAdsBlockedCount() {
    return _prefs.getInt(_keyAdsBlocked) ?? 0;
  }

  Future<void> incrementAdsBlocked([int count = 1]) async {
    final current = getAdsBlockedCount();
    await _prefs.setInt(_keyAdsBlocked, current + count);
  }
}
