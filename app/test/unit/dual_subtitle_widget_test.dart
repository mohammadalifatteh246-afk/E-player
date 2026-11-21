import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/subtitles/domain/dual_subtitle_controller.dart';
import 'package:app/features/subtitles/ui/dual_subtitle_sheet.dart';

class MockMpvPropertyDispatcher implements MpvSubtitlePropertyDispatcher {
  final Map<String, String> properties = {};
  SubtitleTrack? lastPrimaryTrack;

  @override
  Future<void> setProperty(String name, String value) async {
    properties[name] = value;
  }

  @override
  Future<void> setPrimaryTrack(SubtitleTrack track) async {
    lastPrimaryTrack = track;
  }
}

void main() {
  group('DualSubtitleSheet Widget Tests', () {
    late MockMpvPropertyDispatcher dispatcher;
    late DualSubtitleController controller;
    late List<SubtitleTrack> sampleTracks;

    setUp(() {
      dispatcher = MockMpvPropertyDispatcher();
      controller = DualSubtitleController(dispatcher: dispatcher);
      sampleTracks = [
        SubtitleTrack.uri('file:///sub_en.srt', title: 'English [Default]', language: 'eng'),
        SubtitleTrack.uri('file:///sub_hi.srt', title: 'Hindi [SDH]', language: 'hin'),
        SubtitleTrack.uri('file:///sub_ja.srt', title: 'Japanese [Original]', language: 'jpn'),
      ];
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: DualSubtitleSheet(
            controller: controller,
            availableTracks: sampleTracks,
          ),
        ),
      );
    }

    testWidgets('1. Renders DualSubtitleSheet with header, switch, and track selectors', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Dual Subtitles Studio'), findsOneWidget);
      expect(find.text('Simultaneous Top & Bottom Tracks (VLC Parity)'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('PRIMARY SUBTITLE (BOTTOM · 92%)'), findsOneWidget);
      expect(find.text('Swap Bottom & Top Tracks'), findsOneWidget);
      expect(find.text('SECONDARY SUBTITLE (TOP · 10%)'), findsOneWidget);
    });

    testWidgets('2. Toggling switch updates controller.isEnabled', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(controller.isEnabled, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(controller.isEnabled, isTrue);
    });

    testWidgets('3. Tapping Swap Bottom & Top Tracks calls controller.swapTracks()', (tester) async {
      controller.setPrimaryTrack(sampleTracks[0]);
      controller.setSecondaryTrack(sampleTracks[1]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(controller.primaryTrack.id, sampleTracks[0].id);
      expect(controller.secondaryTrack.id, sampleTracks[1].id);

      await tester.tap(find.text('Swap Bottom & Top Tracks'));
      await tester.pumpAndSettle();

      expect(controller.primaryTrack.id, sampleTracks[1].id);
      expect(controller.secondaryTrack.id, sampleTracks[0].id);
    });

    testWidgets('4. Secondary timing and placement cards appear when enabled', (tester) async {
      controller.toggleDualSubtitles(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Secondary Subtitle Delay'), findsOneWidget);
      expect(find.text('Secondary Subtitle Placement'), findsOneWidget);
      expect(find.text('Reset (0.0s)'), findsOneWidget);
      expect(find.text('+0.1s'), findsOneWidget);
      expect(find.text('-0.5s'), findsOneWidget);

      // Tap +0.1s nudge
      await tester.tap(find.text('+0.1s'));
      await tester.pumpAndSettle();

      expect(controller.secondaryDelay, closeTo(0.1, 0.001));

      // Tap Upper Third preset chip
      await tester.ensureVisible(find.text('Upper Third (25%)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upper Third (25%)'));
      await tester.pumpAndSettle();

      expect(controller.secondaryPosition, 25.0);
    });
  });
}
