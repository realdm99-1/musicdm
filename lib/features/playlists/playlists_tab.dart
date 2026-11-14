import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/music_track.dart';
import '../../core/theme/el_theme.dart';
import 'playlist_detail_screen.dart';
import 'playlist_dialogs.dart';
import 'playlists_provider.dart';

class PlaylistsTab extends ConsumerWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final el = context.el;
    final playlistsAsync = ref.watch(playlistsProvider);

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: el.bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '내 플레이리스트',
                style: TextStyle(
                  color: el.textColorPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => showCreatePlaylistDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('새 플레이리스트'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: playlistsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                '플레이리스트를 불러오지 못했습니다: $e',
                style: TextStyle(color: el.dangerColor),
              ),
            ),
            data: (playlists) {
              if (playlists.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.library_music_outlined,
                          size: 52,
                          color: el.textColorSecondary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '생성된 플레이리스트가 없습니다.',
                          style: TextStyle(
                            color: el.textColorPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '원하는 곡들을 모아 나만의 플레이리스트를 만들어 보세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: el.textColorSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () =>
                              showCreatePlaylistDialog(context, ref),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('첫 플레이리스트 만들기'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: playlists.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final summary = playlists[index];
                  final record = summary.record;
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlaylistDetailScreen(
                              playlistId: record.id,
                              initialName: record.name,
                            ),
                          ),
                        );
                      },
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: el.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            ElThemeTokens.radiusThumbnail,
                          ),
                          border: Border.all(
                            color: el.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.queue_music_rounded,
                          color: el.primary,
                        ),
                      ),
                      title: Text(
                        record.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: el.textColorPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${summary.validTrackCount}곡 · ${formatDuration(summary.totalDuration)}',
                        style: TextStyle(
                          color: el.textColorRegular,
                          fontSize: 12,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'rename') {
                            await showRenamePlaylistDialog(
                              context,
                              ref,
                              record,
                            );
                          } else if (value == 'delete') {
                            await showDeletePlaylistDialog(
                              context,
                              ref,
                              record,
                            );
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('이름 변경'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('삭제'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
