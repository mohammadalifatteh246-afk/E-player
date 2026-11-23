import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/cdda/domain/cdda_models.dart';
import 'package:app/features/cdda/data/audio_cd_ripper_service.dart';
import 'package:app/features/cdda/ui/audio_cd_ripper_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioCdRipperSheet Widget Tests (VLC cdda.c Parity)', () {
    late Directory tempDir;
    late File mockAudioFile;
    late AudioCdDiscInfo mockDisc;
    late AudioCdRipperService ripperService;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cdda_widget_test_');
      mockAudioFile = File('${tempDir.path}/album.bin')..writeAsStringSync('dummy-audio-stream');

      mockDisc = AudioCdDiscInfo(
        cueSheetPath: '${tempDir.path}/album.cue',
        audioSourcePath: mockAudioFile.path,
        albumTitle: 'Random Access Memories',
        artist: 'Daft Punk',
        genre: 'Electronic',
        releaseYear: '2013',
        tracks: [
          CdTrackInfo(
            trackNumber: 1,
            title: 'Give Life Back to Music',
            artist: 'Daft Punk',
            startOffset: Duration.zero,
            duration: const Duration(minutes: 4, seconds: 35),
            isSelected: true,
          ),
          CdTrackInfo(
            trackNumber: 2,
            title: 'Giorgio by Moroder',
            artist: 'Daft Punk',
            startOffset: const Duration(minutes: 4, seconds: 35),
            duration: const Duration(minutes: 9, seconds: 4),
            isSelected: true,
          ),
          CdTrackInfo(
            trackNumber: 3,
            title: 'Get Lucky',
            artist: 'Daft Punk',
            startOffset: const Duration(minutes: 13, seconds: 39),
            duration: const Duration(minutes: 6, seconds: 9),
            isSelected: false,
          ),
        ],
      );

      ripperService = AudioCdRipperService(
        customExecutor: (args, onProgress, isCancelled) async {
          onProgress(1.0);
        },
      );
    });

    tearDown(() {
      ripperService.dispose();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('1. Renders disc header, metadata, format choices, and track list', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioCdRipperSheet(
              disc: mockDisc,
              ripperService: ripperService,
              outputDirectory: tempDir.path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Random Access Memories'), findsOneWidget);
      expect(find.textContaining('Daft Punk • 3 Tracks'), findsOneWidget);
      expect(find.text('Electronic • 2013'), findsOneWidget);

      // Format chips
      expect(find.byKey(const Key('rip_format_flac')), findsOneWidget);
      expect(find.byKey(const Key('rip_format_mp3')), findsOneWidget);
      expect(find.byKey(const Key('rip_format_aac')), findsOneWidget);
      expect(find.byKey(const Key('rip_format_opus')), findsOneWidget);
      expect(find.byKey(const Key('rip_format_wav')), findsOneWidget);

      // Tracks
      expect(find.text('01. Give Life Back to Music'), findsOneWidget);
      expect(find.text('02. Giorgio by Moroder'), findsOneWidget);
      expect(find.text('03. Get Lucky'), findsOneWidget);

      // Default selected tracks = 2
      expect(find.text('Rip 2 Track(s) (FLAC Lossless)'), findsOneWidget);
    });

    testWidgets('2. Format chip switching updates rip button text', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioCdRipperSheet(
              disc: mockDisc,
              ripperService: ripperService,
              outputDirectory: tempDir.path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap MP3 chip
      await tester.tap(find.byKey(const Key('rip_format_mp3')));
      await tester.pumpAndSettle();

      expect(find.text('Rip 2 Track(s) (MP3 High Quality)'), findsOneWidget);

      // Tap OPUS chip
      await tester.tap(find.byKey(const Key('rip_format_opus')));
      await tester.pumpAndSettle();

      expect(find.text('Rip 2 Track(s) (Opus Modern)'), findsOneWidget);
    });

    testWidgets('3. Select All and None buttons toggle all tracks', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioCdRipperSheet(
              disc: mockDisc,
              ripperService: ripperService,
              outputDirectory: tempDir.path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap None
      await tester.tap(find.byKey(const Key('rip_deselect_all_button')));
      await tester.pumpAndSettle();

      expect(find.text('Select Tracks to Rip'), findsOneWidget);
      expect(find.text('DISC TRACKS (0/3 SELECTED)'), findsOneWidget);

      // Tap All
      await tester.tap(find.byKey(const Key('rip_select_all_button')));
      await tester.pumpAndSettle();

      expect(find.text('Rip 3 Track(s) (FLAC Lossless)'), findsOneWidget);
      expect(find.text('DISC TRACKS (3/3 SELECTED)'), findsOneWidget);
    });

    testWidgets('4. Tapping start rip runs extraction and shows completion message', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioCdRipperSheet(
              disc: mockDisc,
              ripperService: ripperService,
              outputDirectory: tempDir.path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ripButton = find.byKey(const Key('start_rip_button'));
      expect(ripButton, findsOneWidget);

      await tester.ensureVisible(ripButton);
      await tester.pumpAndSettle();

      // Start ripping
      await tester.tap(ripButton);
      await tester.pump();
      await tester.pumpAndSettle();

      // Should show completion message
      expect(find.textContaining('Extraction Complete! 2 tracks ripped to ${tempDir.path}'), findsOneWidget);
    });

    testWidgets('5. Ripping error displays error container', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final failingRipper = AudioCdRipperService(
        customExecutor: (args, onProgress, isCancelled) async {
          throw Exception('FFmpeg mock failure error');
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioCdRipperSheet(
              disc: mockDisc,
              ripperService: failingRipper,
              outputDirectory: tempDir.path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ripButton = find.byKey(const Key('start_rip_button'));
      await tester.ensureVisible(ripButton);
      await tester.pumpAndSettle();

      await tester.tap(ripButton);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('FFmpeg mock failure error'), findsOneWidget);
      failingRipper.dispose();
    });
  });
}
