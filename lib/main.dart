import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/library_provider.dart';
import 'providers/media_provider.dart';
import 'providers/settings_provider.dart';
import 'services/anilist_service.dart';
import 'services/drama_service.dart';
import 'services/storage_service.dart';
import 'services/tmdb_service.dart';
import 'ui/screens/main_screen.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation colors
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = await StorageService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(storageService),
        ),
        ProxyProvider<SettingsProvider, TmdbService>(
          update: (_, settings, _) => TmdbService(apiKey: settings.apiKey),
        ),
        Provider(
          create: (_) => AnilistService(),
        ),
        Provider(
          create: (_) => DramaService(),
        ),
        ChangeNotifierProxyProvider2<TmdbService, AnilistService, MediaProvider>(
          create: (ctx) => MediaProvider(
            tmdbService: ctx.read<TmdbService>(),
            anilistService: ctx.read<AnilistService>(),
            dramaService: ctx.read<DramaService>(),
          )..fetchHomeContent(),
          update: (ctx, tmdb, anilist, media) =>
              (media ??
                  MediaProvider(
                    tmdbService: tmdb,
                    anilistService: anilist,
                    dramaService: ctx.read<DramaService>(),
                  )),
        ),
      ],
      child: const StreambertApp(),
    ),
  );
}

class StreambertApp extends StatelessWidget {
  const StreambertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'streamkier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}

