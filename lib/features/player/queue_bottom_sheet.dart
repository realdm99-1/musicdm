import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/music_track.dart';
import '../../core/theme/el_theme.dart';
import '../tracks/track_artwork.dart';
import 'player_provider.dart';

class QueueBottomSheet extends ConsumerWidget {
  const QueueBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const QueueBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final el = context.el;
    final queue = ref.watch(queueTracksProvider).value ?? const [];
    final currentTrack = ref.watch(currentTrackProvider);
    final handler = ref.read(audioHandlerProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Text(
                    '현재 재생 목록 (${queue.length})',
                    style: TextStyle(
                      color: el.textColorPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: el.textColorRegular),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Text(
                        '재생 목록이 비어 있습니다.',
                        style: TextStyle(color: el.textColorSecondary),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: queue.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final track = queue[index];
                        final isCurrent = currentTrack?.id == track.id;
                        return ListTile(
                          onTap: () => handler.skipToQueueItem(index),
                          tileColor: isCurrent
                              ? el.primary.withValues(alpha: 0.08)
                              : null,
                          leading: TrackArtwork(audioId: track.id, size: 42),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent
                                  ? el.primary
                                  : el.textColorPrimary,
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${track.artist} · ${formatDuration(track.duration)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: el.textColorRegular,
                              fontSize: 12,
                            ),
                          ),
                          trailing: isCurrent
                              ? Icon(
                                  Icons.equalizer_rounded,
                                  color: el.primary,
                                  size: 20,
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
