import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:musicdm/core/audio/music_track.dart';
import 'package:musicdm/core/theme/el_theme.dart';
import 'package:musicdm/features/playlists/playlist_dialogs.dart';

void main() {
  test('formatDuration formats mm:ss and hh:mm:ss', () {
    expect(formatDuration(const Duration(seconds: 5)), '00:05');
    expect(formatDuration(const Duration(minutes: 3, seconds: 42)), '03:42');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  test('buildElThemeData provides Element Plus tokens for light and dark', () {
    final light = buildElThemeData(
      brightness: Brightness.light,
      accentColor: const Color(0xFF409EFF),
    );
    final dark = buildElThemeData(
      brightness: Brightness.dark,
      accentColor: const Color(0xFF67C23A),
    );

    final lightTokens = light.extension<ElThemeTokens>()!;
    final darkTokens = dark.extension<ElThemeTokens>()!;

    expect(lightTokens.bgColor, const Color(0xFFFFFFFF));
    expect(lightTokens.bgColorPage, const Color(0xFFF2F3F5));
    expect(lightTokens.primary, const Color(0xFF409EFF));

    expect(darkTokens.bgColor, const Color(0xFF141414));
    expect(darkTokens.bgColorPage, const Color(0xFF0A0A0A));
    expect(darkTokens.primary, const Color(0xFF67C23A));
  });

  testWidgets('showCreatePlaylistDialog closes cleanly on cancel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildElThemeData(
            brightness: Brightness.light,
            accentColor: const Color(0xFF409EFF),
          ),
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showCreatePlaylistDialog(context, ref),
                    child: const Text('새 플레이리스트'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('새 플레이리스트'));
    await tester.pumpAndSettle();

    expect(find.text('취소'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('취소'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
