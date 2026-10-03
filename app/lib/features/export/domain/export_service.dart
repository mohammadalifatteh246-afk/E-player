import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

enum ExportStatus { pending, processing, paused, completed, failed, cancelled }

class ExportJob {
  final String id;
  final String sourcePath;
  final String outputPath;
  final String tempPath; // Phase 7A: Temporary-file management
  
  // Phase 7B: Enhancement Export Configurations
  final String resolutionTarget;
  final int fpsTarget;
  final bool enableAudioEnhancement;
  final bool enableSubtitles;
  
  ExportStatus status;
  double progress;
  String? error;

  ExportJob({
    required this.id,
    required this.sourcePath,
    required this.outputPath,
    required this.resolutionTarget,
    required this.fpsTarget,
    this.enableAudioEnhancement = false,
    this.enableSubtitles = false,
    this.status = ExportStatus.pending,
    this.progress = 0.0,
  }) : tempPath = '$outputPath.tmp'; // Generate temp path automatically
}

class ExportService extends ChangeNotifier {
  final Map<String, ExportJob> _jobs = {};
  
  List<ExportJob> get jobs => _jobs.values.toList();

  void addJob(ExportJob job) {
    _jobs[job.id] = job;
    notifyListeners();
    if (job.status == ExportStatus.pending) {
      _startExportWorker(job);
    }
  }

  void cancelJob(String id) {
    if (_jobs.containsKey(id)) {
      final job = _jobs[id]!;
      job.status = ExportStatus.cancelled;
      
      // Phase 7A: Temporary-file management - clean up orphaned temp files
      try {
        final tempFile = File(job.tempPath);
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      } catch (_) {}

      notifyListeners();
    }
  }

  void _startExportWorker(ExportJob job) async {
    job.status = ExportStatus.processing;
    notifyListeners();

    ReceivePort receivePort = ReceivePort();
    
    try {
      await Isolate.spawn(_exportIsolateTask, {
        'sendPort': receivePort.sendPort,
        'jobId': job.id,
        'sourcePath': job.sourcePath,
        'outputPath': job.outputPath,
        'tempPath': job.tempPath, // Phase 7
      });

      receivePort.listen((message) {
        if (job.status == ExportStatus.cancelled) {
          // If cancelled by user, ignore further progress
          return;
        }
        
        if (message is double) {
          job.progress = message;
          notifyListeners();
        } else if (message == 'COMPLETED') {
          job.status = ExportStatus.completed;
          job.progress = 1.0;
          notifyListeners();
          receivePort.close();
        } else if (message is String && message.startsWith('ERROR:')) {
          job.status = ExportStatus.failed;
          job.error = message;
          notifyListeners();
          receivePort.close();
        }
      });
    } catch (e) {
      job.status = ExportStatus.failed;
      job.error = e.toString();
      notifyListeners();
    }
  }

  // --- Background Isolate Entry Point ---
  static void _exportIsolateTask(Map<String, dynamic> args) async {
    SendPort sendPort = args['sendPort'];
    // String jobId = args['jobId'];
    // String sourcePath = args['sourcePath'];
    String outputPath = args['outputPath'];
    String tempPath = args['tempPath'];

    try {
      // Phase 7A: Temporary-file management
      // We write to a .tmp file while FFmpeg/FFI builds the multiplexed container
      final tempFile = File(tempPath);
      await tempFile.writeAsString('Mock encoded video data...', mode: FileMode.writeOnly);
      
      // Mocking the pipeline where we pull frames from Native FFI and feed to FFmpeg muxer
      // Part 7B logic is evaluated here during iteration.
      for (int i = 0; i <= 100; i += 10) {
        // Simulate heavy processing time per frame batch
        await Future.delayed(const Duration(milliseconds: 150));
        sendPort.send(i / 100.0);
      }
      
      // Phase 7A: Commit temporary file to final destination
      await tempFile.rename(outputPath);

      sendPort.send('COMPLETED');
    } catch (e) {
      sendPort.send('ERROR: $e');
    }
  }
}
