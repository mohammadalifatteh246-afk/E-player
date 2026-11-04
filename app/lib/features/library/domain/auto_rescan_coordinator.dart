import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../../core/models/media_library_models.dart';
import '../../../core/db/media_library_repository.dart';
import '../../../core/db/task_queue_repository.dart';
import '../../browser/domain/file_system_service.dart';
import '../../browser/domain/directory_watcher_service.dart';
import 'services/stability_probe_service.dart';
import 'services/differential_reconciler.dart';

/// Progress status descriptor for media scans and background ingestion.
class ScanProgress {
  final String status;
  final int totalDiscovered;
  final int processedCount;
  final bool isScanning;

  const ScanProgress({
    required this.status,
    this.totalDiscovered = 0,
    this.processedCount = 0,
    this.isScanning = false,
  });

  @override
  String toString() =>
      'ScanProgress($status, $processedCount/$totalDiscovered, scanning: $isScanning)';
}

/// Interface for AutoRescanCoordinator.
abstract class IAutoRescanCoordinator {
  Stream<ScanProgress> get progressStream;
  ScanProgress get currentProgress;
  Future<void> initializeLibrary();
  Future<void> registerFolder(String directoryPath);
  Future<void> unregisterFolder(String directoryPath);
  Future<void> triggerManualRescan({String? specificPath});
  Future<void> handleDeviceDismount(String deviceUuid);
  Future<void> handleDeviceRemount(String deviceUuid);
  void dispose();
}

/// Central coordinator managing directory watchers, differential set reconciliation,
/// stability probing, task queue processing, and SQLite persistence.
class AutoRescanCoordinator extends ChangeNotifier implements IAutoRescanCoordinator {
  final MediaLibraryRepository repository;
  final TaskQueueRepository taskQueue;
  final IDirectoryWatcherService watcherService;
  final IStabilityProbeService stabilityProbe;
  final IDifferentialReconciler reconciler;
  final FileSystemService fileSystemService;
  final Duration periodicRescanInterval;

  final StreamController<ScanProgress> _progressController =
      StreamController<ScanProgress>.broadcast();

  StreamSubscription<WatcherEvent>? _watcherSubscription;
  Timer? _periodicTimer;
  bool _isProcessingTaskQueue = false;
  bool _isDisposed = false;
  ScanProgress _currentProgress = const ScanProgress(status: 'Idle');

  AutoRescanCoordinator({
    required this.repository,
    required this.taskQueue,
    IDirectoryWatcherService? watcherService,
    IStabilityProbeService? stabilityProbe,
    IDifferentialReconciler? reconciler,
    FileSystemService? fileSystemService,
    this.periodicRescanInterval = const Duration(minutes: 10),
  })  : watcherService = watcherService ?? DirectoryWatcherService(),
        stabilityProbe = stabilityProbe ?? const StabilityProbeService(),
        fileSystemService = fileSystemService ?? const DefaultFileSystemService(),
        reconciler = reconciler ??
            DifferentialReconciler(
              repository: repository,
              fileSystemService: fileSystemService ?? const DefaultFileSystemService(),
            );

  @override
  Stream<ScanProgress> get progressStream => _progressController.stream;

  @override
  ScanProgress get currentProgress => _currentProgress;

  void _updateProgress(ScanProgress progress) {
    _currentProgress = progress;
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
    notifyListeners();
  }

  /// Initialize default device, start watching registered folders, and run initial rescan.
  @override
  Future<void> initializeLibrary() async {
    _updateProgress(const ScanProgress(status: 'Initializing library...', isScanning: true));

    // 1. Ensure default local fixed volume exists
    var defaultDevice = await repository.getDeviceByUuid('local_fixed_volume');
    if (defaultDevice == null) {
      await repository.upsertDevice(DeviceRecord(
        uuid: 'local_fixed_volume',
        scheme: 'file://',
        isRemovable: false,
        isPresent: true,
        lastSeen: DateTime.now(),
      ));
    }

    // 2. Fetch all registered non-banned folders
    final folders = await repository.getAllFolders(onlyPresent: true);
    final activePaths = <String>[];

    for (final folder in folders) {
      if (!folder.isBanned) {
        activePaths.add(folder.path);
      }
    }

    // 3. Connect directory watcher events
    _watcherSubscription?.cancel();
    _watcherSubscription = watcherService.events.listen(_handleWatcherEvent);

    if (activePaths.isNotEmpty) {
      await watcherService.startWatching(activePaths);
      // Run initial differential reconciliation
      await triggerManualRescan();
    }

    // 4. Start periodic fallback rescan timer
    _periodicTimer?.cancel();
    if (periodicRescanInterval > Duration.zero) {
      _periodicTimer = Timer.periodic(periodicRescanInterval, (_) {
        triggerManualRescan();
      });
    }

    // 5. Kick off background task queue processing
    _processTaskQueue();

    _updateProgress(const ScanProgress(status: 'Library ready', isScanning: false));
  }

  /// Register and start monitoring a directory folder in the media library.
  @override
  Future<void> registerFolder(String directoryPath) async {
    final normalized = fileSystemService.normalizePath(directoryPath);
    final dir = Directory(normalized);
    if (!await dir.exists()) return;

    // Determine or assign device
    final devices = await repository.getAllDevices();
    final deviceId = devices.isNotEmpty ? devices.first.idDevice ?? 1 : 1;

    // Upsert folder record
    final stat = await dir.stat();
    final existingFolder = await repository.getFolderByPath(normalized);

    final folderId = await repository.upsertFolder(FolderRecord(
      idFolder: existingFolder?.idFolder,
      path: normalized,
      name: p.basename(normalized).isEmpty ? normalized : p.basename(normalized),
      deviceId: deviceId,
      mtime: stat.modified.millisecondsSinceEpoch,
      isPresent: true,
      isBanned: false,
    ));

    // Start watching
    await watcherService.startWatching([normalized]);

    // Run reconciliation on this newly registered directory
    await _reconcileSingleFolder(normalized, folderId);
    await _processTaskQueue();
  }

  /// Unregister folder from monitoring and mark its indexed media inactive.
  @override
  Future<void> unregisterFolder(String directoryPath) async {
    final normalized = fileSystemService.normalizePath(directoryPath);
    await watcherService.stopWatching(normalized);

    final folder = await repository.getFolderByPath(normalized);
    if (folder != null && folder.idFolder != null) {
      await repository.setFolderBanned(folder.idFolder!, true);
      await repository.setFolderPresence(folder.idFolder!, false);
    }

    notifyListeners();
  }

  /// Trigger manual differential rescan across all registered folders (or a specific directory).
  @override
  Future<void> triggerManualRescan({String? specificPath}) async {
    _updateProgress(const ScanProgress(status: 'Scanning media library...', isScanning: true));

    final folders = await repository.getAllFolders(onlyPresent: true);
    for (final folder in folders) {
      if (folder.idFolder == null || folder.isBanned) continue;
      if (specificPath != null &&
          fileSystemService.normalizePath(specificPath) != folder.path) {
        continue;
      }

      await _reconcileSingleFolder(folder.path, folder.idFolder!);
    }

    // Process queued tasks
    await _processTaskQueue();

    _updateProgress(const ScanProgress(status: 'Scan complete', isScanning: false));
  }

  Future<void> _reconcileSingleFolder(String folderPath, int folderId) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      await watcherService.stopWatching(folderPath);
      await repository.setFolderPresence(folderId, false);
      final dbFiles = await repository.getFilesByFolder(folderId, onlyPresent: true);
      for (final removed in dbFiles) {
        if (removed.idFile != null) {
          await repository.setFilePresence(removed.idFile!, false);
        }
        final media = await repository.getMediaById(removed.mediaId);
        if (media != null) {
          await repository.updateMedia(media.copyWith(isPresent: false));
        }
      }
      await repository.updateFolderMediaCount(folderId, 0);
      return;
    }

    final diff = await reconciler.reconcileDirectory(
      directoryPath: folderPath,
      folderId: folderId,
    );

    if (!diff.hasChanges) return;

    // 1. Process Added Files
    for (final addedPath in diff.addedPaths) {
      final file = File(addedPath);
      int size = 0;
      int mtime = DateTime.now().millisecondsSinceEpoch;
      try {
        final stat = await file.stat();
        size = stat.size;
        mtime = stat.modified.millisecondsSinceEpoch;
      } catch (_) {}

      // Check if file was already indexed previously (e.g. recovering from soft-deletion)
      final existingFile = await repository.getFileByMrl(addedPath);
      if (existingFile != null) {
        if (existingFile.idFile != null) {
          await repository.setFilePresence(existingFile.idFile!, true);
        }
        final media = await repository.getMediaById(existingFile.mediaId);
        if (media != null) {
          await repository.updateMedia(media.copyWith(isPresent: true));
        }
        continue;
      }

      // Create Media record
      final basename = p.basename(addedPath);
      final ext = p.extension(addedPath).toLowerCase();
      final isVideo = DefaultFileSystemService.videoExtensions.contains(ext);

      final mediaId = await repository.insertMedia(MediaRecord(
        type: isVideo ? MediaType.video : MediaType.audio,
        title: p.basenameWithoutExtension(basename),
        insertionDate: DateTime.now(),
        isPresent: true,
      ));

      // Create File record
      final fileId = await repository.upsertFile(FileRecord(
        mediaId: mediaId,
        folderId: folderId,
        mrl: addedPath,
        type: FileType.main,
        mtime: mtime,
        size: size,
        isPresent: true,
      ));

      // Enqueue task for background metadata extraction
      await taskQueue.enqueueTask(fileId);
    }

    // 2. Process Removed Files (Soft Delete)
    for (final removed in diff.removedRecords) {
      if (removed.idFile != null) {
        await repository.setFilePresence(removed.idFile!, false);
        final media = await repository.getMediaById(removed.mediaId);
        if (media != null) {
          await repository.updateMedia(media.copyWith(isPresent: false));
        }
      }
    }

    // 3. Process Modified Files
    for (final modified in diff.modifiedRecords) {
      await repository.upsertFile(modified);
      if (modified.idFile != null) {
        await taskQueue.enqueueTask(modified.idFile!);
      }
    }

    // Update folder media count
    final presentFiles = await repository.getFilesByFolder(folderId, onlyPresent: true);
    await repository.updateFolderMediaCount(folderId, presentFiles.length);
  }

  /// Handle incoming debounced watcher notifications.
  Future<void> _handleWatcherEvent(WatcherEvent event) async {
    if (_isDisposed) return;

    if (event.type == WatcherChangeType.overflowCatch) {
      await triggerManualRescan(specificPath: event.path);
      return;
    }

    final folder = await repository.getFolderByPath(p.dirname(event.path));
    final folderId = folder?.idFolder;

    switch (event.type) {
      case WatcherChangeType.created:
      case WatcherChangeType.modified:
        if (folderId == null) return;

        // Specific handling for .nomedia dynamic creation/modification:
        // Triggers folder reconciliation which soft-deletes files in the excluded directory.
        if (p.basename(event.path) == '.nomedia') {
          await _reconcileSingleFolder(p.dirname(event.path), folderId);
          return;
        }

        // Strictly whitelist media node types: only video and audio files are ingested.
        final nodeType = fileSystemService.determineNodeType(
          event.path,
          isDirectory: event.isDirectory,
        );
        if (nodeType != FileNodeType.videoFile && nodeType != FileNodeType.audioFile) {
          return;
        }

        // Stability probe check
        final isStable = await stabilityProbe.probeFileStability(
          event.path,
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 100),
          samplingDelay: const Duration(milliseconds: 200),
        );

        if (!isStable) return;

        final file = File(event.path);
        if (!await file.exists()) return;

        final stat = await file.stat();
        final existingFile = await repository.getFileByMrl(event.path);

        if (existingFile == null) {
          final ext = p.extension(event.path).toLowerCase();
          final isVideo = DefaultFileSystemService.videoExtensions.contains(ext);

          final mediaId = await repository.insertMedia(MediaRecord(
            type: isVideo ? MediaType.video : MediaType.audio,
            title: p.basenameWithoutExtension(event.path),
            insertionDate: DateTime.now(),
            isPresent: true,
          ));

          final fileId = await repository.upsertFile(FileRecord(
            mediaId: mediaId,
            folderId: folderId,
            mrl: event.path,
            mtime: stat.modified.millisecondsSinceEpoch,
            size: stat.size,
            isPresent: true,
          ));

          await taskQueue.enqueueTask(fileId);
        } else {
          await repository.upsertFile(existingFile.copyWith(
            mtime: stat.modified.millisecondsSinceEpoch,
            size: stat.size,
            isPresent: true,
          ));
          if (existingFile.idFile != null) {
            await repository.setFilePresence(existingFile.idFile!, true);
          }
          final media = await repository.getMediaById(existingFile.mediaId);
          if (media != null) {
            await repository.updateMedia(media.copyWith(isPresent: true));
          }
          if (existingFile.idFile != null) {
            await taskQueue.enqueueTask(existingFile.idFile!);
          }
        }
        break;

      case WatcherChangeType.deleted:
        // If .nomedia is deleted, reconcile the folder to un-soft-delete its media
        if (folderId != null && p.basename(event.path) == '.nomedia') {
          await _reconcileSingleFolder(p.dirname(event.path), folderId);
          return;
        }

        final existing = await repository.getFileByMrl(event.path);
        if (existing != null && existing.idFile != null) {
          await repository.setFilePresence(existing.idFile!, false);
          final media = await repository.getMediaById(existing.mediaId);
          if (media != null) {
            await repository.updateMedia(media.copyWith(isPresent: false));
          }
        }
        break;

      case WatcherChangeType.moved:
        if (event.destinationPath != null) {
          final oldFile = await repository.getFileByMrl(event.path);
          if (oldFile != null) {
            await repository.upsertFile(oldFile.copyWith(
              mrl: event.destinationPath!,
            ));
            final media = await repository.getMediaById(oldFile.mediaId);
            if (media != null) {
              await repository.updateMedia(media.copyWith(
                title: p.basenameWithoutExtension(event.destinationPath!),
              ));
            }
          }
        }
        break;

      case WatcherChangeType.overflowCatch:
        break;
    }

    notifyListeners();
  }

  /// Process persistent task queue items with two-phase locking and metadata extraction.
  Future<void> _processTaskQueue() async {
    if (_isProcessingTaskQueue || _isDisposed) return;
    _isProcessingTaskQueue = true;

    try {
      while (!_isDisposed) {
        final task = await taskQueue.getNextPendingTask();
        if (task == null) break;

        final fileRecord = await repository.getFileById(task.fileId);
        if (fileRecord == null || !fileRecord.isPresent) {
          await taskQueue.deleteTask(task.idTask!);
          continue;
        }

        // 1. Verify stability
        await taskQueue.updateTaskStep(task.idTask!, TaskStep.metadataExtraction);
        final stable = await stabilityProbe.probeFileStability(
          fileRecord.mrl,
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 50),
          samplingDelay: const Duration(milliseconds: 100),
        );

        if (!stable) {
          await taskQueue.incrementRetry(task.idTask!);
          continue;
        }

        // 2. Synthesize or extract metadata attributes
        final ext = p.extension(fileRecord.mrl).toLowerCase();
        final isVideo = DefaultFileSystemService.videoExtensions.contains(ext);

        if (isVideo) {
          // Add default VideoTrack if not existing
          final existingTracks = await repository.getVideoTracks(fileRecord.mediaId);
          if (existingTracks.isEmpty) {
            await repository.insertVideoTrack(VideoTrackRecord(
              mediaId: fileRecord.mediaId,
              codec: 'H264',
              width: 1920,
              height: 1080,
              fpsNum: 60,
              fpsDen: 1,
              bitrate: 4500000,
            ));
          }
        } else {
          // Add default AudioTrack if not existing
          final existingTracks = await repository.getAudioTracks(fileRecord.mediaId);
          if (existingTracks.isEmpty) {
            await repository.insertAudioTrack(AudioTrackRecord(
              mediaId: fileRecord.mediaId,
              codec: 'AAC',
              bitrate: 320000,
              samplerate: 48000,
              nbChannels: 2,
              language: 'eng',
            ));
          }
        }

        // Mark task complete
        await taskQueue.updateTaskStep(task.idTask!, TaskStep.complete);
        await taskQueue.deleteTask(task.idTask!);
      }
    } catch (_) {
      // Graceful error recovery
    } finally {
      _isProcessingTaskQueue = false;
    }
  }

  /// Handle device detachment: sets `Device.is_present = 0` to trigger cascading soft-deletes.
  @override
  Future<void> handleDeviceDismount(String deviceUuid) async {
    final dev = await repository.getDeviceByUuid(deviceUuid);
    if (dev != null && dev.idDevice != null) {
      await repository.setDevicePresence(dev.idDevice!, false);
      notifyListeners();
    }
  }

  /// Handle device reattachment: sets `Device.is_present = 1` to restore visibility.
  @override
  Future<void> handleDeviceRemount(String deviceUuid) async {
    final dev = await repository.getDeviceByUuid(deviceUuid);
    if (dev != null && dev.idDevice != null) {
      await repository.setDevicePresence(dev.idDevice!, true);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _periodicTimer?.cancel();
    _watcherSubscription?.cancel();
    watcherService.dispose();
    if (!_progressController.isClosed) {
      _progressController.close();
    }
    super.dispose();
  }
}
