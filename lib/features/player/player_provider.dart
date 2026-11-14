import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/music_audio_handler.dart';
import '../../core/audio/music_track.dart';

/// Overridden in main.dart with the initialized AudioService handler.
final audioHandlerProvider = Provider<MusicAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main()');
});

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState;
});

final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.mediaItem;
});

final currentTrackProvider = Provider<MusicTrack?>((ref) {
  final item = ref.watch(currentMediaItemProvider).value;
  if (item == null) return null;
  return MusicTrack.fromMediaItem(item);
});

final queueTracksProvider = StreamProvider<List<MusicTrack>>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.queue.map(
    (items) => items
        .map(MusicTrack.fromMediaItem)
        .whereType<MusicTrack>()
        .toList(),
  );
});

final positionProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.durationStream;
});
