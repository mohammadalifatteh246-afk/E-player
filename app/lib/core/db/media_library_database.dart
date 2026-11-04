import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Production SQLite WAL database engine for E-Player Media Library.
///
/// Implements VLC-grade schema, relational integrity, recursive triggers,
/// FTS5 full-text search, and multi-tier presence cascading.
class MediaLibraryDatabase {
  static final MediaLibraryDatabase instance = MediaLibraryDatabase._init();
  static bool _ffiInitialized = false;

  Database? _database;
  String? _customPath;

  MediaLibraryDatabase._init();

  /// Visible for testing to inject custom database paths or in-memory databases.
  MediaLibraryDatabase.withCustomPath(String customPath) : _customPath = customPath;

  /// Ensure FFI factory is initialized on desktop platforms.
  static void ensurePlatformInitialized() {
    if (!_ffiInitialized) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      _ffiInitialized = true;
    }
  }

  /// Active SQLite database connection.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDB(_customPath ?? 'eplayer_media_library.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    ensurePlatformInitialized();

    String path;
    if (filePath == inMemoryDatabasePath || filePath == ':memory:') {
      path = inMemoryDatabasePath;
    } else if (p.isAbsolute(filePath)) {
      path = filePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onConfigure: _configureDatabase,
      onCreate: _createDatabase,
      onOpen: (db) async {
        await migrateLegacyTable(db);
      },
    );
  }

  /// Configure SQLite pragmas for high throughput, referential integrity, and concurrency.
  Future<void> _configureDatabase(Database db) async {
    // 1. Enforce referential integrity and cascading deletions
    await db.execute('PRAGMA foreign_keys = ON;');

    // 2. Enable recursive triggers for multi-tier presence cascading
    await db.execute('PRAGMA recursive_triggers = ON;');

    // 3. Write-Ahead Logging for simultaneous reads and writes without contention
    try {
      await db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {
      // In-memory or special test databases may not support WAL mode
    }

    // 4. Normal synchronous mode: high throughput, zero DB corruption risk on crash
    try {
      await db.execute('PRAGMA synchronous = NORMAL;');
    } catch (_) {}

    // 5. Store temp tables and indexes in RAM
    try {
      await db.execute('PRAGMA temp_store = MEMORY;');
    } catch (_) {}

    // 6. Busy timeout to prevent transient locked table exceptions
    try {
      await db.execute('PRAGMA busy_timeout = 5000;');
    } catch (_) {}
  }

  /// Create full relational schema, indices, triggers, and FTS5 virtual tables.
  Future<void> _createDatabase(Database db, int version) async {
    await db.transaction((txn) async {
      // 1. Device Table
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS Device (
            id_device INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT UNIQUE NOT NULL,
            scheme TEXT NOT NULL,
            is_removable INTEGER NOT NULL DEFAULT 0,
            is_present INTEGER NOT NULL DEFAULT 1,
            last_seen INTEGER NOT NULL DEFAULT 0
        );
      ''');

      // 2. Folder Table
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS Folder (
            id_folder INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            parent_id INTEGER,
            device_id INTEGER NOT NULL,
            mtime INTEGER NOT NULL DEFAULT 0,
            is_present INTEGER NOT NULL DEFAULT 1,
            is_banned INTEGER NOT NULL DEFAULT 0,
            nb_media INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(parent_id) REFERENCES Folder(id_folder) ON DELETE CASCADE,
            FOREIGN KEY(device_id) REFERENCES Device(id_device) ON DELETE CASCADE
        );
      ''');

      // 3. Media Table
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS Media (
            id_media INTEGER PRIMARY KEY AUTOINCREMENT,
            type INTEGER NOT NULL,
            subtype INTEGER NOT NULL DEFAULT 0,
            title TEXT NOT NULL,
            duration INTEGER NOT NULL DEFAULT -1,
            play_count INTEGER NOT NULL DEFAULT 0,
            last_position INTEGER NOT NULL DEFAULT 0,
            last_played_date INTEGER,
            insertion_date INTEGER NOT NULL,
            release_date INTEGER,
            thumbnail TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            is_present INTEGER NOT NULL DEFAULT 1
        );
      ''');

      // 4. File Table
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS File (
            id_file INTEGER PRIMARY KEY AUTOINCREMENT,
            media_id INTEGER NOT NULL,
            folder_id INTEGER,
            mrl TEXT UNIQUE NOT NULL,
            type INTEGER NOT NULL DEFAULT 1,
            mtime INTEGER NOT NULL,
            size INTEGER NOT NULL,
            is_present INTEGER NOT NULL DEFAULT 1,
            is_removable INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(media_id) REFERENCES Media(id_media) ON DELETE CASCADE,
            FOREIGN KEY(folder_id) REFERENCES Folder(id_folder) ON DELETE SET NULL
        );
      ''');

      // 5. Track Metadata Tables
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS VideoTrack (
            id_track INTEGER PRIMARY KEY AUTOINCREMENT,
            media_id INTEGER NOT NULL,
            codec TEXT,
            width INTEGER NOT NULL,
            height INTEGER NOT NULL,
            fps_num INTEGER,
            fps_den INTEGER,
            bitrate INTEGER,
            FOREIGN KEY(media_id) REFERENCES Media(id_media) ON DELETE CASCADE
        );
      ''');

      await txn.execute('''
        CREATE TABLE IF NOT EXISTS AudioTrack (
            id_track INTEGER PRIMARY KEY AUTOINCREMENT,
            media_id INTEGER NOT NULL,
            codec TEXT,
            bitrate INTEGER,
            samplerate INTEGER,
            nb_channels INTEGER,
            language TEXT,
            FOREIGN KEY(media_id) REFERENCES Media(id_media) ON DELETE CASCADE
        );
      ''');

      // 6. Persistent Ingestion Task Table
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS Task (
            id_task INTEGER PRIMARY KEY AUTOINCREMENT,
            step INTEGER NOT NULL DEFAULT 0,
            retry_count INTEGER NOT NULL DEFAULT 0,
            file_id INTEGER NOT NULL,
            FOREIGN KEY(file_id) REFERENCES File(id_file) ON DELETE CASCADE
        );
      ''');

      // 7. High-Performance Indices
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_file_folder ON File(folder_id);');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_file_mrl ON File(mrl);');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_media_type_present ON Media(type, is_present);');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_folder_path ON Folder(path);');
      await txn.execute('CREATE INDEX IF NOT EXISTS idx_task_step ON Task(step);');

      // 8. FTS5 Virtual Search Table
      try {
        await txn.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS MediaFts USING fts5(
              title,
              content='Media',
              content_rowid='id_media'
          );
        ''');

        // 9. FTS Synchronizing Triggers
        await txn.execute('''
          CREATE TRIGGER IF NOT EXISTS trigger_media_ai AFTER INSERT ON Media BEGIN
              INSERT INTO MediaFts(rowid, title) VALUES (new.id_media, new.title);
          END;
        ''');

        await txn.execute('''
          CREATE TRIGGER IF NOT EXISTS trigger_media_ad AFTER DELETE ON Media BEGIN
              INSERT INTO MediaFts(MediaFts, rowid, title) VALUES ('delete', old.id_media, old.title);
          END;
        ''');

        await txn.execute('''
          CREATE TRIGGER IF NOT EXISTS trigger_media_au AFTER UPDATE ON Media BEGIN
              INSERT INTO MediaFts(MediaFts, rowid, title) VALUES ('delete', old.id_media, old.title);
              INSERT INTO MediaFts(rowid, title) VALUES (new.id_media, new.title);
          END;
        ''');
      } catch (_) {
        // FTS5 might not be compiled in some minimal SQLite builds; gracefully skip
      }

      // 10. Presence Cascades (Device Dismount / Remount Trigger)
      await txn.execute('''
        CREATE TRIGGER IF NOT EXISTS trigger_device_presence_update
        AFTER UPDATE OF is_present ON Device
        BEGIN
            UPDATE Folder SET is_present = NEW.is_present WHERE device_id = NEW.id_device;
            UPDATE File SET is_present = NEW.is_present WHERE folder_id IN (
                SELECT id_folder FROM Folder WHERE device_id = NEW.id_device
            );
            UPDATE Media SET is_present = NEW.is_present WHERE id_media IN (
                SELECT media_id FROM File WHERE folder_id IN (
                    SELECT id_folder FROM Folder WHERE device_id = NEW.id_device
                )
            );
        END;
      ''');
    });
  }

  /// Migrate data from the legacy flat `media_items` table if present.
  Future<void> migrateLegacyTable(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='media_items';",
    );
    if (tables.isEmpty) {
      return;
    }

    await db.transaction((txn) async {
      // 1. Ensure default local device exists
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.rawInsert('''
        INSERT OR IGNORE INTO Device (uuid, scheme, is_removable, is_present, last_seen)
        VALUES ('local_fixed_volume', 'file://', 0, 1, ?)
      ''', [now]);

      final devRows = await txn.rawQuery(
        "SELECT id_device FROM Device WHERE uuid = 'local_fixed_volume';",
      );
      final deviceId = devRows.isNotEmpty ? devRows.first['id_device'] as int : 1;

      // 2. Query legacy items
      final legacyRows = await txn.rawQuery('SELECT * FROM media_items');
      for (final row in legacyRows) {
        final path = row['path'] as String?;
        if (path == null || path.isEmpty) continue;

        final name = row['name'] as String? ?? p.basename(path);
        final parentFolder = row['parentFolder'] as String? ?? p.dirname(path);
        final sizeBytes = row['sizeBytes'] as int? ?? 0;
        final durationMs = row['durationMs'] as int? ?? 0;
        final lastPositionMs = row['lastPositionMs'] as int? ?? 0;
        final lastPlayed = row['lastPlayed'] as int? ?? now;
        final isFavorite = (row['isFavorite'] as int? ?? 0) == 1;

        // Upsert Folder
        await txn.rawInsert('''
          INSERT OR IGNORE INTO Folder (path, name, device_id, mtime, is_present)
          VALUES (?, ?, ?, ?, 1)
        ''', [parentFolder, p.basename(parentFolder), deviceId, now]);

        final folderResult = await txn.rawQuery(
          'SELECT id_folder FROM Folder WHERE path = ?',
          [parentFolder],
        );
        final folderId = folderResult.isNotEmpty ? folderResult.first['id_folder'] as int : null;

        // Check if file already migrated
        final existingFile = await txn.rawQuery('SELECT id_file FROM File WHERE mrl = ?', [path]);
        if (existingFile.isNotEmpty) continue;

        // Insert Media
        final mediaId = await txn.rawInsert('''
          INSERT INTO Media (type, title, duration, last_position, last_played_date, insertion_date, is_favorite, is_present)
          VALUES (?, ?, ?, ?, ?, ?, ?, 1)
        ''', [1, name, durationMs, lastPositionMs, lastPlayed, now, isFavorite ? 1 : 0]);

        // Insert File
        await txn.rawInsert('''
          INSERT OR IGNORE INTO File (media_id, folder_id, mrl, type, mtime, size, is_present)
          VALUES (?, ?, ?, 1, ?, ?, 1)
        ''', [mediaId, folderId, path, now, sizeBytes]);
      }
    });
  }

  /// Close active database connection cleanly.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  /// Delete underlying database file.
  Future<void> deleteDatabaseFile() async {
    await close();
    final path = _customPath ?? 'eplayer_media_library.db';
    if (path != inMemoryDatabasePath && path != ':memory:') {
      final fullPath = p.isAbsolute(path) ? path : p.join(await getDatabasesPath(), path);
      final file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
      }
      // Also delete WAL and SHM files
      final walFile = File('$fullPath-wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }
      final shmFile = File('$fullPath-shm');
      if (await shmFile.exists()) {
        await shmFile.delete();
      }
    }
  }
}
