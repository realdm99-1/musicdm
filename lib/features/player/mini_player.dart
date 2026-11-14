import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/el_theme.dart';
import '../tracks/track_artwork.dart';
import 'full_player_sheet.dart';
import 'player_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final el = context.el;
    final track = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();

    final playbackState = ref.watch(playbackStateProvider).value;
    final isPlaying = playbackState?.playing ?? false;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final liveDuration = ref.watch(durationProvider).value;
    final totalDuration = (liveDuration != null && liveDuration > Duration.zero)
        ? liveDuration
        : track.duration;
    final progress = totalDuration.inMilliseconds > 0
        ? (position.inMilliseconds / totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    final handler = ref.read(audioHandlerProvider);

    return Material(
      color: el.bgColor,
      child: InkWell(
        onTap: () => FullPlayerSheet.show(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top 2px progress bar
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: el.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(el.primary),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: el.borderColor, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    TrackArtwork(audioId: track.id, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: el.textColorPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: el.textColorRegular,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isPlaying ? '일시정지' : '재생',
                      onPressed: isPlaying ? handler.pause : handler.play,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: el.primary,
                        size: 28,
                      ),
                    ),
                    IconButton(
                      tooltip: '다음 곡',
                      onPressed: handler.skipToNext,
                      icon: Icon(
                        Icons.skip_next_rounded,
                        color: el.textColorPrimary,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
