import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/music_track.dart';

const _kImportedPathsKey = 'musicdm_imported_mp3_paths';
final _naturalTokenRegex = RegExp(r'(\d+|\D+)');

/// Compares two file paths by their base filename using natural sort order
/// (e.g. `1.mp3`, `2.mp3`, `10.mp3`).
int compareFileNamesNatural(String pathA, String pathB) {
  final nameA = p.basename(pathA).toLowerCase();
  final nameB = p.basename(pathB).toLowerCase();
  final tokensA = _naturalTokenRegex.allMatches(nameA).map((m) => m.group(0)!).toList();
  final tokensB = _naturalTokenRegex.allMatches(nameB).map((m) => m.group(0)!).toList();
  final len = tokensA.length < tokensB.length ? tokensA.length : tokensB.length;

  for (var i = 0; i < len; i++) {
    final segA = tokensA[i];
    final segB = tokensB[i];
    final numA = int.tryParse(segA);
    final numB = int.tryParse(segB);
    final cmp = (numA != null && numB != null)
        ? numA.compareTo(numB)
        : segA.compareTo(segB);
    if (cmp != 0) return cmp;
  }

  final lenCmp = tokensA.length.compareTo(tokensB.length);
  if (lenCmp != 0) return lenCmp;
  return pathA.toLowerCase().compareTo(pathB.toLowerCase());
}

/// Compares two [MusicTrack] instances by their filename in natural order.
int compareTracksByFileName(MusicTrack a, MusicTrack b) {
  final sourceA = a.filePath.isNotEmpty ? a.filePath : a.title;
  final sourceB = b.filePath.isNotEmpty ? b.filePath : b.title;
  return compareFileNamesNatural(sourceA, sourceB);
}

enum AudioPermissionState {
  checking,
  granted,
  denied,
}

class TracksState {
  const TracksState({
    this.permission = AudioPermissionState.checking,
    this.isLoading = false,
    this.tracks = const [],
    this.errorMessage,
  });

  final AudioPermissionState permission;
  final bool isLoading;
  final List<MusicTrack> tracks;
  final String? errorMessage;

  TracksState copyWith({
    AudioPermissionState? permission,
    bool? isLoading,
    List<MusicTrack>? tracks,
    String? errorMessage,
  }) {
    return TracksState(
      permission: permission ?? this.permission,
      isLoading: isLoading ?? this.isLoading,
      tracks: tracks ?? this.tracks,
      errorMessage: errorMessage,
    );
  }
}

final onAudioQueryProvider = Provider<OnAudioQuery>((ref) => OnAudioQuery());

class TracksNotifier extends Notifier<TracksState> {
  @override
  TracksState build() {
    Future.microtask(initAndScan);
    return const TracksState();
  }

  Future<void> initAndScan() async {
    state = state.copyWith(
      permission: AudioPermissionState.checking,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final audioQuery = ref.read(onAudioQueryProvider);
      var hasPermission = await audioQuery.permissionsStatus();
      if (!hasPermission) {
        hasPermission = await audioQuery.permissionsRequest();
      }

      if (!hasPermission) {
        state = state.copyWith(
          permission: AudioPermissionState.denied,
          isLoading: false,
        );
        return;
      }

      state = state.copyWith(permission: AudioPermissionState.granted);
      await scanTracks();
    } catch (e) {
      state = state.copyWith(
        permission: AudioPermissionState.denied,
        isLoading: false,
        errorMessage: '권한 확인 중 오류가 발생했습니다: $e',
      );
    }
  }

  Future<void> requestPermissionAndScan() async {
    await initAndScan();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  Future<void> scanTracks() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final audioQuery = ref.read(onAudioQueryProvider);
      final songs = await audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final mp3Tracks = <MusicTrack>[];
      final seenPaths = <String>{};

      for (final song in songs) {
        final isMp3 = song.fileExtension.toLowerCase() == 'mp3' ||
            song.data.toLowerCase().endsWith('.mp3');
        if (!isMp3) continue;

        final uri = song.uri;
        if (uri == null || uri.isEmpty) continue;

        final rawTitle = song.title.trim();
        final fileNameFallback = song.displayNameWOExt.trim().isNotEmpty
            ? song.displayNameWOExt.trim()
            : p.basenameWithoutExtension(song.data);
        final title = rawTitle.isNotEmpty ? rawTitle : fileNameFallback;

        final rawArtist = song.artist?.trim() ?? '';
        final artist = (rawArtist.isEmpty ||
                rawArtist.toLowerCase() == '<unknown>' ||
                rawArtist.toLowerCase() == 'unknown')
            ? 'Unknown Artist'
            : rawArtist;

        final rawAlbum = song.album?.trim() ?? '';
        final album = (rawAlbum.isEmpty ||
                rawAlbum.toLowerCase() == '<unknown>' ||
                rawAlbum.toLowerCase() == 'unknown')
            ? 'Unknown Album'
            : rawAlbum;

        seenPaths.add(song.data);
        mp3Tracks.add(
          MusicTrack(
            id: song.id,
            title: title,
            artist: artist,
            album: album,
            durationMs: song.duration ?? 0,
            uri: uri,
            filePath: song.data,
            albumId: song.albumId,
          ),
        );
      }

      // Also merge previously user-imported local MP3 paths that exist on disk.
      final prefs = await SharedPreferences.getInstance();
      final savedPaths = prefs.getStringList(_kImportedPathsKey) ?? const [];
      final validSavedPaths = <String>[];

      for (final filePath in savedPaths) {
        if (!File(filePath).existsSync()) continue;
        validSavedPaths.add(filePath);
        if (seenPaths.contains(filePath)) continue;
        seenPaths.add(filePath);
        mp3Tracks.add(_trackFromLocalPath(filePath));
      }

      if (validSavedPaths.length != savedPaths.length) {
        await prefs.setStringList(_kImportedPathsKey, validSavedPaths);
      }

      state = state.copyWith(
        permission: AudioPermissionState.granted,
        isLoading: false,
        tracks: mp3Tracks,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '음원 스캔 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// Opens the system file picker to select one or more local .mp3 files.
  Future<List<MusicTrack>> importMp3Files() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'MP3 파일 선택',
      type: FileType.custom,
      allowedExtensions: const ['mp3'],
    );
    if (files.isEmpty) return const [];

    final importedEntries = <({String path, String title})>[];
    Directory? permanentDir;

    for (final f in files) {
      final rawPath = f.path;
      if (rawPath == null || rawPath.isEmpty) continue;

      final originalName = f.name.trim().isNotEmpty
          ? f.name.trim()
          : p.basename(rawPath);
      final isMp3 = originalName.toLowerCase().endsWith('.mp3') ||
          rawPath.toLowerCase().endsWith('.mp3');
      if (!isMp3) continue;

      var finalPath = rawPath;
      // android_file_picker often copies SAF files to /cache/<uuid>.mp3.
      // Persist to app documents with the real filename so it is never lost
      // and never displays a UUID.
      if (rawPath.contains('/cache/') || rawPath.contains('\\cache\\')) {
        permanentDir ??= Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'imported_mp3'),
        );
        if (!await permanentDir.exists()) {
          await permanentDir.create(recursive: true);
        }
        final targetFile = File(p.join(permanentDir.path, originalName));
        if (!await targetFile.exists()) {
          await File(rawPath).copy(targetFile.path);
        }
        finalPath = targetFile.path;
      }

      final title = p.basenameWithoutExtension(originalName);
      importedEntries.add((
        path: finalPath,
        title: title.isEmpty ? originalName : title,
      ));
    }

    importedEntries.sort((a, b) => compareFileNamesNatural(a.path, b.path));
    return _mergeLocalEntries(importedEntries);
  }

  /// Opens the system directory picker and scans all .mp3 files inside it.
  Future<({String? dirPath, List<MusicTrack> tracks})>
      importMp3Directory() async {
    final dirPath = await FilePicker.getDirectoryPath(
      dialogTitle: 'MP3 폴더 선택',
    );
    if (dirPath == null || dirPath.isEmpty) {
      return (dirPath: null, tracks: const <MusicTrack>[]);
    }

    final foundPaths = <String>{};

    // Match any tracks already indexed by MediaStore under this directory.
    final normalizedPrefix =
        dirPath.endsWith(Platform.pathSeparator) ? dirPath : '$dirPath/';
    for (final track in state.tracks) {
      if (track.filePath == dirPath ||
          track.filePath.startsWith(normalizedPrefix) ||
          track.filePath.startsWith(dirPath)) {
        foundPaths.add(track.filePath);
      }
    }

    // Also scan the directory directly on disk.
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.mp3')) {
            foundPaths.add(entity.path);
          }
        }
      }
    } catch (_) {
      // Ignore permission errors on restricted subdirectories.
    }

    final entries = foundPaths
        .map(
          (path) => (
            path: path,
            title: p.basenameWithoutExtension(path),
          ),
        )
        .toList()
      ..sort((a, b) => compareFileNamesNatural(a.path, b.path));
    final merged = await _mergeLocalEntries(entries);
    return (dirPath: dirPath, tracks: merged);
  }

  Future<List<MusicTrack>> _mergeLocalEntries(
    List<({String path, String title})> entries,
  ) async {
    if (entries.isEmpty) return const [];

    final existingByPath = {for (final t in state.tracks) t.filePath: t};
    final resultTracks = <MusicTrack>[];
    final updatedList = [...state.tracks];

    final prefs = await SharedPreferences.getInstance();
    final savedPaths =
        (prefs.getStringList(_kImportedPathsKey) ?? const []).toSet();

    for (final entry in entries) {
      final existing = existingByPath[entry.path];
      if (existing != null) {
        resultTracks.add(existing);
      } else {
        final created = _trackFromLocalPath(
          entry.path,
          overrideTitle: entry.title,
        );
        existingByPath[entry.path] = created;
        updatedList.add(created);
        resultTracks.add(created);
        savedPaths.add(entry.path);
      }
    }

    await prefs.setStringList(_kImportedPathsKey, savedPaths.toList());
    state = state.copyWith(tracks: updatedList);
    return resultTracks;
  }

  MusicTrack _trackFromLocalPath(String filePath, {String? overrideTitle}) {
    final fallbackTitle = p.basenameWithoutExtension(filePath);
    final title = (overrideTitle != null && overrideTitle.trim().isNotEmpty)
        ? overrideTitle.trim()
        : (fallbackTitle.isEmpty ? p.basename(filePath) : fallbackTitle);
    // Use a stable negative ID so it never collides with MediaStore positive IDs.
    final stableId = -(filePath.hashCode.abs() + 1);
    return MusicTrack(
      id: stableId,
      title: title,
      artist: 'Unknown Artist',
      album: p.basename(p.dirname(filePath)),
      durationMs: 0,
      uri: Uri.file(filePath).toString(),
      filePath: filePath,
    );
  }
}

final tracksProvider =
    NotifierProvider<TracksNotifier, TracksState>(TracksNotifier.new);

class TrackSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final trackSearchQueryProvider =
    NotifierProvider<TrackSearchQueryNotifier, String>(
  TrackSearchQueryNotifier.new,
);

final filteredTracksProvider = Provider<List<MusicTrack>>((ref) {
  final tracks = ref.watch(tracksProvider).tracks;
  final query = ref.watch(trackSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return tracks;

  return tracks.where((t) {
    return t.title.toLowerCase().contains(query) ||
        t.artist.toLowerCase().contains(query) ||
        t.album.toLowerCase().contains(query);
  }).toList();
});
