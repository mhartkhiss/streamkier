import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/ad_blocker_service.dart';
import '../theme.dart';

class YouTubeScreen extends StatefulWidget {
  final bool isActive;

  const YouTubeScreen({super.key, this.isActive = false});

  @override
  State<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends State<YouTubeScreen> {
  static const String _homeUrl = 'https://m.youtube.com';

  InAppWebViewController? _controller;
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String?> _activeVideoIdNotifier = ValueNotifier<String?>(null);
  bool _hasActivated = false;
  bool _isPureEmbedMode = false;
  String _currentUrl = _homeUrl;
  String _selectedTopic = 'Home';

  static const List<({String label, IconData icon, String url})> _topics = [
    (label: 'Home', icon: Icons.home_rounded, url: 'https://m.youtube.com'),
    (
      label: 'AI Dramas',
      icon: Icons.smart_toy_rounded,
      url: 'https://m.youtube.com/results?search_query=AI+drama+short+film+series+full',
    ),
    (
      label: 'Short Dramas',
      icon: Icons.play_lesson_rounded,
      url: 'https://m.youtube.com/results?search_query=full+short+drama+movie+eng+sub',
    ),
    (
      label: 'Trending',
      icon: Icons.local_fire_department_rounded,
      url: 'https://m.youtube.com/feed/trending',
    ),
    (
      label: 'K-Drama OSTs',
      icon: Icons.queue_music_rounded,
      url: 'https://m.youtube.com/results?search_query=kdrama+ost+playlist',
    ),
    (
      label: 'Trailers',
      icon: Icons.movie_creation_outlined,
      url: 'https://m.youtube.com/results?search_query=official+trailer+4k',
    ),
    (
      label: 'Music',
      icon: Icons.music_note_rounded,
      url: 'https://m.youtube.com/results?search_query=top+music+hits',
    ),
    (
      label: 'Anime Clips',
      icon: Icons.auto_awesome_rounded,
      url: 'https://m.youtube.com/results?search_query=anime+ost+clips',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _hasActivated = true;
    }
  }

  @override
  void didUpdateWidget(covariant YouTubeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (!_hasActivated) {
          setState(() => _hasActivated = true);
        } else {
          _controller?.resumeTimers();
          _controller?.evaluateJavascript(
            source: 'window.__streamkierTabInactive = false;',
          );
        }
      } else {
        // Pause all playing videos, inline previews, and autoplay when leaving the YouTube tab
        // without calling global pauseTimers() (which would freeze PlayerScreen's WebView).
        _controller?.evaluateJavascript(
          source: '''
            window.__streamkierTabInactive = true;
            document.querySelectorAll('video, audio').forEach(function(el) {
              try { el.pause(); } catch (_) {}
            });
          ''',
        );
      }
    }
  }

  @override
  void dispose() {
    _isLoadingNotifier.dispose();
    _activeVideoIdNotifier.dispose();
    super.dispose();
  }

  String? _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    final segments = uri.pathSegments;
    final shortsIdx = segments.indexOf('shorts');
    if (shortsIdx != -1 && shortsIdx + 1 < segments.length) {
      return segments[shortsIdx + 1];
    }
    final embedIdx = segments.indexOf('embed');
    if (embedIdx != -1 && embedIdx + 1 < segments.length) {
      return segments[embedIdx + 1];
    }
    return null;
  }

  void _updateUrlTracking(String url) {
    _currentUrl = url;
    final vid = _extractVideoId(url);
    if (_activeVideoIdNotifier.value != vid) {
      _activeVideoIdNotifier.value = vid;
    }
  }

  void _loadUrl(String url) {
    _updateUrlTracking(url);
    _isLoadingNotifier.value = true;
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void _togglePureEmbed() {
    final videoId = _extractVideoId(_currentUrl);
    if (videoId == null || videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open any YouTube video first to switch to Pure Ad-Free Embed mode.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isPureEmbedMode) {
      setState(() => _isPureEmbedMode = false);
      _loadUrl('https://m.youtube.com/watch?v=$videoId');
    } else {
      setState(() => _isPureEmbedMode = true);
      _loadUrl('https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&rel=0');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_display_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text(
                    'YOUTUBE',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 12),
                  const SizedBox(width: 4),
                  Selector<SettingsProvider, int>(
                    selector: (_, s) => s.adsBlocked,
                    builder: (_, adsBlocked, _) => Text(
                      'Ad-Free ($adsBlocked)',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<String?>(
            valueListenable: _activeVideoIdNotifier,
            builder: (_, activeVideoId, _) {
              if (activeVideoId == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isPureEmbedMode ? Colors.greenAccent : Colors.white,
                    side: BorderSide(
                      color: _isPureEmbedMode ? Colors.greenAccent : Colors.white24,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: Icon(
                    _isPureEmbedMode ? Icons.check_circle_rounded : Icons.bolt_rounded,
                    size: 15,
                  ),
                  label: Text(
                    _isPureEmbedMode ? 'Pure Mode' : 'Pure Player',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _togglePureEmbed,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () async {
              if (_controller != null && await _controller!.canGoBack()) {
                await _controller!.goBack();
              }
            },
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => _controller?.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Topic Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: _topics.map((topic) {
                final isSelected = _selectedTopic == topic.label && !_isPureEmbedMode;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTopic = topic.label;
                        _isPureEmbedMode = false;
                      });
                      _loadUrl(topic.url);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : Colors.white10,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            topic.icon,
                            size: 13,
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            topic.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: _isLoadingNotifier,
            builder: (_, isLoading, _) {
              if (!isLoading) return const SizedBox.shrink();
              return const LinearProgressIndicator(
                color: AppTheme.primary,
                backgroundColor: Colors.transparent,
                minHeight: 2,
              );
            },
          ),

          // Ad-Free YouTube WebView
          Expanded(
            child: !_hasActivated
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(_homeUrl)),
                    initialUserScripts: UnmodifiableListView([
                      UserScript(
                        source: AdBlockerService.youtubeBackgroundPlayScript,
                        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                        forMainFrameOnly: false,
                        contentWorld: ContentWorld.PAGE,
                      ),
                      UserScript(
                        source: AdBlockerService.youtubeAdBlockScript,
                        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                        forMainFrameOnly: true,
                        contentWorld: ContentWorld.PAGE,
                      ),
                    ]),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      supportMultipleWindows: false,
                      javaScriptCanOpenWindowsAutomatically: false,
                      useShouldInterceptRequest: false,
                      contentBlockers: AdBlockerService.getContentBlockers(),
                    ),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                    },
                    onCreateWindow: (_, _) async => false,
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      final uri = navigationAction.request.url;
                      if (uri == null) return NavigationActionPolicy.CANCEL;
                      final url = uri.toString();

                      if (AdBlockerService.isBlockedUrl(url)) {
                        if (mounted) {
                          context.read<SettingsProvider>().incrementAdsBlocked();
                        }
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStart: (_, url) {
                      _isLoadingNotifier.value = true;
                      if (url != null) _updateUrlTracking(url.toString());
                    },
                    onLoadStop: (controller, url) async {
                      await controller.evaluateJavascript(
                        source: '''
                          window.__streamkierTabInactive = ${!widget.isActive};
                          ${AdBlockerService.youtubeBackgroundPlayScript}
                          ${AdBlockerService.youtubeAdBlockScript}
                        ''',
                      );
                      if (!widget.isActive) {
                        await controller.evaluateJavascript(
                          source: '''
                            document.querySelectorAll('video, audio').forEach(function(el) {
                              try { el.pause(); } catch (_) {}
                            });
                          ''',
                        );
                      }
                      _isLoadingNotifier.value = false;
                      if (url != null) _updateUrlTracking(url.toString());
                    },
                    onUpdateVisitedHistory: (_, url, _) {
                      if (url != null) {
                        _updateUrlTracking(url.toString());
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
