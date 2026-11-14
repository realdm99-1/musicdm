import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_track.dart';

const _kLastTrackIdKey = 'musicdm_last_track_id';
const _kLastPositionMsKey = 'musicdm_last_position_ms';
const _kLastQueueJsonKey = 'musicdm_last_queue_json';
const _kLastQueueIndexKey = 'musicdm_last_queue_index';

Future<MusicAudioHandler> initAudioService() async {
  final handler = MusicAudioHandler();
  await handler.init();
  return AudioService.init(
    builder: () => handler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.realdm99.musicdm.channel.audio',
      androidNotificationChannelName: 'musicdm Playback',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
      androidResumeOnClick: false,
    ),
  );
}

class MusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _noisySub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<Duration>? _positionSaveSub;
  DateTime _lastSavedTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _playInterrupted = false;
  bool _isStopped = false;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Duration get currentPosition => _player.position;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Automatically pause when Bluetooth/wired headphones are disconnected.
    _noisySub = session.becomingNoisyEventStream.listen((_) {
      pause();
    });

    // Handle audio focus interruptions (e.g., phone calls, other media apps).
    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.35);
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_player.playing) {
              _playInterrupted = true;
              pause();
            }
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
          case AudioInterruptionType.pause:
            if (_playInterrupted) {
              _playInterrupted = false;
              play();
            }
          case AudioInterruptionType.unknown:
            _playInterrupted = false;
        }
      }
    });

    _player.playbackEventStream.listen(_broadcastState);

    _player.currentIndexStream.listen((index) {
      final currentQueue = queue.value;
      if (index != null && index >= 0 && index < currentQueue.length) {
        mediaItem.add(currentQueue[index]);
        _saveLastTrack(currentQueue[index].id, _player.position);
      }
      _broadcastState(_player.playbackEvent);
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });

    // Periodically persist playback position every 3 seconds while playing
    // so abrupt app termination still remembers the last position.
    _positionSaveSub = _player.positionStream.listen((pos) {
      if (!_player.playing || _isStopped) return;
      final now = DateTime.now();
      if (now.difference(_lastSavedTime) < const Duration(seconds: 3)) return;
      _lastSavedTime = now;
      final item = mediaItem.value;
      if (item != null) {
        _saveLastTrack(item.id, pos);
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    if (_isStopped) return;
    final playing = _player.playing;
    final queueIndex = event.currentIndex;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: queueIndex,
        repeatMode: switch (_player.loopMode) {
          LoopMode.off => AudioServiceRepeatMode.none,
          LoopMode.all => AudioServiceRepeatMode.all,
          LoopMode.one => AudioServiceRepeatMode.one,
        },
        shuffleMode: _player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  Future<void> playTracks(
    List<MusicTrack> tracks, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    if (tracks.isEmpty) return;
    _isStopped = false;
    final safeIndex = initialIndex.clamp(0, tracks.length - 1);

    final mediaItems = tracks.map((t) => t.toMediaItem()).toList();
    queue.add(mediaItems);
    mediaItem.add(mediaItems[safeIndex]);

    final sources = tracks.map((track) {
      final parsedUri = Uri.tryParse(track.uri);
      final uri = (parsedUri != null && parsedUri.hasScheme)
          ? parsedUri
          : Uri.file(track.filePath);
      return AudioSource.uri(uri, tag: track.toMediaItem());
    }).toList();

    await _player.setAudioSources(
      sources,
      initialIndex: safeIndex,
      initialPosition: initialPosition,
    );

    await _saveLastQueue(tracks, safeIndex, initialPosition);

    if (autoPlay) {
      await play();
    } else {
      _broadcastState(_player.playbackEvent);
    }
  }

  @override
  Future<void> play() async {
    _isStopped = false;
    final session = await AudioSession.instance;
    if (await session.setActive(true)) {
      _playInterrupted = false;
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    final item = mediaItem.value;
    if (item != null) {
      await _saveLastTrack(item.id, _player.position);
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  @override
  Future<void> onNotificationDeleted() async {
    await stop();
    await SystemNavigator.pop();
  }

  @override
  Future<void> stop() async {
    final lastPos = _player.position;
    final item = mediaItem.value;
    if (item != null) {
      await _saveLastTrack(item.id, lastPos);
    }
    _isStopped = true;
    await _player.stop();
    mediaItem.add(null);
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    final item = mediaItem.value;
    if (item != null) {
      await _saveLastTrack(item.id, position);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (queue.value.isNotEmpty) {
      await _player.seek(Duration.zero, index: 0);
    }
    if (!_player.playing) {
      await play();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (queue.value.isNotEmpty) {
      await _player.seek(Duration.zero, index: queue.value.length - 1);
    }
    if (!_player.playing) {
      await play();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await _player.seek(Duration.zero, index: index);
    await play();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group =>
        LoopMode.all,
    };
    await _player.setLoopMode(loopMode);
    _broadcastState(_player.playbackEvent);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    if (enabled) {
      await _player.shuffle();
    }
    await _player.setShuffleModeEnabled(enabled);
    _broadcastState(_player.playbackEvent);
  }

  Future<void> _saveLastTrack(String trackId, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastTrackIdKey, trackId);
    await prefs.setInt(_kLastPositionMsKey, position.inMilliseconds);
    final idx = _player.currentIndex;
    if (idx != null) {
      await prefs.setInt(_kLastQueueIndexKey, idx);
    }
  }

  Future<void> _saveLastQueue(
    List<MusicTrack> tracks,
    int index,
    Duration position,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      tracks
          .map(
            (t) => {
              'id': t.id,
              'title': t.title,
              'artist': t.artist,
              'album': t.album,
              'durationMs': t.durationMs,
              'uri': t.uri,
              'filePath': t.filePath,
              'albumId': t.albumId,
            },
          )
          .toList(),
    );
    await prefs.setString(_kLastQueueJsonKey, encoded);
    await prefs.setInt(_kLastQueueIndexKey, index);
    await prefs.setInt(_kLastPositionMsKey, position.inMilliseconds);
  }

  Future<void> restoreLastSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawQueue = prefs.getString(_kLastQueueJsonKey);
    if (rawQueue == null || rawQueue.isEmpty) return;

    try {
      final decoded = jsonDecode(rawQueue) as List<dynamic>;
      final savedTracks = <MusicTrack>[];
      for (final item in decoded) {
        final map = item as Map<String, dynamic>;
        final filePath = map['filePath'] as String? ?? '';
        final uri = map['uri'] as String? ?? '';
        final isContentUri = uri.startsWith('content://');
        if (!isContentUri &&
            (filePath.isEmpty || !File(filePath).existsSync())) {
          continue;
        }
        savedTracks.add(
          MusicTrack(
            id: map['id'] as int,
            title: map['title'] as String? ?? '',
            artist: map['artist'] as String? ?? 'Unknown Artist',
            album: map['album'] as String? ?? 'Unknown Album',
            durationMs: map['durationMs'] as int? ?? 0,
            uri: uri.isNotEmpty ? uri : Uri.file(filePath).toString(),
            filePath: filePath,
            albumId: map['albumId'] as int?,
          ),
        );
      }
      if (savedTracks.isEmpty) return;

      final savedIndex =
          (prefs.getInt(_kLastQueueIndexKey) ?? 0).clamp(0, savedTracks.length - 1);
      final savedPosMs = prefs.getInt(_kLastPositionMsKey) ?? 0;

      await playTracks(
        savedTracks,
        initialIndex: savedIndex,
        initialPosition: Duration(milliseconds: savedPosMs),
        autoPlay: false,
      );
    } catch (_) {
      // Ignore corrupted session cache
    }
  }

  Future<({int? trackId, Duration position})> loadLastTrackState() async {
    final prefs = await SharedPreferences.getInstance();
    final idStr = prefs.getString(_kLastTrackIdKey);
    final posMs = prefs.getInt(_kLastPositionMsKey) ?? 0;
    return (
      trackId: idStr != null ? int.tryParse(idStr) : null,
      position: Duration(milliseconds: posMs),
    );
  }

  Future<void> disposeHandler() async {
    await _noisySub?.cancel();
    await _interruptionSub?.cancel();
    await _positionSaveSub?.cancel();
    await _player.dispose();
  }
}
