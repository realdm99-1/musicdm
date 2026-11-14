import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../core/audio/music_track.dart';
import '../../core/database/music_database.dart';
import '../../core/theme/el_theme.dart';
import '../tracks/track_artwork.dart';
import '../tracks/tracks_provider.dart';
import 'playlists_provider.dart';

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.title,
    required this.hintText,
    required this.confirmLabel,
    required this.onSubmit,
    this.initialText = '',
  });

  final String title;
  final String hintText;
  final String confirmLabel;
  final String initialText;
  final Future<void> Function(String name) onSubmit;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await widget.onSubmit(_controller.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText =
              e.toString().replaceFirst('Invalid argument(s): ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final el = context.el;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hintText,
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            '취소',
            style: TextStyle(color: el.textColorRegular),
          ),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

Future<int?> showCreatePlaylistDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return _PlaylistNameDialog(
        title: '새 플레이리스트',
        hintText: '플레이리스트 이름을 입력하세요',
        confirmLabel: '생성',
        onSubmit: (name) async {
          final id =
              await ref.read(playlistsProvider.notifier).createPlaylist(name);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop(id);
          }
        },
      );
    },
  );
}

Future<void> showRenamePlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  PlaylistRecord playlist,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _PlaylistNameDialog(
        title: '플레이리스트 이름 변경',
        hintText: '새 이름을 입력하세요',
        confirmLabel: '저장',
        initialText: playlist.name,
        onSubmit: (name) async {
          await ref
              .read(playlistsProvider.notifier)
              .renamePlaylist(playlist.id, name);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        },
      );
    },
  );
}

Future<bool> showDeletePlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  PlaylistRecord playlist,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final el = dialogContext.el;
      return AlertDialog(
        title: const Text('플레이리스트 삭제'),
        content: Text(
          '"${playlist.name}" 플레이리스트를 삭제하시겠습니까?\n'
          '기기에 저장된 실제 MP3 파일은 삭제되지 않습니다.',
          style: TextStyle(color: el.textColorRegular, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '취소',
              style: TextStyle(color: el.textColorRegular),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: el.dangerColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      );
    },
  );

  if (confirmed == true) {
    await ref.read(playlistsProvider.notifier).deletePlaylist(playlist.id);
    return true;
  }
  return false;
}

Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  MusicTrack track,
) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, _) {
          final el = context.el;
          final playlistsAsync = ref.watch(playlistsProvider);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '플레이리스트에 추가',
                            style: TextStyle(
                              color: el.textColorPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: el.textColorSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final id = await showCreatePlaylistDialog(context, ref);
                        if (id != null && sheetContext.mounted) {
                          await ref
                              .read(playlistsProvider.notifier)
                              .addTracks(id, [track]);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('플레이리스트에 곡을 추가했습니다.'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('새로 만들기'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: playlistsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('오류: $e'),
                  ),
                  data: (playlists) {
                    if (playlists.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '플레이리스트가 없습니다. "새로 만들기"를 눌러 생성해 주세요.',
                          style: TextStyle(color: el.textColorSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final summary = playlists[index];
                        return ListTile(
                          leading: Icon(
                            Icons.queue_music_rounded,
                            color: el.primary,
                          ),
                          title: Text(
                            summary.record.name,
                            style: TextStyle(color: el.textColorPrimary),
                          ),
                          subtitle: Text(
                            '${summary.validTrackCount}곡',
                            style: TextStyle(
                              color: el.textColorSecondary,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () async {
                            await ref
                                .read(playlistsProvider.notifier)
                                .addTracks(summary.record.id, [track]);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '"${summary.record.name}"에 곡을 추가했습니다.',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _FolderGroup {
  const _FolderGroup({
    required this.dirPath,
    required this.folderName,
    required this.tracks,
  });

  final String dirPath;
  final String folderName;
  final List<MusicTrack> tracks;
}

Future<void> showMultiSelectTracksSheet(
  BuildContext context,
  WidgetRef ref,
  int playlistId,
) async {
  var allTracks = ref.read(tracksProvider).tracks;
  final existingItems =
      await MusicDatabase.instance.getPlaylistItems(playlistId);
  final existingAudioIds = existingItems.map((e) => e.audioId).toSet();
  final selectedIds = <int>{};
  String? activeFolderPath;
  var searchQuery = '';

  List<_FolderGroup> buildFolders(List<MusicTrack> tracks) {
    final folderMap = <String, List<MusicTrack>>{};
    for (final track in tracks) {
      final dirPath = p.dirname(track.filePath);
      folderMap.putIfAbsent(dirPath, () => []).add(track);
    }
    return folderMap.entries.map((entry) {
      final name = p.basename(entry.key);
      return _FolderGroup(
        dirPath: entry.key,
        folderName: name.isEmpty ? entry.key : name,
        tracks: entry.value,
      );
    }).toList()
      ..sort(
        (a, b) =>
            a.folderName.toLowerCase().compareTo(b.folderName.toLowerCase()),
      );
  }

  var allFolders = buildFolders(allTracks);

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final el = context.el;
          final q = searchQuery.trim().toLowerCase();

          final tracksToAdd = allTracks
              .where(
                (t) =>
                    selectedIds.contains(t.id) &&
                    !existingAudioIds.contains(t.id),
              )
              .toList();

          final activeFolder = activeFolderPath == null
              ? null
              : allFolders
                  .where((f) => f.dirPath == activeFolderPath)
                  .firstOrNull;

          final visibleFolders = allFolders.where((f) {
            if (q.isEmpty) return true;
            return f.folderName.toLowerCase().contains(q) ||
                f.dirPath.toLowerCase().contains(q);
          }).toList();

          final visibleTracks = (activeFolder != null
                  ? activeFolder.tracks
                  : allTracks)
              .where((t) {
            if (q.isEmpty) return true;
            return t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q);
          }).toList();

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        '곡 추가 (${tracksToAdd.length}곡 선택)',
                        style: TextStyle(
                          color: el.textColorPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(
                          '취소',
                          style: TextStyle(color: el.textColorRegular),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: tracksToAdd.isEmpty
                            ? null
                            : () async {
                                await ref
                                    .read(playlistsProvider.notifier)
                                    .addTracks(playlistId, tracksToAdd);
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                        child: const Text('추가'),
                      ),
                    ],
                  ),
                ),
                // Direct system picker buttons: File & Folder
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final imported = await ref
                                .read(tracksProvider.notifier)
                                .importMp3Files();
                            if (imported.isEmpty) return;
                            setState(() {
                              allTracks = ref.read(tracksProvider).tracks;
                              allFolders = buildFolders(allTracks);
                              activeFolderPath =
                                  p.dirname(imported.first.filePath);
                              for (final t in imported) {
                                if (!existingAudioIds.contains(t.id)) {
                                  selectedIds.add(t.id);
                                }
                              }
                            });
                          },
                          icon: const Icon(Icons.audio_file_outlined, size: 18),
                          label: const Text('파일 선택'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await ref
                                .read(tracksProvider.notifier)
                                .importMp3Directory();
                            if (result.dirPath == null) return;
                            if (result.tracks.isEmpty && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('선택한 폴더에 MP3 파일이 없습니다.'),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              allTracks = ref.read(tracksProvider).tracks;
                              allFolders = buildFolders(allTracks);
                              activeFolderPath = result.dirPath;
                              for (final t in result.tracks) {
                                if (!existingAudioIds.contains(t.id)) {
                                  selectedIds.add(t.id);
                                }
                              }
                            });
                          },
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('폴더 선택'),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: activeFolder == null && q.isEmpty
                          ? '폴더명, 곡 제목 또는 아티스트 검색'
                          : '곡 제목 또는 아티스트 검색',
                      prefixIcon: const Icon(Icons.search, size: 20),
                    ),
                    onChanged: (val) => setState(() => searchQuery = val),
                  ),
                ),
                if (activeFolder != null)
                  Container(
                    width: double.infinity,
                    color: el.bgColorPage,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => activeFolderPath = null),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('폴더 목록'),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            activeFolder.folderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: el.textColorPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: activeFolder == null && q.isEmpty
                      ? (visibleFolders.isEmpty
                          ? Center(
                              child: Text(
                                '상단의 [폴더 선택] 또는 [파일 선택]으로 MP3를 불러와 주세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: el.textColorSecondary),
                              ),
                            )
                          : ListView.separated(
                              itemCount: visibleFolders.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final folder = visibleFolders[index];
                                final addableTracks = folder.tracks
                                    .where(
                                      (t) => !existingAudioIds.contains(t.id),
                                    )
                                    .toList();
                                final allAlreadyIn = addableTracks.isEmpty;
                                final allSelected = !allAlreadyIn &&
                                    addableTracks.every(
                                      (t) => selectedIds.contains(t.id),
                                    );

                                return ListTile(
                                  onTap: () => setState(
                                    () => activeFolderPath = folder.dirPath,
                                  ),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
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
                                      Icons.folder_rounded,
                                      color: el.primary,
                                      size: 22,
                                    ),
                                  ),
                                  title: Text(
                                    folder.folderName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: allAlreadyIn
                                          ? el.textColorSecondary
                                          : el.textColorPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    allAlreadyIn
                                        ? '${folder.tracks.length}곡 · 모두 추가됨'
                                        : '${folder.tracks.length}곡 (추가 가능 ${addableTracks.length}곡)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: el.textColorSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Checkbox(
                                    value: allAlreadyIn || allSelected,
                                    onChanged: allAlreadyIn
                                        ? null
                                        : (checked) {
                                            setState(() {
                                              if (checked == true) {
                                                for (final t in addableTracks) {
                                                  selectedIds.add(t.id);
                                                }
                                              } else {
                                                for (final t in addableTracks) {
                                                  selectedIds.remove(t.id);
                                                }
                                              }
                                            });
                                          },
                                  ),
                                );
                              },
                            ))
                      : (visibleTracks.isEmpty
                          ? Center(
                              child: Text(
                                '추가할 수 있는 곡이 없습니다.',
                                style: TextStyle(color: el.textColorSecondary),
                              ),
                            )
                          : ListView.separated(
                              itemCount: visibleTracks.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final track = visibleTracks[index];
                                final alreadyIn =
                                    existingAudioIds.contains(track.id);
                                final isSelected =
                                    selectedIds.contains(track.id);

                                return CheckboxListTile(
                                  value: alreadyIn || isSelected,
                                  onChanged: alreadyIn
                                      ? null
                                      : (checked) {
                                          setState(() {
                                            if (checked == true) {
                                              selectedIds.add(track.id);
                                            } else {
                                              selectedIds.remove(track.id);
                                            }
                                          });
                                        },
                                  secondary: TrackArtwork(
                                    audioId: track.id,
                                    size: 40,
                                  ),
                                  title: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: alreadyIn
                                          ? el.textColorSecondary
                                          : el.textColorPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    alreadyIn
                                        ? '${track.artist} · 이미 추가됨'
                                        : '${track.artist} · ${formatDuration(track.duration)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: el.textColorSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                );
                              },
                            )),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
