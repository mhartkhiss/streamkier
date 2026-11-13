import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AdBlockerService {
  static final List<String> blockedPatterns = [
    ".*doubleclick\\.net.*",
    ".*google-analytics\\.com.*",
    ".*googletagmanager\\.com.*",
    ".*googlesyndication\\.com.*",
    ".*adservice\\.google\\..*",
    ".*mc\\.yandex\\..*",
    ".*profitableratecpm\\.com.*",
    ".*acscdn\\.com.*",
    ".*protrafficinspector\\.com.*",
    ".*cloudflareinsights\\.com.*",
    ".*histats\\.com.*",
    ".*usrpubtrk\\.com.*",
    ".*adexchangeclear\\.com.*",
    ".*popads\\.net.*",
    ".*popcash\\.net.*",
    ".*adnxs\\.com.*",
    ".*adsystem\\.com.*",
    ".*track\\.trafficjunky\\.com.*",
    ".*exoclick\\.com.*",
    ".*juicyads\\.com.*",
    ".*tsyndicate\\.com.*",
    ".*onclickbright\\.com.*",
    ".*alwingulla\\.com.*",
    ".*in-page-push\\.com.*",
    ".*bet365\\..*",
    ".*1xbet\\..*",
    ".*disable-devtool.*",
    ".*createlouisville\\.org.*",
    ".*tagivi\\.com.*",
    ".*vidlink\\.pro/api/mercury.*",
    ".*vidlink\\.pro/api/venus.*",
    ".*youtube\\.com/api/stats/ads.*",
    ".*youtube\\.com/pagead/.*",
    ".*youtube\\.com/ptracking.*",
    ".*youtube\\.com/get_midroll_.*",
    ".*googleads\\.g\\.doubleclick\\.net.*",
    ".*static\\.doubleclick\\.net.*",
  ];

  /// Injected at AT_DOCUMENT_START to enable background/lock-screen playback
  /// when on the YouTube tab, strip pre-roll/mid-roll ad placements from player
  /// JSON responses so videos start playing immediately with zero ad-wait delay,
  /// and strictly block autoplay/previews when another app tab is focused.
  static const String youtubeBackgroundPlayScript = '''
    (function() {
      if (window.__streamkierBgPlay) return;
      window.__streamkierBgPlay = true;

      // Strip adPlacements/playerAds/adSlots from YouTube player JSON so videos start instantly
      function stripPlayerAds(obj) {
        if (!obj || typeof obj !== 'object') return obj;
        try {
          if ('adPlacements' in obj) delete obj.adPlacements;
          if ('playerAds' in obj) delete obj.playerAds;
          if ('adSlots' in obj) delete obj.adSlots;
          if (obj.playerResponse && typeof obj.playerResponse === 'object') {
            delete obj.playerResponse.adPlacements;
            delete obj.playerResponse.playerAds;
            delete obj.playerResponse.adSlots;
          }
        } catch (_) {}
        return obj;
      }

      try {
        const origParse = JSON.parse;
        JSON.parse = function(text, reviver) {
          const data = origParse.call(this, text, reviver);
          return stripPlayerAds(data);
        };
      } catch (_) {}

      try {
        if (window.Response && Response.prototype.json) {
          const origJson = Response.prototype.json;
          Response.prototype.json = function() {
            return origJson.call(this).then(stripPlayerAds);
          };
        }
      } catch (_) {}

      try {
        let _ytInitResp = window.ytInitialPlayerResponse;
        Object.defineProperty(window, 'ytInitialPlayerResponse', {
          configurable: true,
          get: function() { return _ytInitResp; },
          set: function(val) { _ytInitResp = stripPlayerAds(val); }
        });
      } catch (_) {}

      try {
        Object.defineProperty(Document.prototype, 'hidden', {
          get: function() { return false; },
          configurable: true
        });
        Object.defineProperty(Document.prototype, 'webkitHidden', {
          get: function() { return false; },
          configurable: true
        });
        Object.defineProperty(Document.prototype, 'visibilityState', {
          get: function() { return 'visible'; },
          configurable: true
        });
        Object.defineProperty(Document.prototype, 'webkitVisibilityState', {
          get: function() { return 'visible'; },
          configurable: true
        });
      } catch (_) {}

      const blockEvents = ['visibilitychange', 'webkitvisibilitychange', 'mozvisibilitychange', 'pagehide'];
      for (const evt of blockEvents) {
        window.addEventListener(evt, function(e) {
          e.stopImmediatePropagation();
        }, true);
        document.addEventListener(evt, function(e) {
          e.stopImmediatePropagation();
        }, true);
      }

      // Prevent any autoplay or inline preview from playing when YouTube tab is not focused
      const mediaEvents = ['play', 'playing', 'timeupdate'];
      for (const evt of mediaEvents) {
        document.addEventListener(evt, function(e) {
          if (window.__streamkierTabInactive && e.target && typeof e.target.pause === 'function') {
            try { e.target.pause(); } catch (_) {}
          }
        }, true);
      }

      // Keep YouTube activity timestamp fresh so background playback never auto-pauses
      setInterval(function() {
        try {
          if (!window.__streamkierTabInactive) {
            window._lact = Date.now();
          }
        } catch (_) {}
      }, 5000);
    })();
  ''';

  /// Injected user script that strips YouTube banner/feed ads via CSS
  /// and auto-skips or fast-forwards any video pre-roll/mid-roll ads.
  /// Guarded for idempotency and uses lightweight polling instead of
  /// full-DOM MutationObserver to prevent scroll FPS spikes.
  static const String youtubeAdBlockScript = '''
    (function() {
      if (window.__streamkierYtAdBlock) return;
      window.__streamkierYtAdBlock = true;

      const style = document.createElement('style');
      style.id = 'streamkier-yt-adblock-style';
      style.textContent = `
        ytm-promoted-sparkles-web-renderer,
        ytm-promoted-video-renderer,
        ytm-companion-ad-renderer,
        ytm-in-feed-ad-layout-renderer,
        ytd-ad-slot-renderer,
        ytd-in-feed-ad-layout-renderer,
        ytd-banner-promo-renderer,
        ytd-promoted-sparkles-web-renderer,
        ytd-compact-promoted-video-renderer,
        .ytp-ad-overlay-container,
        .ytp-ad-message-container,
        .ytp-ad-image-overlay,
        .ytp-ad-text-overlay,
        #player-ads,
        #masthead-ad,
        ytm-mealbar-promo-renderer,
        ytm-statement-banner-renderer {
          display: none !important;
          height: 0 !important;
          visibility: hidden !important;
          pointer-events: none !important;
        }
      `;
      (document.head || document.documentElement).appendChild(style);

      function skipYouTubeAds() {
        try {
          const player = document.querySelector('.html5-video-player.ad-showing, .html5-video-player.ad-interrupting');
          if (!player) return;

          const skipBtn = player.querySelector(
            '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, .videoAdUiSkipButton, button.ytp-ad-overlay-close-button'
          );
          if (skipBtn) {
            skipBtn.click();
          }

          const video = player.querySelector('video');
          if (video) {
            video.muted = true;
            if (isFinite(video.duration) && video.duration > 0 && video.currentTime < video.duration - 0.1) {
              video.currentTime = video.duration;
            } else if (video.playbackRate < 8.0) {
              video.playbackRate = 16.0;
            }
          }
        } catch (_) {}
      }

      setInterval(skipYouTubeAds, 600);
    })();
  ''';

  static final RegExp _combinedBlockRegex = RegExp(
    blockedPatterns.map((p) => '(?:$p)').join('|'),
    caseSensitive: false,
  );

  static final List<ContentBlocker> _cachedContentBlockers = List.unmodifiable(
    blockedPatterns.map((pattern) {
      return ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: pattern,
        ),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.BLOCK,
        ),
      );
    }),
  );

  static List<ContentBlocker> getContentBlockers() => _cachedContentBlockers;

  static bool isBlockedUrl(String url) {
    return _combinedBlockRegex.hasMatch(url);
  }
}
