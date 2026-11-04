import 'package:sqflite/sqflite.dart';
import '../models/media_library_models.dart';
import 'media_library_database.dart';

/// Repository interface for managing background ingestion tasks.
abstract class TaskQueueRepository {
  Future<int> enqueueTask(int fileId);
  Future<TaskRecord?> getNextPendingTask();
  Future<void> updateTaskStep(int idTask, TaskStep step);
  Future<void> incrementRetry(int idTask);
  Future<void> deleteTask(int idTask);
  Future<int> getPendingCount();
  Future<void> clearAllTasks();
}

/// SQLite-backed persistent implementation of TaskQueueRepository.
class SqliteTaskQueueRepository implements TaskQueueRepository {
  final MediaLibraryDatabase _dbHelper;
  final Database? _injectedDb;

  SqliteTaskQueueRepository({MediaLibraryDatabase? dbHelper, Database? database})
      : _dbHelper = dbHelper ?? MediaLibraryDatabase.instance,
        _injectedDb = database;

  Future<DatabaseExecutor> _getExecutor() async {
    if (_injectedDb != null && _injectedDb.isOpen) return _injectedDb;
    return await _dbHelper.database;
  }

  @override
  Future<int> enqueueTask(int fileId) async {
    final executor = await _getExecutor();
    return await executor.insert('Task', {
      'step': TaskStep.discovered.index,
      'retry_count': 0,
      'file_id': fileId,
    });
  }

  @override
  Future<TaskRecord?> getNextPendingTask() async {
    final executor = await _getExecutor();
    final rows = await executor.query(
      'Task',
      where: 'step != ? AND retry_count < 5',
      whereArgs: [TaskStep.complete.index],
      orderBy: 'id_task ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TaskRecord.fromMap(rows.first);
  }

  @override
  Future<void> updateTaskStep(int idTask, TaskStep step) async {
    final executor = await _getExecutor();
    await executor.update(
      'Task',
      {'step': step.index},
      where: 'id_task = ?',
      whereArgs: [idTask],
    );
  }

  @override
  Future<void> incrementRetry(int idTask) async {
    final executor = await _getExecutor();
    await executor.rawUpdate(
      'UPDATE Task SET retry_count = retry_count + 1 WHERE id_task = ?',
      [idTask],
    );
  }

  @override
  Future<void> deleteTask(int idTask) async {
    final executor = await _getExecutor();
    await executor.delete(
      'Task',
      where: 'id_task = ?',
      whereArgs: [idTask],
    );
  }

  @override
  Future<int> getPendingCount() async {
    final executor = await _getExecutor();
    final result = await executor.rawQuery(
      'SELECT COUNT(*) as count FROM Task WHERE step != ? AND retry_count < 5',
      [TaskStep.complete.index],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> clearAllTasks() async {
    final executor = await _getExecutor();
    await executor.delete('Task');
  }
}
