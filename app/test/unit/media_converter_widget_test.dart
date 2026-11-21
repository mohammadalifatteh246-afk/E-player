import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/export/domain/media_converter_service.dart';
import 'package:app/features/export/ui/media_converter_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaConverterSheet UI Widget Tests (VLC sout transcode Parity)', () {
    testWidgets('1. Displays Media Converter Sheet with presets and paths', (tester) async {
      final service = MediaConverterService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaConverterSheet(
              service: service,
              initialSourcePath: 'C:/Movies/Cyberpunk_Action.mkv',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Media Converter & Extractor'), findsOneWidget);
      expect(find.text('C:/Movies/Cyberpunk_Action.mkv'), findsOneWidget);
      expect(find.text('C:/Movies/Cyberpunk_Action_converted.mp3'), findsOneWidget);
      expect(find.byKey(const Key('converter_preset_mp3_320k')), findsOneWidget);
      expect(find.byKey(const Key('converter_start_button')), findsOneWidget);
    });

    testWidgets('2. Switching preset chip updates output extension dynamically', (tester) async {
      final service = MediaConverterService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaConverterSheet(
              service: service,
              initialSourcePath: 'C:/Movies/Concert.mkv',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to MP4 (H.264 / AAC)
      final mp4Chip = find.byKey(const Key('converter_preset_mp4_h264'));
      expect(mp4Chip, findsOneWidget);
      await tester.tap(mp4Chip);
      await tester.pumpAndSettle();

      expect(find.text('C:/Movies/Concert_converted.mp4'), findsOneWidget);

      // Switch to FLAC Lossless
      final flacChip = find.byKey(const Key('converter_preset_flac_lossless'));
      expect(flacChip, findsOneWidget);
      await tester.tap(flacChip);
      await tester.pumpAndSettle();

      expect(find.text('C:/Movies/Concert_converted.flac'), findsOneWidget);
    });

    testWidgets('3. Starting conversion renders active progress bar and readouts', (tester) async {
      final service = MediaConverterService();

      // Custom slow executor to observe active state in UI
      service.customExecutor = (task, onProgress, isCancelled) async {
        onProgress(0.45, 2.8, 12, 15);
        await Future.delayed(const Duration(milliseconds: 50));
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaConverterSheet(
              service: service,
              initialSourcePath: 'Podcast.mkv',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final startButton = find.byKey(const Key('converter_start_button'));
      expect(startButton, findsOneWidget);
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pump();

      expect(find.text('Transcoding... 45%'), findsOneWidget);
      expect(find.text('2.8x'), findsOneWidget);
      expect(find.text('Elapsed: 00:12'), findsOneWidget);
      expect(find.text('ETA: 00:15'), findsOneWidget);
      expect(find.byKey(const Key('converter_cancel_button')), findsOneWidget);

      // Allow pending timer to settle
      await tester.pump(const Duration(milliseconds: 60));
    });

    testWidgets('4. Tapping Cancel button halts in-flight conversion', (tester) async {
      final service = MediaConverterService();

      service.customExecutor = (task, onProgress, isCancelled) async {
        for (int i = 0; i < 20; i++) {
          if (isCancelled()) return;
          await Future.delayed(const Duration(milliseconds: 20));
          if (isCancelled()) return;
          onProgress(0.2, 1.5, 2, 8);
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaConverterSheet(
              service: service,
              initialSourcePath: 'Demo.mkv',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final startButton = find.byKey(const Key('converter_start_button'));
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pump();

      final cancelButton = find.byKey(const Key('converter_cancel_button'));
      expect(cancelButton, findsOneWidget);
      await tester.ensureVisible(cancelButton);
      await tester.tap(cancelButton);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(service.isConverting, isFalse);
    });
  });
}
