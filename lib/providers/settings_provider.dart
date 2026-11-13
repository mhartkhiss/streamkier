import 'dart:async';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;

  late String _apiKey;
  late String _defaultSource;
  late int _adsBlocked;
  int _pendingAdIncrements = 0;
  Timer? _adBatchTimer;

  SettingsProvider(this._storageService) {
    _apiKey = _storageService.getTmdbApiKey();
    _defaultSource = _storageService.getDefaultSource();
    const validIds = {'vidlink', 'autoembed', '2embed', 'vidsrc'};
    if (!validIds.contains(_defaultSource)) {
      _defaultSource = 'vidlink';
      _storageService.setDefaultSource('vidlink');
    }
    _adsBlocked = _storageService.getAdsBlockedCount();
  }

  String get apiKey => _apiKey;
  String get defaultSource => _defaultSource;
  int get adsBlocked => _adsBlocked;

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    await _storageService.setTmdbApiKey(_apiKey);
    notifyListeners();
  }

  Future<void> setDefaultSource(String sourceId) async {
    _defaultSource = sourceId;
    await _storageService.setDefaultSource(sourceId);
    notifyListeners();
  }

  void incrementAdsBlocked([int count = 1]) {
    _adsBlocked += count;
    _pendingAdIncrements += count;
    _adBatchTimer ??= Timer(const Duration(seconds: 3), () {
      final delta = _pendingAdIncrements;
      _pendingAdIncrements = 0;
      _adBatchTimer = null;
      if (delta > 0) {
        _storageService.incrementAdsBlocked(delta);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _adBatchTimer?.cancel();
    super.dispose();
  }
}
