import 'dart:async';
import 'dart:io';
import '../../../core/models/media_library_models.dart';

/// Interface for multi-folder filesystem watcher service.
abstract class IDirectoryWatcherService {
  Stream<WatcherEvent> get events;
  Set<String> get watchedPaths;
  Future<void> startWatching(List<String> paths);
  Future<void> stopWatching(String path);
  Future<void> stopAll();
  void dispose();
}

/// Helper tracking pending debounced changes for a single file path.
class _PendingChange {
  final String path;
  WatcherChangeType type;
  final DateTime firstSeen;
  DateTime lastSeen;
  final bool isDirectory;
  Timer? timer;

  _PendingChange({
    required this.path,
    required this.type,
    required this.firstSeen,
    required this.lastSeen,
    this.isDirectory = false,
  });
}

/// Production implementation of DirectoryWatcherService with sliding debounce,
/// event coalescing, and buffer overflow recovery.
class DirectoryWatcherService implements IDirectoryWatcherService {
  final Duration debounceDuration;
  final StreamController<WatcherEvent> _eventController =
      StreamController<WatcherEvent>.broadcast();

  final Map<String, StreamSubscription<FileSystemEvent>> _subscriptions = {};
  final Map<String, _PendingChange> _pendingChanges = {};
  final List<_PendingChange> _recentDeletions = [];

  // Rate limiting / overflow tracking
  int _eventsInCurrentSecond = 0;
  DateTime _lastRateCheck = DateTime.now();
  static const int maxEventsPerSecond = 200;

  DirectoryWatcherService({
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  @override
  Stream<WatcherEvent> get events => _eventController.stream;

  @override
  Set<String> get watchedPaths => Set.unmodifiable(_subscriptions.keys);

  @override
  Future<void> startWatching(List<String> paths) async {
    for (final path in paths) {
      if (_subscriptions.containsKey(path)) continue;

      final dir = Directory(path);
      if (!await dir.exists()) continue;

      try {
        final stream = dir.watch(recursive: true);
        final sub = stream.listen(
          (event) => _handleRawFsEvent(dir.path, event),
          onError: (error) {
            // Kernel buffer overflow (e.g. ERROR_NOTIFY_ENUM_DIR / IN_Q_OVERFLOW)
            _emitOverflow(dir.path);
          },
          cancelOnError: false,
        );
        _subscriptions[path] = sub;
      } catch (_) {
        // Fallback for filesystems that do not support recursive watch
        _emitOverflow(dir.path);
      }
    }
  }

  void _handleRawFsEvent(String watchedRoot, FileSystemEvent rawEvent) {
    final now = DateTime.now();

    // 1. Rate limiter check for high I/O burst overflow
    if (now.difference(_lastRateCheck).inSeconds >= 1) {
      _eventsInCurrentSecond = 0;
      _lastRateCheck = now;
    }
    _eventsInCurrentSecond++;

    if (_eventsInCurrentSecond > maxEventsPerSecond) {
      _emitOverflow(watchedRoot);
      return;
    }

    final path = rawEvent.path;
    final isDirectory = rawEvent.isDirectory;

    // Determine initial change type
    WatcherChangeType changeType;
    if (rawEvent is FileSystemCreateEvent) {
      changeType = WatcherChangeType.created;
    } else if (rawEvent is FileSystemModifyEvent) {
      changeType = WatcherChangeType.modified;
    } else if (rawEvent is FileSystemDeleteEvent) {
      changeType = WatcherChangeType.deleted;
    } else if (rawEvent is FileSystemMoveEvent) {
      changeType = WatcherChangeType.moved;
      // Handle rename / move immediately if destination is present
      final dest = rawEvent.destination;
      _eventController.add(WatcherEvent(
        path: path,
        type: WatcherChangeType.moved,
        destinationPath: dest,
        timestamp: now,
        isDirectory: isDirectory,
      ));
      return;
    } else {
      changeType = WatcherChangeType.modified;
    }

    // 2. Coalescing Logic
    if (_pendingChanges.containsKey(path)) {
      final existing = _pendingChanges[path]!;
      existing.timer?.cancel();
      existing.lastSeen = now;

      if (existing.type == WatcherChangeType.created && changeType == WatcherChangeType.deleted) {
        // CREATE + DELETE -> NOOP (temporary download or scratch file)
        _pendingChanges.remove(path);
        return;
      } else if (existing.type == WatcherChangeType.created &&
          changeType == WatcherChangeType.modified) {
        // CREATE + MODIFY -> Keep as CREATED
        existing.type = WatcherChangeType.created;
      } else {
        existing.type = changeType;
      }

      existing.timer = Timer(debounceDuration, () => _flushChange(path));
      return;
    }

    // 3. Move Detection: Check if this CREATE matches a recent DELETE within 300ms
    if (changeType == WatcherChangeType.created) {
      final matchIndex = _recentDeletions.indexWhere((del) =>
          now.difference(del.lastSeen).inMilliseconds <= 300);

      if (matchIndex != -1) {
        final recentDelete = _recentDeletions.removeAt(matchIndex);
        _eventController.add(WatcherEvent(
          path: recentDelete.path,
          type: WatcherChangeType.moved,
          destinationPath: path,
          timestamp: now,
          isDirectory: isDirectory,
        ));
        return;
      }
    }

    // Track new pending change with sliding debounce timer
    final pending = _PendingChange(
      path: path,
      type: changeType,
      firstSeen: now,
      lastSeen: now,
      isDirectory: isDirectory,
    );

    pending.timer = Timer(debounceDuration, () => _flushChange(path));
    _pendingChanges[path] = pending;

    if (changeType == WatcherChangeType.deleted) {
      _recentDeletions.add(pending);
      // Clean up old deletion markers after 1 second
      Timer(const Duration(seconds: 1), () {
        _recentDeletions.remove(pending);
      });
    }
  }

  void _flushChange(String path) {
    final pending = _pendingChanges.remove(path);
    if (pending == null) return;

    if (!_eventController.isClosed) {
      _eventController.add(WatcherEvent(
        path: pending.path,
        type: pending.type,
        timestamp: pending.lastSeen,
        isDirectory: pending.isDirectory,
      ));
    }
  }

  void _emitOverflow(String directoryPath) {
    if (!_eventController.isClosed) {
      _eventController.add(WatcherEvent(
        path: directoryPath,
        type: WatcherChangeType.overflowCatch,
        timestamp: DateTime.now(),
        isDirectory: true,
      ));
    }
  }

  @override
  Future<void> stopWatching(String path) async {
    final sub = _subscriptions.remove(path);
    await sub?.cancel();
  }

  @override
  Future<void> stopAll() async {
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();

    for (final pending in _pendingChanges.values) {
      pending.timer?.cancel();
    }
    _pendingChanges.clear();
    _recentDeletions.clear();
  }

  @override
  void dispose() {
    stopAll();
    if (!_eventController.isClosed) {
      _eventController.close();
    }
  }
}
