import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/stream_recorder/models/stream_recorder_models.dart';
import 'package:app/features/stream_recorder/data/stream_recorder_controller.dart';

void main() {
  group('Stream Recorder (record.c Parity) - Unit Tests', () {
    test('RecordingConfig initializes with sane defaults', () {
      final config = RecordingConfig();
      expect(config.format, equals(RecordingFormat.auto));
      expect(config.fileNamePrefix, equals('eplayer-record'));
      expect(config.autoAddToLibrary, isTrue);
      expect(config.audioOnly, isFalse);
    });

    test('RecordingConfig serialization and deserialization round-trip', () {
      final config = RecordingConfig(
        outputDirectory: '/custom/captures',
        format: RecordingFormat.ts,
        fileNamePrefix: 'stream-dump',
        autoAddToLibrary: false,
        audioOnly: true,
      );

      final json = config.toJson();
      final restored = RecordingConfig.fromJson(json);

      expect(restored.outputDirectory, equals('/custom/captures'));
      expect(restored.format, equals(RecordingFormat.ts));
      expect(restored.fileNamePrefix, equals('stream-dump'));
      expect(restored.autoAddToLibrary, isFalse);
      expect(restored.audioOnly, isTrue);
    });

    test('RecordingFormat extensions resolution', () {
      expect(RecordingFormat.auto.extensionFor(sourceUrl: 'http://example.com/live.m3u8'), equals('ts'));
      expect(RecordingFormat.auto.extensionFor(sourceUrl: 'http://example.com/video.mp4'), equals('mp4'));
      expect(RecordingFormat.auto.extensionFor(sourceUrl: 'rtsp://stream/live'), equals('ts'));
      expect(RecordingFormat.auto.extensionFor(sourceUrl: ''), equals('mp4'));
      expect(RecordingFormat.ts.extensionFor(), equals('ts'));
      expect(RecordingFormat.mp4.extensionFor(), equals('mp4'));
      expect(RecordingFormat.mkv.extensionFor(), equals('mkv'));
    });

    test('RecordingSession tracks duration and formatted size correctly', () {
      final session = RecordingSession(
        id: 'rec_001',
        filePath: '/tmp/capture.mp4',
        startTime: DateTime.now(),
        duration: const Duration(minutes: 1, seconds: 24),
        byteSize: 14 * 1024 * 1024 + 500 * 1024, // ~14.5 MB
        status: RecordingState.recording,
      );

      expect(session.formattedDuration, equals('01:24'));
      expect(session.formattedSize, contains('14.5 MB'));
    });

    test('StreamRecorderController starts, updates duration, and stops recording cleanly', () async {
      final controller = StreamRecorderController();
      expect(controller.state, equals(RecordingState.idle));
      expect(controller.isRecording, isFalse);

      final destinationPath = await controller.startRecording(
        mediaTitle: 'Test Broadcast Stream',
        sourceUrl: 'https://test.stream/live.m3u8',
        mockDestinationDir: '/mock/videos',
      );

      expect(controller.isRecording, isTrue);
      expect(controller.state, equals(RecordingState.recording));
      expect(controller.currentSession, isNotNull);
      expect(destinationPath, contains('eplayer-record'));
      expect(destinationPath, contains('Test_Broadcast_Stream'));
      expect(destinationPath, endsWith('.ts'));

      // Simulate a duration tick
      controller.tickForTesting(const Duration(seconds: 15), 1024 * 1024 * 2);
      expect(controller.currentSession!.duration.inSeconds, equals(15));
      expect(controller.currentSession!.formattedSize, contains('2.0 MB'));

      final completedSession = await controller.stopRecording();
      expect(controller.isRecording, isFalse);
      expect(controller.state, equals(RecordingState.idle));
      expect(completedSession, isNotNull);
      expect(completedSession!.status, equals(RecordingState.idle));
    });

    test('StreamRecorderController generates timestamped filenames adhering to VLC convention', () {
      final controller = StreamRecorderController();
      final now = DateTime(2026, 11, 16, 17, 55, 30);
      final filename = controller.generateFilename(
        now: now,
        mediaTitle: 'Live News',
        format: RecordingFormat.mp4,
      );

      // VLC parity: vlc-record-YYYY-MM-DD-HHhMMmSSs-title.ext
      expect(filename, equals('eplayer-record-2026-11-16-17h55m30s-Live_News.mp4'));
    });

    test('StreamRecorderController toggleRecording alternates between start and stop', () async {
      final controller = StreamRecorderController();
      expect(controller.isRecording, isFalse);

      await controller.toggleRecording(
        mediaTitle: 'Stream 1',
        mockDestinationDir: '/mock/videos',
      );
      expect(controller.isRecording, isTrue);

      await controller.toggleRecording();
      expect(controller.isRecording, isFalse);
    });
  });
}
