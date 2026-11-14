import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class PlaylistRecord {
  const PlaylistRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    this.trackCount = 0,
  });

  final int id;
  final String name;
  final int createdAt;
  final int trackCount;

  factory PlaylistRecord.fromMap(Map<String, Object?> map) {
    return PlaylistRecord(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: map['created_at'] as int,
      trackCount: (map['track_count'] as int?) ?? 0,
    );
  }
}

class PlaylistItemRecord {
  const PlaylistItemRecord({
    required this.id,
    required this.playlistId,
    required this.audioId,
    required this.filePath,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.sortOrder,
  });

  final int id;
  final int playlistId;
  final int audioId;
  final String filePath;
  final String title;
  final String artist;
  final int durationMs;
  final int sortOrder;

  factory PlaylistItemRecord.fromMap(Map<String, Object?> map) {
    final filePath = map['file_path'] as String;
    final rawTitle = (map['title'] as String?) ?? '';
    return PlaylistItemRecord(
      id: map['id'] as int,
      playlistId: map['playlist_id'] as int,
      audioId: map['audio_id'] as int,
      filePath: filePath,
      title: rawTitle.isNotEmpty
          ? rawTitle
          : p.basenameWithoutExtension(filePath),
      artist: (map['artist'] as String?) ?? 'Unknown Artist',
      durationMs: (map['duration_ms'] as int?) ?? 0,
      sortOrder: map['sort_order'] as int,
    );
  }
}

class DuplicatePlaylistNameException implements Exception {
  const DuplicatePlaylistNameException(this.name);
  final String name;

  @override
  String toString() => '이미 "$name" 플레이리스트가 존재합니다.';
}

class MusicDatabase {
  MusicDatabase._();
  static final MusicDatabase instance = MusicDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'musicdm.db');

    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE playlist_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            playlist_id INTEGER NOT NULL,
            audio_id INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            artist TEXT NOT NULL DEFAULT 'Unknown Artist',
            duration_ms INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL,
            FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_playlist_items_playlist_sort
          ON playlist_items (playlist_id, sort_order)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE playlist_items ADD COLUMN title TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE playlist_items ADD COLUMN artist TEXT NOT NULL DEFAULT 'Unknown Artist'",
          );
          await db.execute(
            'ALTER TABLE playlist_items ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  Future<List<PlaylistRecord>> getPlaylists() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.created_at,
        COUNT(pi.id) AS track_count
      FROM playlists p
      LEFT JOIN playlist_items pi ON pi.playlist_id = p.id
      GROUP BY p.id
      ORDER BY p.created_at DESC
    ''');
    return rows.map(PlaylistRecord.fromMap).toList();
  }

  Future<int> createPlaylist(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError('플레이리스트 이름을 입력해 주세요.');
    }

    final db = await database;
    final existing = await db.query(
      'playlists',
      columns: ['id'],
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw DuplicatePlaylistNameException(name);
    }

    return db.insert('playlists', {
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> renamePlaylist(int playlistId, String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError('플레이리스트 이름을 입력해 주세요.');
    }

    final db = await database;
    final existing = await db.query(
      'playlists',
      columns: ['id'],
      where: 'LOWER(name) = LOWER(?) AND id != ?',
      whereArgs: [name, playlistId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw DuplicatePlaylistNameException(name);
    }

    await db.update(
      'playlists',
      {'name': name},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  /// Deletes playlist record and its items via ON DELETE CASCADE.
  /// Never touches actual MP3 files on device storage.
  Future<void> deletePlaylist(int playlistId) async {
    final db = await database;
    await db.delete(
      'playlists',
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<List<PlaylistItemRecord>> getPlaylistItems(int playlistId) async {
    final db = await database;
    final rows = await db.query(
      'playlist_items',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(PlaylistItemRecord.fromMap).toList();
  }

  Future<void> addTracksToPlaylist(
    int playlistId,
    List<
        ({
          int audioId,
          String filePath,
          String title,
          String artist,
          int durationMs,
        })> tracks,
  ) async {
    if (tracks.isEmpty) return;
    final db = await database;

    await db.transaction((txn) async {
      final maxOrderRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM playlist_items WHERE playlist_id = ?',
        [playlistId],
      );
      var nextOrder = (maxOrderRows.first['max_order'] as int? ?? -1) + 1;

      final existingRows = await txn.query(
        'playlist_items',
        columns: ['audio_id', 'file_path'],
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      final existingIds = existingRows.map((r) => r['audio_id'] as int).toSet();
      final existingPaths =
          existingRows.map((r) => r['file_path'] as String).toSet();

      for (final track in tracks) {
        if (existingIds.contains(track.audioId) ||
            existingPaths.contains(track.filePath)) {
          continue;
        }
        existingIds.add(track.audioId);
        existingPaths.add(track.filePath);
        await txn.insert('playlist_items', {
          'playlist_id': playlistId,
          'audio_id': track.audioId,
          'file_path': track.filePath,
          'title': track.title,
          'artist': track.artist,
          'duration_ms': track.durationMs,
          'sort_order': nextOrder++,
        });
      }
    });
  }

  Future<void> removePlaylistItem(int itemId) async {
    final db = await database;
    await db.delete(
      'playlist_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> reorderPlaylistItems(
    int playlistId,
    List<int> orderedItemIds,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedItemIds.length; i++) {
        await txn.update(
          'playlist_items',
          {'sort_order': i},
          where: 'id = ? AND playlist_id = ?',
          whereArgs: [orderedItemIds[i], playlistId],
        );
      }
    });
  }
}
