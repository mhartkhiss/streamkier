import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../models/episode.dart';
import '../../models/media_item.dart';
import '../../models/streaming_source.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/ad_blocker_service.dart';
import '../../services/anilist_service.dart';
import '../../services/drama_service.dart';
import '../theme.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem item;
  final Episode? episode;
  final StreamingSource source;

  const PlayerScreen({
    super.key,
    required this.item,
    this.episode,
    required this.source,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  InAppWebViewController? _webViewController;
  late StreamingSource _currentSource;
  late MediaItem _item;
  bool _isLoading = true;
  bool _isResolvingId = false;
  bool _showControls = true;
  String? _capturedStreamUrl;
  Timer? _hideControlsTimer;

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _revealControlsTemporarily() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _scheduleHideControls();
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _currentSource = widget.source;
    _isResolvingId = _item.effectiveTmdbId.isEmpty;
    _scheduleHideControls();

    // Enable landscape and hide system status bars for immersive cinema mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    // Record watch history and resolve TMDB ID before loading WebView if needed
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final epNum = widget.episode?.episodeNumber ?? 1;
      final sNum = widget.episode?.seasonNumber ?? 1;
      context.read<LibraryProvider>().recordWatchHistory(
            _item,
            season: sNum,
            episode: epNum,
          );

      if (_item.effectiveTmdbId.isEmpty && _item.mediaType == MediaType.anime) {
        final resolved = await context.read<AnilistService>().resolveTmdbId(_item.id);
        if (mounted) {
          setState(() {
            if (resolved != null) _item = _item.copyWith(tmdbId: resolved);
            _isResolvingId = false;
          });
        }
      } else if (_item.effectiveTmdbId.isEmpty) {
        final resolved = await context.read<DramaService>().getDetailsAndSeasons(_item);
        if (mounted) {
          setState(() {
            if (resolved != null && resolved.details.effectiveTmdbId.isNotEmpty) {
              _item = resolved.details;
            }
            _isResolvingId = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    // Restore orientations and system bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  String _buildStreamUrl() {
    final effectiveId = _item.effectiveTmdbId.isNotEmpty ? _item.effectiveTmdbId : _item.id;
    return _currentSource.getUrl(
      tmdbId: effectiveId,
      mediaType: _item.mediaType,
      season: widget.episode?.seasonNumber ?? 1,
      episode: widget.episode?.episodeNumber ?? 1,
    );
  }

  void _switchSource(StreamingSource newSource) {
    setState(() {
      _currentSource = newSource;
      _isLoading = true;
    });
    _scheduleHideControls();
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_buildStreamUrl())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item.title;
    final epLabel = widget.episode != null
        ? 'S${widget.episode!.seasonNumber} E${widget.episode!.episodeNumber} - ${widget.episode!.name}'
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The InAppWebView with Ad-blocking, DOM storage, and fast iframe pass-through
          if (!_isResolvingId)
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(_buildStreamUrl()),
              ),
              initialUserScripts: UnmodifiableListView([
                UserScript(
                  source: '''
                    (function() {
                      function noop() {}
                      window.DisableDevtool = noop;
                      window.disableDevtool = noop;
                      try {
                        Object.defineProperty(window, 'DisableDevtool', {
                          get: function() { return noop; },
                          set: function(_) {}
                        });
                        Object.defineProperty(window, 'disableDevtool', {
                          get: function() { return noop; },
                          set: function(_) {}
                        });
                      } catch(e) {}

                      // Block popups and popunders at DOM level
                      window.open = function() { return null; };
                      try {
                        Object.defineProperty(window, 'open', {
                          get: function() { return function() { return null; }; },
                          set: function(_) {}
                        });
                      } catch(e) {}
                    })();
                  ''',
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  forMainFrameOnly: false,
                  contentWorld: ContentWorld.PAGE,
                ),
              ]),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                transparentBackground: false,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                supportMultipleWindows: false,
                javaScriptCanOpenWindowsAutomatically: false,
                useShouldInterceptRequest: false,
                contentBlockers: AdBlockerService.getContentBlockers(),
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                controller.resumeTimers();
              },
              onCreateWindow: (controller, createWindowAction) async {
                // Reject opening new windows/tabs (e.g. ad popunders)
                return false;
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri == null) return NavigationActionPolicy.CANCEL;
                final url = uri.toString();

                // Always block known ad/tracker URLs in both main frame and iframes
                if (AdBlockerService.isBlockedUrl(url)) {
                  if (mounted) {
                    context.read<SettingsProvider>().incrementAdsBlocked();
                  }
                  return NavigationActionPolicy.CANCEL;
                }

                // Allow nested video player iframes (!isForMainFrame) so internal stream CDNs
                // (e.g. vidsrc.sh, cloudnestra, megacloud, rabbitstream) load immediately without timing out.
                if (!navigationAction.isForMainFrame) {
                  return NavigationActionPolicy.ALLOW;
                }

                // Restrict top-level main-frame navigation to allowed streaming domains
                const allowedMainDomains = [
                  'vidlink.pro',
                  'vidsrc.sh',
                  'vidsrc.to',
                  'vidsrc.me',
                  'vidsrc.net',
                  'autoembed.co',
                  'multiembed.mov',
                  'streamingnow.mov',
                  'vsembed.ru',
                  '2embed.cc',
                  '2embed.org',
                ];

                final host = uri.host.toLowerCase();
                final isAllowedHost =
                    allowedMainDomains.any((d) => host == d || host.endsWith('.$d'));

                if (!isAllowedHost) {
                  if (mounted) {
                    context.read<SettingsProvider>().incrementAdsBlocked();
                  }
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT,
                );
              },
              onLoadResource: (controller, resource) {
                final url = resource.url.toString();
                if (url.contains('.m3u8') && _capturedStreamUrl != url) {
                  if (mounted) {
                    setState(() => _capturedStreamUrl = url);
                  }
                }
              },
              onLoadStart: (controller, url) {
                controller.resumeTimers();
                if (mounted && !_isLoading) {
                  setState(() => _isLoading = true);
                }
              },
              onLoadStop: (controller, url) {
                if (mounted && _isLoading) {
                  setState(() => _isLoading = false);
                }
                _scheduleHideControls();
              },
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame ?? false) {
                  final fallbackId = _currentSource.id == 'vidlink' ? 'autoembed' : 'vidlink';
                  final fallback = StreamingSource.allSources.firstWhere((s) => s.id == fallbackId);
                  _switchSource(fallback);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Auto-switched to ${fallback.name} for faster playback.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              onReceivedHttpError: (controller, request, errorResponse) {
                if ((request.isForMainFrame ?? false) && (errorResponse.statusCode ?? 200) >= 400) {
                  final fallbackId = _currentSource.id == 'vidlink' ? 'autoembed' : 'vidlink';
                  final fallback = StreamingSource.allSources.firstWhere((s) => s.id == fallbackId);
                  _switchSource(fallback);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Auto-switched to ${fallback.name} due to server error.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),

          // Buffering Spinner (IgnorePointer so it doesn't block touches)
          if (_isLoading || _isResolvingId)
            IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 12),
                      Text(
                        'Connecting to streaming server…',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Floating Toggle Controls Button (visible when controls are auto-hidden)
          if (!_showControls)
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: GestureDetector(
                  onTap: _revealControlsTemporarily,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12, width: 0.5),
                    ),
                    child: const Icon(Icons.menu_rounded, color: Colors.white60, size: 18),
                  ),
                ),
              ),
            ),

          // Controls Overlay: Top Bar & Bottom Bar (Auto-hides after 4 seconds)
          if (_showControls) ...[
            // Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Listener(
                onPointerDown: (_) => _scheduleHideControls(),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (epLabel != null)
                                  Text(
                                    epLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_capturedStreamUrl != null)
                            IconButton(
                              icon: const Icon(Icons.link, color: Colors.greenAccent),
                              tooltip: 'M3U8 Stream Detected',
                              onPressed: () {
                                _scheduleHideControls();
                                Clipboard.setData(ClipboardData(text: _capturedStreamUrl!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Direct M3U8 stream copied to clipboard!')),
                                );
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            onPressed: () {
                              _scheduleHideControls();
                              _webViewController?.reload();
                            },
                          ),
                          PopupMenuButton<StreamingSource>(
                            icon: const Icon(Icons.dns, color: Colors.white),
                            tooltip: 'Switch Server',
                            initialValue: _currentSource,
                            onOpened: () => _hideControlsTimer?.cancel(),
                            onCanceled: _scheduleHideControls,
                            onSelected: _switchSource,
                            itemBuilder: (context) {
                              return StreamingSource.allSources
                                  .where((s) => !s.isAnimeOnly || _item.mediaType == MediaType.anime)
                                  .map((source) {
                                return PopupMenuItem<StreamingSource>(
                                  value: source,
                                  child: Row(
                                    children: [
                                      if (source.id == _currentSource.id)
                                        const Icon(Icons.check, color: AppTheme.primary, size: 16)
                                      else
                                        const SizedBox(width: 16),
                                      const SizedBox(width: 8),
                                      Text(source.name),
                                    ],
                                  ),
                                );
                              }).toList();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.visibility_off, color: Colors.white70),
                            tooltip: 'Hide Controls Now',
                            onPressed: () {
                              _hideControlsTimer?.cancel();
                              setState(() => _showControls = false);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Bar (IgnorePointer so it never blocks bottom player seekbars)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield, color: Colors.greenAccent, size: 16),
                              const SizedBox(width: 6),
                              Consumer<SettingsProvider>(
                                builder: (_, settings, _) => Text(
                                  'AdBlock Active (${settings.adsBlocked} blocked)',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Server: ${_currentSource.name}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
