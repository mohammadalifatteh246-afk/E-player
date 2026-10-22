import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/media_info/domain/media_info_service.dart';

void main() {
  group('MediaInfoService & Model Unit Tests', () {
    test('Inspect 4K HDR MKV parses UHD geometry and HDR10 color profile', () async {
      final report = await MediaInfoService.inspectFile(
        'Cyberpunk_Edgerunners_S01E01_4K_HDR.mkv',
        sizeBytes: 8 * 1024 * 1024 * 1024, // 8 GB
        durationMs: 24 * 60 * 1000, // 24 mins
      );

      expect(report.fileName, 'Cyberpunk_Edgerunners_S01E01_4K_HDR.mkv');
      expect(report.containerFormat, contains('Matroska'));
      expect(report.videoTrack.is4K, isTrue);
      expect(report.videoTrack.width, 3840);
      expect(report.videoTrack.height, 2160);
      expect(report.videoTrack.bitDepth, 10);
      expect(report.videoTrack.isHDR, isTrue);
      expect(report.videoTrack.colorPrimaries, 'BT.2020');
      expect(report.videoTrack.codecName, contains('HEVC'));

      expect(report.audioTracks.length, greaterThanOrEqualTo(2));
      expect(report.audioTracks.first.channelCount, 6);
      expect(report.subtitleTracks.length, greaterThanOrEqualTo(2));
    });

    test('Inspect 1080p SDR MP4 parses Full HD geometry and Rec.709 profile', () async {
      final report = await MediaInfoService.inspectFile(
        'Anime_Episode_1080p.mp4',
        sizeBytes: 800 * 1024 * 1024, // 800 MB
        durationMs: 23 * 60 * 1000, // 23 mins
      );

      expect(report.containerFormat, contains('MPEG-4'));
      expect(report.videoTrack.is4K, isFalse);
      expect(report.videoTrack.width, 1920);
      expect(report.videoTrack.height, 1080);
      expect(report.videoTrack.bitDepth, 8);
      expect(report.videoTrack.isHDR, isFalse);
      expect(report.videoTrack.colorPrimaries, 'BT.709');
      expect(report.videoTrack.codecName, contains('AVC'));
    });

    test('MediaTechnicalReport formatted helpers and plaintext NFO export', () async {
      final report = await MediaInfoService.inspectFile(
        'Sample_Movie_4K.mkv',
        sizeBytes: 4 * 1024 * 1024 * 1024,
        durationMs: 90 * 60 * 1000,
      );

      expect(report.formattedFileSize, contains('GB'));
      expect(report.formattedDuration, '01:30:00');

      final plainText = report.toPlainTextReport();
      expect(plainText, contains('E-PLAYER TECHNICAL MEDIA INSPECTOR REPORT'));
      expect(plainText, contains('GENERAL CONTAINER SPECIFICATIONS'));
      expect(plainText, contains('VIDEO STREAM'));
      expect(plainText, contains('AUDIO STREAMS'));
      expect(plainText, contains('SUBTITLE STREAMS'));
      expect(plainText, contains('RENDER PIPELINE & HARDWARE DECODING'));
    });
  });
}
