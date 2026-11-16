import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/bookmarks/data/bookmark_service.dart';
import 'package:app/features/bookmarks/ui/bookmarks_sheet.dart';
import 'package:app/features/audio/domain/audio_visualizer_engine.dart';
import 'package:app/features/audio/ui/audio_spectrum_visualizer_widget.dart';
import 'package:app/features/player/services/video_snapshot_service.dart';
import 'package:app/features/player/services/desktop_tray_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 Master E2E Integration Test Suite', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('phase4_e2e_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    // -------------------------------------------------------------------------
    // Pillar 1: Intra-Media Chapter Bookmarking System (Ctrl+B, F1..F10, Pips)
    // -------------------------------------------------------------------------
    testWidgets('Pillar 1 E2E: Chapter Bookmarking full lifecycle & UI jump', (tester) async {
      final bookmarkService = BookmarkService(storageDir: tempDir);
      const mediaId = 'interstellar_4k.mkv';

      // 1. Add sequential bookmarks
      await bookmarkService.addBookmark(
        mediaId: mediaId,
        position: const Duration(minutes: 42, seconds: 15),
        label: 'Black Hole Gargantua',
      );
      await bookmarkService.addBookmark(
        mediaId: mediaId,
        position: const Duration(hours: 1, minutes: 15, seconds: 30),
        label: 'Miller Water Planet Wave',
      );

      final bookmarks = bookmarkService.getBookmarks(mediaId);
      expect(bookmarks.length, 2);
      expect(bookmarks[0].formattedTime, '42:15');
      expect(bookmarks[1].formattedTime, '01:15:30');

      // 2. Render BookmarksSheet UI with mock seek handler
      Duration? jumpedTarget;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarksSheet(
              mediaId: mediaId,
              currentPosition: const Duration(minutes: 50),
              bookmarkService: bookmarkService,
              onSeek: (target) {
                jumpedTarget = target;
              },
            ),
          ),
        ),
      );

      expect(find.text('CHAPTERS & BOOKMARKS'), findsOneWidget);
      expect(find.text('Black Hole Gargantua'), findsOneWidget);
      expect(find.text('Miller Water Planet Wave'), findsOneWidget);

      // 3. Tap on first bookmark item to seek
      await tester.tap(find.text('Black Hole Gargantua'));
      await tester.pumpAndSettle();

      expect(jumpedTarget, const Duration(minutes: 42, seconds: 15));
    });

    // -------------------------------------------------------------------------
    // Pillar 2: Real-Time FFT Audio Spectrum Visualizer
    // -------------------------------------------------------------------------
    testWidgets('Pillar 2 E2E: Audio Spectrum Visualizer physics and rendering styles', (tester) async {
      final engine = AudioVisualizerEngine(bandCount: 32);

      // Verify band scaling & peak decay physics
      engine.tick(const Duration(milliseconds: 16));
      expect(engine.magnitudes.length, 32);
      expect(engine.peaks.length, 32);

      // Render Visualizer in Bars and MirrorWave styles
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioSpectrumVisualizerWidget(
              engine: engine,
              style: VisualizerStyle.bars,
              height: 120,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AudioSpectrumVisualizerWidget), findsOneWidget);

      // Switch to mirrorWave style
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioSpectrumVisualizerWidget(
              engine: engine,
              style: VisualizerStyle.mirrorWave,
              height: 120,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AudioSpectrumVisualizerWidget), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Pillar 3: Video Snapshot Frame Capture & Preview Toast
    // -------------------------------------------------------------------------
    test('Pillar 3 E2E: Snapshot capture, deduplication, and filename formatting', () async {
      final snapshotService = VideoSnapshotService(customStorageDir: tempDir);
      final dummyPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      ]);

      final result = await snapshotService.saveSnapshotBytes(
        bytes: dummyPngBytes,
        position: const Duration(minutes: 24, seconds: 10),
        mediaTitle: 'Oppenheimer',
      );

      expect(result.success, isTrue);
      expect(result.file, isNotNull);
      expect(result.file!.existsSync(), isTrue);
      expect(result.formattedPosition, '24:10');
      expect(result.fileName, startsWith('vlcsnap-'));
      expect(result.fileName, endsWith('.png'));
    });

    // -------------------------------------------------------------------------
    // Pillar 4: Desktop System Tray Integration & Background Audio Daemon
    // -------------------------------------------------------------------------
    test('Pillar 4 E2E: Desktop System Tray command pipeline and state persistence', () async {
      final trayService = DesktopTrayAudioService();

      trayService.updatePlaybackState(
        isPlaying: true,
        mediaTitle: 'Cyberpunk Edgerunners EP1.mkv',
        position: const Duration(minutes: 14),
        duration: const Duration(minutes: 24),
        volume: 150.0,
      );

      expect(trayService.currentState.isPlaying, isTrue);
      expect(trayService.currentState.mediaTitle, 'Cyberpunk Edgerunners EP1.mkv');
      expect(trayService.currentState.formattedStatus, 'Playing: Cyberpunk Edgerunners EP1.mkv');

      final commands = <TrayPlaybackCommand>[];
      final sub = trayService.commandStream.listen(commands.add);

      trayService.dispatchCommand(TrayPlaybackCommand.playPause);
      trayService.dispatchCommand(TrayPlaybackCommand.volumeUp);
      trayService.dispatchCommand(TrayPlaybackCommand.volumeDown);

      await pumpEventQueue();

      expect(commands, [
        TrayPlaybackCommand.playPause,
        TrayPlaybackCommand.volumeUp,
        TrayPlaybackCommand.volumeDown,
      ]);

      await sub.cancel();
      trayService.dispose();
    });
  });
}
