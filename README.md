# Streamkier (Flutter Android & Cross-Platform)

A modern, ad-free streaming client for **Movies, TV Series, Anime, Short Dramas, AI Dramas, and Ad-Free YouTube**, built with **Flutter**.

---

## ✨ Features

- 🎬 **Fast Multi-Source Streaming**: Stream movies and series with instant server switching (**VidLink Pro**, **AutoEmbed**, **2Embed**, **VidSrc**).
- ▶️ **Ad-Free YouTube + Background Play**: Built-in mobile YouTube experience with pre-roll/mid-roll JSON ad stripping, promoted slot hiding, background/lock-screen audio playback (`ForegroundService` + `WakeLock`), and automatic pause when switching tabs.
- 🤖 **AI Dramas & Short Dramas**: Curated **AI & Sci-Fi Dramas** and vertical **Short Dramas** (ReelShort, DramaBox, ShortMax, K-Dramas, C-Dramas) with instant multi-part search and playback.
- ⛩️ **Anime Support**: Anime discovery via **AniList GraphQL** with custom stream scraping ported from `allmanga`.
- 🛡️ **Zero-Freeze Ad & Tracker Blocker**: Pre-compiled native regex content blockers + popup/redirect prevention and batched ad-block telemetry.
- 📡 **Stream Sniffer**: Intercepts and exposes direct `.m3u8` HLS playlist URLs with one-tap clipboard copy.
- 📺 **TV & Series Support**: Season selector, lazy-loaded episode guide with thumbnails, synopses, and auto-hiding immersive player controls.
- 📚 **Library & Watch History**: Keep track of your watchlist and resume watched episodes from where you left off.
- 🔍 **Unified Search**: Search across movies, TV series, anime, and dramas with live results.
- 🎨 **Streamkier Dark Theme**: Sleek dark aesthetic (`#0A0A0A`) with crimson/coral accents and custom launcher icons.

---

## 🏗️ Architecture

```text
streamkier/
├── lib/
│   ├── models/
│   │   ├── media_item.dart        # Unified Movie, TV, Anime, Drama model
│   │   ├── episode.dart           # Episode details & thumbnails
│   │   └── streaming_source.dart  # VidLink Pro, AutoEmbed, 2Embed, VidSrc, AllManga
│   ├── services/
│   │   ├── tmdb_service.dart       # REST client for TMDB (movies/tv)
│   │   ├── anilist_service.dart    # GraphQL client for anime
│   │   ├── allmanga_service.dart   # Hex cipher decipher & stream resolver
│   │   ├── drama_service.dart      # Curated Short Dramas & AI/Sci-Fi Dramas
│   │   ├── ad_blocker_service.dart # Pre-compiled ContentBlockers & YouTube ad-strip/bg-play JS
│   │   └── storage_service.dart    # SharedPreferences local persistence
│   ├── providers/
│   │   ├── media_provider.dart     # Trending, search, categories, AI/Short dramas state
│   │   ├── library_provider.dart   # Watchlist & continue watching history
│   │   └── settings_provider.dart  # API keys, server selection & batched ad-blocking stats
│   ├── ui/
│   │   ├── screens/
│   │   │   ├── main_screen.dart    # Bottom nav shell (Home, YouTube, Search, Library, Settings)
│   │   │   ├── home_screen.dart    # Featured banner, category chips, media rows
│   │   │   ├── youtube_screen.dart # Ad-free YouTube with background play & quick filter pills
│   │   │   ├── search_screen.dart  # Live search grid across Movies, TV, Anime & Dramas
│   │   │   ├── details_screen.dart # Backdrops, season selector, lazy episode list
│   │   │   ├── player_screen.dart  # Immersive InAppWebView player with auto-hiding controls
│   │   │   ├── library_screen.dart # Watchlist & watch history tabs
│   │   │   └── settings_screen.dart# Preferences, server default & TMDB key configuration
│   │   ├── widgets/
│   │   │   ├── media_card.dart     # GPU-optimized poster card with rating and tags
│   │   │   └── media_row.dart      # Horizontal scrolling carousel
│   │   └── theme.dart              # Streamkier dark theme palette
│   └── main.dart                   # App entrypoint & MultiProvider setup
└── android/                        # Android native config + BackgroundMediaService foreground service
```

---

## 🚀 Running the App

### Prerequisites
- Flutter SDK (>= 3.19.0)
- Android SDK & Device or Emulator (Android 5.0+ / API 21+)

### Commands
```bash
# Install dependencies
flutter pub get

# Run on connected Android device/emulator
flutter run

# Build release APK
flutter build apk --release
```
The generated APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🔑 Configuration
By default, the app includes a fallback TMDB access key so it works out of the box. You can enter your own free TMDB API Key anytime in **Settings > TMDB API Key**.
