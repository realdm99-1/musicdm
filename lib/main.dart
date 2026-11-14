import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/audio/music_audio_handler.dart';
import 'core/theme/el_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/theme_settings_sheet.dart';
import 'features/player/mini_player.dart';
import 'features/player/player_provider.dart';
import 'features/playlists/playlists_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioHandler = await initAudioService();
  await audioHandler.restoreLastSession();

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MusicDmApp(),
    ),
  );
}

class MusicDmApp extends ConsumerWidget {
  const MusicDmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeControllerProvider);

    return MaterialApp(
      title: 'musicdm',
      debugShowCheckedModeBanner: false,
      themeMode: themeSettings.themeMode,
      theme: buildElThemeData(
        brightness: Brightness.light,
        accentColor: themeSettings.accentColor,
      ),
      darkTheme: buildElThemeData(
        brightness: Brightness.dark,
        accentColor: themeSettings.accentColor,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final el = context.el;

    return Scaffold(
      appBar: AppBar(
        title: const Text('musicdm'),
        actions: [
          IconButton(
            tooltip: '테마 설정',
            onPressed: () => ThemeSettingsSheet.show(context),
            icon: Icon(Icons.palette_outlined, color: el.primary),
          ),
        ],
      ),
      body: const Column(
        children: [
          Expanded(
            child: PlaylistsTab(),
          ),
          MiniPlayer(),
        ],
      ),
    );
  }
}
