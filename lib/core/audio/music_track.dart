import 'package:audio_service/audio_service.dart';

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.uri,
    required this.filePath,
    this.albumId,
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String uri;
  final String filePath;
  final int? albumId;

  Duration get duration => Duration(milliseconds: durationMs);

  MediaItem toMediaItem() {
    return MediaItem(
      id: id.toString(),
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      extras: {
        'audioId': id,
        'uri': uri,
        'filePath': filePath,
        'albumId': albumId,
      },
    );
  }

  static MusicTrack? fromMediaItem(MediaItem item) {
    final extras = item.extras;
    if (extras == null) return null;
    final audioId = extras['audioId'] as int?;
    final uri = extras['uri'] as String?;
    final filePath = extras['filePath'] as String?;
    if (audioId == null || uri == null || filePath == null) return null;
    return MusicTrack(
      id: audioId,
      title: item.title,
      artist: item.artist ?? 'Unknown Artist',
      album: item.album ?? 'Unknown Album',
      durationMs: item.duration?.inMilliseconds ?? 0,
      uri: uri,
      filePath: filePath,
      albumId: extras['albumId'] as int?,
    );
  }
}

String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 864000);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$mm:$ss';
  }
  return '$mm:$ss';
}
