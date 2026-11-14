import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/audio/music_track.dart';
import '../../core/database/music_database.dart';
import '../tracks/tracks_provider.dart';

class PlaylistSummary {
  const PlaylistSummary({
    required this.record,
    required this.validTrackCount,
    required this.totalDuration,
  });

  final PlaylistRecord record;
  final int validTrackCount;
  final Duration totalDuration;
}

class ResolvedPlaylistItem {
  const ResolvedPlaylistItem({
    required this.item,
    required this.track,
  });

  final PlaylistItemRecord item;
  final MusicTrack track;
}

MusicTrack? _resolvePlaylistItem(
  PlaylistItemRecord item,
  Map<int, MusicTrack> tracksById,
  Map<String, MusicTrack> tracksByPath,
) {
  final scanned = tracksById[item.audioId] ?? tracksByPath[item.filePath];
  if (scanned != null) return scanned;

  if (!File(item.filePath).existsSync()) return null;

  return MusicTrack(
    id: item.audioId,
    title: item.title.isNotEmpty
        ? item.title
        : p.basenameWithoutExtension(item.filePath),
    artist: item.artist,
    album: p.basename(p.dirname(item.filePath)),
    durationMs: item.durationMs,
    uri: Uri.file(item.filePath).toString(),
    filePath: item.filePath,
  );
}

class PlaylistsNotifier extends AsyncNotifier<List<PlaylistSummary>> {
  @override
  Future<List<PlaylistSummary>> build() async {
    final allTracks = ref.watch(tracksProvider).tracks;
    return _loadSummaries(allTracks);
  }

  Future<List<PlaylistSummary>> _loadSummaries(
    List<MusicTrack> allTracks,
  ) async {
    final db = MusicDatabase.instance;
    final playlists = await db.getPlaylists();

    final tracksById = {for (final t in allTracks) t.id: t};
    final tracksByPath = {for (final t in allTracks) t.filePath: t};

    final summaries = <PlaylistSummary>[];
    for (final pl in playlists) {
      final items = await db.getPlaylistItems(pl.id);
      var count = 0;
      var totalMs = 0;

      for (final item in items) {
        final track = _resolvePlaylistItem(item, tracksById, tracksByPath);
        if (track != null) {
          count++;
          totalMs += track.durationMs;
        }
      }

      summaries.add(
        PlaylistSummary(
          record: pl,
          validTrackCount: count,
          totalDuration: Duration(milliseconds: totalMs),
        ),
      );
    }

    return summaries;
  }

  Future<void> refresh() async {
    final allTracks = ref.read(tracksProvider).tracks;
    state = AsyncData(await _loadSummaries(allTracks));
  }

  Future<int> createPlaylist(String name) async {
    final id = await MusicDatabase.instance.createPlaylist(name);
    await refresh();
    return id;
  }

  Future<void> renamePlaylist(int id, String newName) async {
    await MusicDatabase.instance.renamePlaylist(id, newName);
    await refresh();
  }

  Future<void> deletePlaylist(int id) async {
    await MusicDatabase.instance.deletePlaylist(id);
    await refresh();
  }

  Future<void> addTracks(int playlistId, List<MusicTrack> tracks) async {
    await MusicDatabase.instance.addTracksToPlaylist(
      playlistId,
      tracks
          .map(
            (t) => (
              audioId: t.id,
              filePath: t.filePath,
              title: t.title,
              artist: t.artist,
              durationMs: t.durationMs,
            ),
          )
          .toList(),
    );
    await refresh();
    ref.invalidate(playlistItemsProvider(playlistId));
  }

  Future<void> removeItem(int playlistId, int itemId) async {
    await MusicDatabase.instance.removePlaylistItem(itemId);
    await refresh();
    ref.invalidate(playlistItemsProvider(playlistId));
  }

  Future<void> reorderItems(
    int playlistId,
    List<int> orderedItemIds,
  ) async {
    await MusicDatabase.instance.reorderPlaylistItems(
      playlistId,
      orderedItemIds,
    );
    ref.invalidate(playlistItemsProvider(playlistId));
  }
}

final playlistsProvider =
    AsyncNotifierProvider<PlaylistsNotifier, List<PlaylistSummary>>(
  PlaylistsNotifier.new,
);

final playlistItemsProvider =
    FutureProvider.family<List<ResolvedPlaylistItem>, int>(
  (ref, playlistId) async {
    final allTracks = ref.watch(tracksProvider).tracks;
    final tracksById = {for (final t in allTracks) t.id: t};
    final tracksByPath = {for (final t in allTracks) t.filePath: t};

    final items = await MusicDatabase.instance.getPlaylistItems(playlistId);
    final resolved = <ResolvedPlaylistItem>[];

    for (final item in items) {
      final track = _resolvePlaylistItem(item, tracksById, tracksByPath);
      if (track != null) {
        resolved.add(ResolvedPlaylistItem(item: item, track: track));
      }
    }

    return resolved;
  },
);
