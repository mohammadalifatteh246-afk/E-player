import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/media_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('media_library.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const boolType = 'BOOLEAN NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE media_items (
  _id $idType,
  path $textType UNIQUE,
  name $textType,
  parentFolder $textType,
  sizeBytes $integerType,
  durationMs $integerType,
  lastPositionMs $integerType,
  lastPlayed $integerType,
  isFavorite $boolType
)
''');
  }

  Future<void> insertOrUpdateItem(MediaItem item) async {
    final db = await instance.database;
    await db.insert(
      'media_items',
      _toMap(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertBatch(List<MediaItem> items) async {
    final db = await instance.database;
    Batch batch = db.batch();
    for (var item in items) {
      batch.insert(
        'media_items',
        _toMap(item),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<MediaItem>> getAllItems() async {
    final db = await instance.database;
    final orderBy = 'name ASC';
    final result = await db.query('media_items', orderBy: orderBy);
    return result.map((json) => _fromMap(json)).toList();
  }
  
  Future<List<MediaItem>> getItemsByFolder(String folder) async {
    final db = await instance.database;
    final result = await db.query('media_items', where: 'parentFolder = ?', whereArgs: [folder], orderBy: 'name ASC');
    return result.map((json) => _fromMap(json)).toList();
  }

  Future<void> deleteItem(String path) async {
    final db = await instance.database;
    await db.delete(
      'media_items',
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  Map<String, Object?> _toMap(MediaItem item) {
    return {
      'path': item.path,
      'name': item.name,
      'parentFolder': item.parentFolder,
      'sizeBytes': item.sizeBytes,
      'durationMs': item.durationMs,
      'lastPositionMs': item.lastPositionMs,
      'lastPlayed': item.lastPlayed.millisecondsSinceEpoch,
      'isFavorite': item.isFavorite ? 1 : 0,
    };
  }

  MediaItem _fromMap(Map<String, Object?> map) {
    return MediaItem(
      path: map['path'] as String,
      name: map['name'] as String,
      parentFolder: map['parentFolder'] as String,
      sizeBytes: map['sizeBytes'] as int,
      durationMs: map['durationMs'] as int,
      lastPositionMs: map['lastPositionMs'] as int,
      lastPlayed: DateTime.fromMillisecondsSinceEpoch(map['lastPlayed'] as int),
      isFavorite: (map['isFavorite'] as int) == 1,
    );
  }
}
