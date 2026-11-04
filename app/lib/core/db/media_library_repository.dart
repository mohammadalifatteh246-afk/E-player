import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/media_library_models.dart';
import 'media_library_database.dart';

/// Repository interface providing CRUD, search, pagination, and transactional operations.
abstract class MediaLibraryRepository {
  // Device Operations
  Future<int> upsertDevice(DeviceRecord device);
  Future<DeviceRecord?> getDeviceByUuid(String uuid);
  Future<DeviceRecord?> getDeviceById(int id);
  Future<List<DeviceRecord>> getAllDevices();
  Future<void> setDevicePresence(int deviceId, bool isPresent);

  // Folder Operations
  Future<int> upsertFolder(FolderRecord folder);
  Future<FolderRecord?> getFolderById(int id);
  Future<FolderRecord?> getFolderByPath(String path);
  Future<List<FolderRecord>> getAllFolders({bool onlyPresent = true});
  Future<List<FolderRecord>> getSubFolders(int parentId);
  Future<void> setFolderPresence(int folderId, bool isPresent);
  Future<void> setFolderBanned(int folderId, bool isBanned);
  Future<void> updateFolderMediaCount(int folderId, int count);
  Future<void> deleteFolder(int folderId);

  // Media Operations
  Future<int> insertMedia(MediaRecord media);
  Future<void> updateMedia(MediaRecord media);
  Future<MediaRecord?> getMediaById(int idMedia);
  Future<List<MediaRecord>> getAllMedia({bool onlyPresent = true});
  Future<List<MediaRecord>> getMediaPage({required int page, required int pageSize, bool onlyPresent = true});
  Future<int> getMediaCount({bool onlyPresent = true});
  Future<List<MediaRecord>> searchMedia(String query, {bool onlyPresent = true});
  Future<void> deleteMedia(int idMedia);
  Future<void> setMediaFavorite(int idMedia, bool isFavorite);
  Future<void> updateMediaPlayback(int idMedia, {required int position, required int duration});

  // File Operations
  Future<int> upsertFile(FileRecord file);
  Future<FileRecord?> getFileById(int idFile);
  Future<FileRecord?> getFileByMrl(String mrl);
  Future<List<FileRecord>> getFilesByFolder(int folderId, {bool onlyPresent = true});
  Future<void> deleteFile(int idFile);
  Future<void> setFilePresence(int idFile, bool isPresent);

  // Track Operations
  Future<int> insertVideoTrack(VideoTrackRecord track);
  Future<List<VideoTrackRecord>> getVideoTracks(int mediaId);
  Future<int> insertAudioTrack(AudioTrackRecord track);
  Future<List<AudioTrackRecord>> getAudioTracks(int mediaId);

  // Transactions
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action);
}

/// SQLite-backed implementation of MediaLibraryRepository.
class SqliteMediaLibraryRepository implements MediaLibraryRepository {
  final MediaLibraryDatabase _dbHelper;
  final Database? _injectedDb;

  SqliteMediaLibraryRepository({MediaLibraryDatabase? dbHelper, Database? database})
      : _dbHelper = dbHelper ?? MediaLibraryDatabase.instance,
        _injectedDb = database;

  Future<DatabaseExecutor> _getExecutor([Transaction? txn]) async {
    if (txn != null) return txn;
    if (_injectedDb != null && _injectedDb.isOpen) return _injectedDb;
    return await _dbHelper.database;
  }

  // ==================== DEVICE OPERATIONS ====================

  @override
  Future<int> upsertDevice(DeviceRecord device) async {
    final executor = await _getExecutor();
    final map = device.toMap();
    return await executor.insert(
      'Device',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<DeviceRecord?> getDeviceByUuid(String uuid) async {
    final executor = await _getExecutor();
    final rows = await executor.query(
      'Device',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DeviceRecord.fromMap(rows.first);
  }

  @override
  Future<DeviceRecord?> getDeviceById(int id) async {
    final executor = await _getExecutor();
    final rows = await executor.query(
      'Device',
      where: 'id_device = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DeviceRecord.fromMap(rows.first);
  }

  @override
  Future<List<DeviceRecord>> getAllDevices() async {
    final executor = await _getExecutor();
    final rows = await executor.query('Device', orderBy: 'id_device ASC');
    return rows.map((r) => DeviceRecord.fromMap(r)).toList();
  }

  @override
  Future<void> setDevicePresence(int deviceId, bool isPresent) async {
    final executor = await _getExecutor();
    await executor.update(
      'Device',
      {'is_present': isPresent ? 1 : 0},
      where: 'id_device = ?',
      whereArgs: [deviceId],
    );
  }

  // ==================== FOLDER OPERATIONS ====================

  @override
  Future<int> upsertFolder(FolderRecord folder) async {
    final executor = await _getExecutor();
    final normalizedFolder = folder.copyWith(path: p.normalize(folder.path));
    final map = normalizedFolder.toMap();
    return await executor.insert(
      'Folder',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<FolderRecord?> getFolderById(int id) async {
    final executor = await _getExecutor();
    final rows = await executor.query(
      'Folder',
      where: 'id_folder = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FolderRecord.fromMap(rows.first);
  }

  @override
  Future<FolderRecord?> getFolderByPath(String path) async {
    final executor = await _getExecutor();
    final normalized = p.normalize(path);
    final rows = await executor.query(
      'Folder',
      where: 'path = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FolderRecord.fromMap(rows.first);
  }

  @override
  Future<List<FolderRecord>> getAllFolders({bool onlyPresent = true}) async {
    final executor = await _getExecutor();
    final where = onlyPresent ? 'is_present = 1' : null;
    final rows = await executor.query(
      'Folder',
      where: where,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((r) => FolderRecord.fromMap(r)).toList();
  }

  @override
  Future<List<FolderRecord>> getSubFolders(int parentId) async {
    final executor = await _getExecutor();
    final rows = await executor.query(
      'Folder',
      where: 'parent_id = ? AND is_present = 1',
      whereArgs: [parentId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((r) => FolderRecord.fromMap(r)).toList();
  }

  @override
  Future<void> setFolderPresence(int folderId, bool isPresent) async {
    final executor = await _getExecutor();
    await executor.update(
      'Folder',
      {'is_present': isPresent ? 1 : 0},
      where: 'id_folder = ?',
      whereArgs: [folderId],
    );
  }

  @override
  Future<void> setFolderBanned(int folderId, bool isBanned) async {
    final executor = await _getExecutor();
    await executor.update(
      'Folder',
      {'is_banned': isBanned ? 1 : 0},
      where: 'id_folder = ?',
      whereArgs: [folderId],
    );
  }

  @override
  Future<void> updateFolderMediaCount(int folderId, int count) async {
    final executor = await _getExecutor();
    await executor.update(
      'Folder',
      {'nb_media': count},
      where: 'id_folder = ?',
      whereArgs: [folderId],
    );
  }

  @override
  Future<void> deleteFolder(int folderId) async {
    final executor = await _getExecutor();
    await executor.delete(
      'Folder',
      where: 'id_folder = ?',
      whereArgs: [folderId],
    );
  }

  // ==================== MEDIA OPERATIONS ====================

  @override
  Future<int> insertMedia(MediaRecord media) async {
    final executor = await _getExecutor();
    return await executor.insert('Media', media.toMap());
  }

  @override
  Future<void> updateMedia(MediaRecord media) async {
    if (media.idMedia == null) return;
    final executor = await _getExecutor();
    await executor.update(
      'Media',
      media.toMap(),
      where: 'id_media = ?',
      whereArgs: [media.idMedia],
    );
  }

  @override
  Future<MediaRecord?> getMediaById(int idMedia) async {
    final executor = await _getExecutor();
    final rows = await executor.query(
      'Media',
      where: 'id_media = ?',
      whereArgs: [idMedia],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MediaRecord.fromMap(rows.first);
  }

  @override
  Future<List<MediaRecord>> getAllMedia({bool onlyPresent = true}) async {
    final executor = await _getExecutor();
    final where = onlyPresent ? 'is_present = 1' : null;
    final rows = await executor.query(
      'Media',
      where: where,
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map((r) => MediaRecord.fromMap(r)).toList();
  }

  @override
  Future<List<MediaRecord>> getMediaPage({
    required int page,
    required int pageSize,
    bool onlyPresent = true,
  }) async {
    final executor = await _getExecutor();
    final offset = page * pageSize;
    final where = onlyPresent ? 'is_present = 1' : null;
    final rows = await executor.query(
      'Media',
      where: where,
      orderBy: 'title COLLATE NOCASE ASC',
      limit: pageSize,
      offset: offset,
    );
    return rows.map((r) => MediaRecord.fromMap(r)).toList();
  }

  @override
  Future<int> getMediaCount({bool onlyPresent = true}) async {
    final executor = await _getExecutor();
    final whereClause = onlyPresent ? 'WHERE is_present = 1' : '';
    final result = await executor.rawQuery('SELECT COUNT(*) as count FROM Media $whereClause;');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<List<MediaRecord>> searchMedia(String query, {bool onlyPresent = true}) async {
    final executor = await _getExecutor();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getAllMedia(onlyPresent: onlyPresent);
    }

    // Attempt FTS5 MATCH query first; fallback to LIKE
    try {
      final sanitized = trimmed.replaceAll("'", "''");
      final ftsRows = await executor.rawQuery('''
        SELECT m.* FROM Media m
        JOIN MediaFts fts ON m.id_media = fts.rowid
        WHERE MediaFts MATCH ? ${onlyPresent ? 'AND m.is_present = 1' : ''}
        ORDER BY m.title COLLATE NOCASE ASC;
      ''', ['$sanitized*']);

      if (ftsRows.isNotEmpty) {
        return ftsRows.map((r) => MediaRecord.fromMap(r)).toList();
      }
    } catch (_) {
      // FTS table not available or query syntax mismatch; fallback to LIKE
    }

    final likeRows = await executor.query(
      'Media',
      where: 'title LIKE ? ${onlyPresent ? 'AND is_present = 1' : ''}',
      whereArgs: ['%$trimmed%'],
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return likeRows.map((r) => MediaRecord.fromMap(r)).toList();
  }

  @override
  Future<void> deleteMedia(int idMedia) async {
    final executor = await _getExecutor();
    await executor.delete(
      'Media',
      where: 'id_media = ?',
      whereArgs: [idMedia],
    );
  }

  @override
  Future<void> setMediaFavorite(int idMedia, bool isFavorite) async {
    final executor = await _getExecutor();
    await executor.update(
      'Media',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id_media = ?',
      whereArgs: [idMedia],
    );
  }

  @override
  Future<void> updateMediaPlayback(
    int idMedia, {
    required int position,
    required int duration,
  }) async {
    final executor = await _getExecutor();
    final now = DateTime.now().millisecondsSinceEpoch;
    await executor.rawUpdate('''
      UPDATE Media
      SET last_position = ?,
          duration = CASE WHEN duration <= 0 THEN ? ELSE duration END,
          last_played_date = ?,
          play_count = play_count + 1
      WHERE id_media = ?
    ''', [position, duration, now, idMedia]);
  }

  // ==================== FILE OPERATIONS ====================

  @override
  Future<int> upsertFile(FileRecord file) async {
    final executor = await _getExecutor();
    final normalizedFile = file.copyWith(mrl: p.normalize(file.mrl));
    final map = normalizedFile.toMap();
    return await executor.insert(
      'File',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<FileRecord?> getFileById(int idFile) async {
    final executor = await _getExecutor();
    final rows = await executor.query(
      'File',
      where: 'id_file = ?',
      whereArgs: [idFile],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FileRecord.fromMap(rows.first);
  }

  @override
  Future<FileRecord?> getFileByMrl(String mrl) async {
    final executor = await _getExecutor();
    final normalized = p.normalize(mrl);
    final rows = await executor.query(
      'File',
      where: 'mrl = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FileRecord.fromMap(rows.first);
  }

  @override
  Future<List<FileRecord>> getFilesByFolder(int folderId, {bool onlyPresent = true}) async {
    final executor = await _getExecutor();
    final where = onlyPresent ? 'folder_id = ? AND is_present = 1' : 'folder_id = ?';
    final rows = await executor.query(
      'File',
      where: where,
      whereArgs: [folderId],
      orderBy: 'mrl ASC',
    );
    return rows.map((r) => FileRecord.fromMap(r)).toList();
  }

  @override
  Future<void> deleteFile(int idFile) async {
    final executor = await _getExecutor();
    await executor.delete(
      'File',
      where: 'id_file = ?',
      whereArgs: [idFile],
    );
  }

  @override
  Future<void> setFilePresence(int idFile, bool isPresent) async {
    final executor = await _getExecutor();
    await executor.update(
      'File',
      {'is_present': isPresent ? 1 : 0},
      where: 'id_file = ?',
      whereArgs: [idFile],
    );
  }

  // ==================== TRACK OPERATIONS ====================

  @override
  Future<int> insertVideoTrack(VideoTrackRecord track) async {
    final executor = await _getExecutor();
    return await executor.insert('VideoTrack', track.toMap());
  }

  @override
  Future<List<VideoTrackRecord>> getVideoTracks(int mediaId) async {
    final executor = await _getExecutor();
    final rows = await executor.query(
      'VideoTrack',
      where: 'media_id = ?',
      whereArgs: [mediaId],
      orderBy: 'id_track ASC',
    );
    return rows.map((r) => VideoTrackRecord.fromMap(r)).toList();
  }

  @override
  Future<int> insertAudioTrack(AudioTrackRecord track) async {
    final executor = await _getExecutor();
    return await executor.insert('AudioTrack', track.toMap());
  }

  @override
  Future<List<AudioTrackRecord>> getAudioTracks(int mediaId) async {
    final executor = await _getExecutor();
    final rows = await executor.query(
      'AudioTrack',
      where: 'media_id = ?',
      whereArgs: [mediaId],
      orderBy: 'id_track ASC',
    );
    return rows.map((r) => AudioTrackRecord.fromMap(r)).toList();
  }

  // ==================== TRANSACTIONS ====================

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = _injectedDb ?? await _dbHelper.database;
    return await db.transaction(action);
  }
}
