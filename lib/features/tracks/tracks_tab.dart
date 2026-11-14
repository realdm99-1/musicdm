import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/music_track.dart';
import '../../core/theme/el_theme.dart';
import '../player/player_provider.dart';
import '../playlists/playlist_dialogs.dart';
import 'track_artwork.dart';
import 'tracks_provider.dart';

class TracksTab extends ConsumerWidget {
  const TracksTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final el = context.el;
    final tracksState = ref.watch(tracksProvider);
    final filteredTracks = ref.watch(filteredTracksProvider);
    final currentTrack = ref.watch(currentTrackProvider);
    final query = ref.watch(trackSearchQueryProvider);

    if (tracksState.permission == AudioPermissionState.checking ||
        (tracksState.isLoading && tracksState.tracks.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tracksState.permission == AudioPermissionState.denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 48,
                    color: el.warningColor,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '오디오 접근 권한이 필요합니다',
                    style: TextStyle(
                      color: el.textColorPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '기기에 저장된 MP3 파일을 스캔하고 재생하려면 저장소/오디오 파일 접근 권한을 허용해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: el.textColorRegular,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(tracksProvider.notifier).openSettings(),
                        child: const Text('앱 설정 열기'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () => ref
                            .read(tracksProvider.notifier)
                            .requestPermissionAndScan(),
                        child: const Text('권한 허용하기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (tracksState.errorMessage != null && tracksState.tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: el.dangerColor),
              const SizedBox(height: 12),
              Text(
                tracksState.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: el.textColorRegular),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => ref.read(tracksProvider.notifier).scanTracks(),
                child: const Text('다시 스캔'),
              ),
            ],
          ),
        ),
      );
    }

    if (tracksState.tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note_outlined,
                size: 52,
                color: el.textColorSecondary,
              ),
              const SizedBox(height: 14),
              Text(
                'MP3 음원을 찾을 수 없습니다.',
                style: TextStyle(
                  color: el.textColorPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '기기의 Music 또는 Download 폴더에 .mp3 파일을 넣은 뒤 다시 스캔해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: el.textColorSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(tracksProvider.notifier).scanTracks(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('음원 다시 스캔'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final imported = await ref
                          .read(tracksProvider.notifier)
                          .importMp3Files();
                      if (context.mounted && imported.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${imported.length}곡을 불러왔습니다.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.audio_file_outlined, size: 18),
                    label: const Text('파일 선택'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await ref
                          .read(tracksProvider.notifier)
                          .importMp3Directory();
                      if (!context.mounted || result.dirPath == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.tracks.isEmpty
                                ? '선택한 폴더에 MP3 파일이 없습니다.'
                                : '폴더에서 ${result.tracks.length}곡을 불러왔습니다.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('폴더 선택'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: el.bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                query.isEmpty
                    ? '전체 ${filteredTracks.length}곡'
                    : '검색 결과 ${filteredTracks.length}곡',
                style: TextStyle(
                  color: el.textColorRegular,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '로컬 파일 추가',
                onPressed: () async {
                  final imported =
                      await ref.read(tracksProvider.notifier).importMp3Files();
                  if (context.mounted && imported.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${imported.length}곡을 불러왔습니다.')),
                    );
                  }
                },
                icon: Icon(
                  Icons.audio_file_outlined,
                  size: 20,
                  color: el.textColorRegular,
                ),
              ),
              IconButton(
                tooltip: '로컬 폴더 추가',
                onPressed: () async {
                  final result = await ref
                      .read(tracksProvider.notifier)
                      .importMp3Directory();
                  if (!context.mounted || result.dirPath == null) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.tracks.isEmpty
                            ? '선택한 폴더에 MP3 파일이 없습니다.'
                            : '폴더에서 ${result.tracks.length}곡을 불러왔습니다.',
                      ),
                    ),
                  );
                },
                icon: Icon(
                  Icons.create_new_folder_outlined,
                  size: 20,
                  color: el.textColorRegular,
                ),
              ),
              TextButton.icon(
                onPressed: filteredTracks.isEmpty
                    ? null
                    : () {
                        ref
                            .read(audioHandlerProvider)
                            .playTracks(filteredTracks, initialIndex: 0);
                      },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('전체 재생'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filteredTracks.isEmpty
              ? Center(
                  child: Text(
                    '"$query"에 대한 검색 결과가 없습니다.',
                    style: TextStyle(color: el.textColorSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(tracksProvider.notifier).scanTracks(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: filteredTracks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final track = filteredTracks[index];
                      final isCurrent = currentTrack?.id == track.id;

                      return Material(
                        color: isCurrent
                            ? el.primary.withValues(alpha: 0.08)
                            : el.bgColor,
                        child: ListTile(
                          onTap: () {
                            ref.read(audioHandlerProvider).playTracks(
                                  filteredTracks,
                                  initialIndex: index,
                                );
                          },
                          leading: TrackArtwork(audioId: track.id, size: 44),
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
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'play') {
                                ref.read(audioHandlerProvider).playTracks(
                                      filteredTracks,
                                      initialIndex: index,
                                    );
                              } else if (value == 'add_to_playlist') {
                                showAddToPlaylistSheet(context, ref, track);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'play',
                                child: Text('지금 재생'),
                              ),
                              PopupMenuItem(
                                value: 'add_to_playlist',
                                child: Text('플레이리스트에 추가'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
