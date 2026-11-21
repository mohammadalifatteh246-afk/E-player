import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/export/domain/media_converter_models.dart';
import 'package:app/features/export/domain/media_converter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Media Converter & Audio Extractor Tests (VLC sout transcode Parity)', () {
    test('1. Built-in presets have correct format and codec configurations', () {
      expect(TranscodePreset.mp3_320k.isAudioOnly, isTrue);
      expect(TranscodePreset.mp3_320k.audioCodec, equals('libmp3lame'));
      expect(TranscodePreset.mp3_320k.audioBitrateKbps, equals(320));

      expect(TranscodePreset.m4a_256k.isAudioOnly, isTrue);
      expect(TranscodePreset.m4a_256k.audioCodec, equals('aac'));
      expect(TranscodePreset.m4a_256k.audioBitrateKbps, equals(256));

      expect(TranscodePreset.mp4H264.isAudioOnly, isFalse);
      expect(TranscodePreset.mp4H264.videoCodec, equals('libx264'));
      expect(TranscodePreset.mp4H264.audioCodec, equals('aac'));

      expect(TranscodePreset.mkvPassthrough.isPassthrough, isTrue);
      expect(TranscodePreset.mkvPassthrough.videoCodec, equals('copy'));
    });

    test('2. Preset serialization round-trip works accurately', () {
      const preset = TranscodePreset.mp3_320k;
      final json = preset.toJson();
      expect(json['id'], equals('mp3_320k'));
      expect(json['format'], equals('mp3'));
      expect(json['audioCodec'], equals('libmp3lame'));
      expect(json['audioBitrateKbps'], equals(320));

      final restored = TranscodePreset.fromJson(json);
      expect(restored.id, equals('mp3_320k'));
      expect(restored.format, equals(TranscodeFormat.mp3));
      expect(restored.audioCodec, equals('libmp3lame'));
      expect(restored.audioBitrateKbps, equals(320));
      expect(restored.isAudioOnly, isTrue);
    });

    test('3. buildFfmpegArguments constructs valid transcode and trim commands', () {
      final service = MediaConverterService();

      // Audio Extraction Command
      final audioArgs = service.buildFfmpegArguments(
        'C:/Videos/concert.mkv',
        'C:/Music/concert.mp3',
        TranscodePreset.mp3_320k,
      );
      expect(audioArgs, equals([
        '-y',
        '-i',
        'C:/Videos/concert.mkv',
        '-vn',
        '-c:a',
        'libmp3lame',
        '-b:a',
        '320k',
        'C:/Music/concert.mp3',
      ]));

      // Lossless Remux Passthrough Command
      final remuxArgs = service.buildFfmpegArguments(
        'C:/Videos/movie.mp4',
        'C:/Videos/movie.mkv',
        TranscodePreset.mkvPassthrough,
      );
      expect(remuxArgs, equals([
        '-y',
        '-i',
        'C:/Videos/movie.mp4',
        '-c',
        'copy',
        'C:/Videos/movie.mkv',
      ]));

      // Trimming + Video Transcode Command
      final trimmedArgs = service.buildFfmpegArguments(
        'source.mkv',
        'output.mp4',
        TranscodePreset.mp4H264,
        startTime: const Duration(minutes: 1, seconds: 30),
        endTime: const Duration(minutes: 4, seconds: 45),
      );
      expect(trimmedArgs, containsAllInOrder([
        '-y',
        '-ss',
        '00:01:30',
        '-to',
        '00:04:45',
        '-i',
        'source.mkv',
        '-c:v',
        'libx264',
        '-b:v',
        '5000k',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        'output.mp4',
      ]));
    });

    test('4. startConversion runs and reports progress to completion', () async {
      final service = MediaConverterService();

      final task = await service.startConversion(
        sourcePath: 'sample.mkv',
        outputPath: 'sample.mp3',
        preset: TranscodePreset.mp3_320k,
      );

      expect(task.status, equals(TranscodeTaskStatus.completed));
      expect(task.progress, equals(1.0));
      expect(task.progressPercent, equals(100));
      expect(service.history.isNotEmpty, isTrue);
      expect(service.history.first.id, equals(task.id));
    });

    test('5. cancelActiveTask cancels in-flight conversion immediately', () async {
      final service = MediaConverterService();

      // Custom slow executor
      service.customExecutor = (task, onProgress, isCancelled) async {
        for (int i = 0; i < 50; i++) {
          if (isCancelled()) return;
          await Future.delayed(const Duration(milliseconds: 20));
          if (isCancelled()) return;
          onProgress(0.1, 1.0, 1, 9);
        }
      };

      final future = service.startConversion(
        sourcePath: 'long_movie.mkv',
        outputPath: 'long_movie.mp4',
        preset: TranscodePreset.mp4H264,
      );

      await Future.delayed(const Duration(milliseconds: 30));
      expect(service.isConverting, isTrue);

      service.cancelActiveTask();
      final result = await future;

      expect(result.status, equals(TranscodeTaskStatus.cancelled));
      expect(service.isConverting, isFalse);
    });
  });
}
