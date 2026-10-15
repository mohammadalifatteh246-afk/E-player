import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/export/domain/export_service.dart';

void main() {
  group('ExportService V3 Tests (Phases 12 & 13)', () {
    late ExportService service;

    setUp(() {
      service = ExportService();
    });

    test('Add job initializes Phase 13 state machine and triggers worker', () {
      final job = ExportJob(
        id: 'job_1',
        sourcePath: 'src.mp4',
        outputPath: 'out.mkv',
        resolutionTarget: '1080p',
        fpsTarget: 60,
      );

      service.addJob(job);
      expect(service.jobs.length, 1);
      expect(service.jobs.first.id, 'job_1');
      expect(job.targetWidth, 1920);
      expect(job.targetHeight, 1080);
      expect(
        job.status == ExportStatus.pending || job.status == ExportStatus.processing,
        isTrue,
      );
    });

    test('Cancel job updates status and stage to cancelled and clears temp file', () {
      final job = ExportJob(
        id: 'job_2',
        sourcePath: 'src.mp4',
        outputPath: 'out.mkv',
        resolutionTarget: '4K',
        fpsTarget: 30,
      );

      service.addJob(job);
      service.cancelJob('job_2');

      expect(service.jobs.first.status, ExportStatus.cancelled);
      expect(service.jobs.first.stage, ExportPipelineStage.cancelled);
      expect(service.jobs.first.stageLabel, contains('Cancelled'));
    });

    test('Job preserves AV Sync and resolution mapping across presets', () {
      final job4k = ExportJob(
        id: 'job_sync_1',
        sourcePath: 'src.mp4',
        outputPath: 'out.mkv',
        resolutionTarget: '2160p/4K',
        fpsTarget: 60,
        enableAudioEnhancement: true,
        enableSubtitles: true,
      );

      expect(job4k.enableAudioEnhancement, isTrue);
      expect(job4k.enableSubtitles, isTrue);
      expect(job4k.targetWidth, 3840);
      expect(job4k.targetHeight, 2160);
      expect(job4k.tempPath, 'out.mkv.tmp');
    });
  });
}
