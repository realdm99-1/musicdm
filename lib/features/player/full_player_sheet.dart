import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/music_track.dart';
import '../../core/theme/el_theme.dart';
import '../tracks/track_artwork.dart';
import 'player_provider.dart';
import 'queue_bottom_sheet.dart';

class FullPlayerSheet extends ConsumerStatefulWidget {
  const FullPlayerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FullPlayerSheet(),
    );
  }

  @override
  ConsumerState<FullPlayerSheet> createState() => _FullPlayerSheetState();
}

class _FullPlayerSheetState extends ConsumerState<FullPlayerSheet> {
  double? _dragValueMs;

  @override
  Widget build(BuildContext context) {
    final el = context.el;
    final track = ref.watch(currentTrackProvider);
    final playbackState = ref.watch(playbackStateProvider).value;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final liveDuration = ref.watch(durationProvider).value;
    final handler = ref.read(audioHandlerProvider);

    if (track == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = playbackState?.playing ?? false;
    final repeatMode = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
    final shuffleMode =
        playbackState?.shuffleMode ?? AudioServiceShuffleMode.none;
    final isShuffled = shuffleMode != AudioServiceShuffleMode.none;

    final totalDuration = (liveDuration != null && liveDuration > Duration.zero)
        ? liveDuration
        : track.duration;
    final maxMs = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds.toDouble()
        : 1.0;
    final currentMs = (_dragValueMs ?? position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs);

    return Container(
      decoration: BoxDecoration(
        color: el.bgColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ElThemeTokens.radiusCard),
        ),
        border: Border.all(color: el.borderColor, width: 1),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Top bar
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: el.textColorPrimary,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '지금 재생 중',
                    style: TextStyle(
                      color: el.textColorRegular,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '재생 목록',
                    onPressed: () => QueueBottomSheet.show(context),
                    icon: Icon(
                      Icons.queue_music_rounded,
                      color: el.textColorPrimary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Album Art
              LayoutBuilder(
                builder: (context, constraints) {
                  final artSize =
                      (constraints.maxWidth * 0.78).clamp(180.0, 300.0);
                  return TrackArtwork(
                    audioId: track.id,
                    size: artSize,
                    borderRadius: ElThemeTokens.radiusCard,
                    iconSize: 64,
                  );
                },
              ),
              const SizedBox(height: 28),
              // Track Title & Artist
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: el.textColorPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${track.artist} · ${track.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: el.textColorRegular,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              // Seek Bar
              Slider(
                value: currentMs,
                min: 0.0,
                max: maxMs,
                onChanged: (value) {
                  setState(() => _dragValueMs = value);
                },
                onChangeEnd: (value) {
                  handler.seek(Duration(milliseconds: value.round()));
                  setState(() => _dragValueMs = null);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDuration(
                        Duration(milliseconds: currentMs.round()),
                      ),
                      style: TextStyle(
                        color: el.textColorSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      formatDuration(totalDuration),
                      style: TextStyle(
                        color: el.textColorSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: '셔플',
                    onPressed: () {
                      handler.setShuffleMode(
                        isShuffled
                            ? AudioServiceShuffleMode.none
                            : AudioServiceShuffleMode.all,
                      );
                    },
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: isShuffled ? el.primary : el.textColorSecondary,
                    ),
                  ),
                  IconButton(
                    tooltip: '이전 곡',
                    onPressed: handler.skipToPrevious,
                    iconSize: 34,
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: el.textColorPrimary,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: isPlaying ? handler.pause : handler.play,
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 34,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 곡',
                    onPressed: handler.skipToNext,
                    iconSize: 34,
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: el.textColorPrimary,
                    ),
                  ),
                  IconButton(
                    tooltip: _repeatTooltip(repeatMode),
                    onPressed: () {
                      final nextMode = switch (repeatMode) {
                        AudioServiceRepeatMode.none =>
                          AudioServiceRepeatMode.all,
                        AudioServiceRepeatMode.all =>
                          AudioServiceRepeatMode.one,
                        AudioServiceRepeatMode.one ||
                        AudioServiceRepeatMode.group =>
                          AudioServiceRepeatMode.none,
                      };
                      handler.setRepeatMode(nextMode);
                    },
                    icon: Icon(
                      repeatMode == AudioServiceRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: repeatMode == AudioServiceRepeatMode.none
                          ? el.textColorSecondary
                          : el.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stop button (resets to 00:00 and stops foreground service)
              TextButton.icon(
                onPressed: () async {
                  await handler.stop();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: Icon(Icons.stop_rounded, size: 20, color: el.dangerColor),
                label: Text(
                  '종료',
                  style: TextStyle(color: el.dangerColor, fontSize: 13),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  String _repeatTooltip(AudioServiceRepeatMode mode) {
    return switch (mode) {
      AudioServiceRepeatMode.none => '순차 재생',
      AudioServiceRepeatMode.all => '전체 반복',
      AudioServiceRepeatMode.one => '한 곡 반복',
      AudioServiceRepeatMode.group => '그룹 반복',
    };
  }
}
