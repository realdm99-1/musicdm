import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/music_track.dart';
import '../../core/theme/el_theme.dart';
import '../player/mini_player.dart';
import '../player/player_provider.dart';
import '../tracks/track_artwork.dart';
import 'playlist_dialogs.dart';
import 'playlists_provider.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.initialName,
  });

  final int playlistId;
  final String initialName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final el = context.el;
    final playlists = ref.watch(playlistsProvider).value ?? const [];
    final currentSummary = playlists
        .where((p) => p.record.id == playlistId)
        .firstOrNull;
    final playlistName = currentSummary?.record.name ?? initialName;

    final itemsAsync = ref.watch(playlistItemsProvider(playlistId));
    final currentTrack = ref.watch(currentTrackProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlistName),
        actions: [
          if (currentSummary != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'rename') {
                  await showRenamePlaylistDialog(
                    context,
                    ref,
                    currentSummary.record,
                  );
                } else if (value == 'delete') {
                  final deleted = await showDeletePlaylistDialog(
                    context,
                    ref,
                    currentSummary.record,
                  );
                  if (deleted && context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('이름 변경')),
                PopupMenuItem(value: 'delete', child: Text('플레이리스트 삭제')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '플레이리스트를 불러오지 못했습니다: $e',
                  style: TextStyle(color: el.dangerColor),
                ),
              ),
              data: (items) {
                final totalDuration = items.fold<Duration>(
                  Duration.zero,
                  (sum, e) => sum + e.track.duration,
                );

                return Column(
                  children: [
                    // Summary & Action Header
                    Container(
                      width: double.infinity,
                      color: el.bgColor,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '총 ${items.length}곡 · ${formatDuration(totalDuration)}',
                                  style: TextStyle(
                                    color: el.textColorRegular,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => showMultiSelectTracksSheet(
                              context,
                              ref,
                              playlistId,
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('곡 추가'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: items.isEmpty
                                ? null
                                : () {
                                    final tracks =
                                        items.map((e) => e.track).toList();
                                    ref
                                        .read(audioHandlerProvider)
                                        .playTracks(tracks, initialIndex: 0);
                                  },
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text('전체 재생'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.music_off_rounded,
                                      size: 48,
                                      color: el.textColorSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '플레이리스트에 곡이 없습니다.',
                                      style: TextStyle(
                                        color: el.textColorPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '상단의 [곡 추가] 버튼을 눌러 MP3 곡을 추가해 보세요.',
                                      style: TextStyle(
                                        color: el.textColorSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: items.length,
                              onReorderItem: (oldIndex, newIndex) async {
                                final updated = [...items];
                                final moved = updated.removeAt(oldIndex);
                                updated.insert(newIndex, moved);
                                await ref
                                    .read(playlistsProvider.notifier)
                                    .reorderItems(
                                      playlistId,
                                      updated.map((e) => e.item.id).toList(),
                                    );
                              },
                              itemBuilder: (context, index) {
                                final resolved = items[index];
                                final track = resolved.track;
                                final isCurrent = currentTrack?.id == track.id;

                                return Column(
                                  key: ValueKey(resolved.item.id),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: isCurrent
                                          ? el.primary.withValues(alpha: 0.08)
                                          : el.bgColor,
                                      child: ListTile(
                                    onTap: () {
                                      final tracks =
                                          items.map((e) => e.track).toList();
                                      ref
                                          .read(audioHandlerProvider)
                                          .playTracks(
                                            tracks,
                                            initialIndex: index,
                                          );
                                    },
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: Icon(
                                              Icons.drag_handle_rounded,
                                              color: el.textColorSecondary,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        TrackArtwork(
                                          audioId: track.id,
                                          size: 42,
                                        ),
                                      ],
                                    ),
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
                                    trailing: IconButton(
                                      tooltip: '플레이리스트에서 제외',
                                      onPressed: () {
                                        ref
                                            .read(playlistsProvider.notifier)
                                            .removeItem(
                                              playlistId,
                                              resolved.item.id,
                                            );
                                      },
                                      icon: Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: el.textColorSecondary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                    ),
                                    const Divider(height: 1),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
