import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/stream_recorder/models/stream_recorder_models.dart';
import 'package:app/features/stream_recorder/data/stream_recorder_controller.dart';
import 'package:app/features/stream_recorder/ui/stream_recorder_badge_widget.dart';
import 'package:app/features/stream_recorder/ui/stream_recorder_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stream Recorder Widget Tests (record.c Parity)', () {
    testWidgets('StreamRecorderBadgeWidget is hidden when not recording', (tester) async {
      final controller = StreamRecorderController();
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamRecorderBadgeWidget(controller: controller),
          ),
        ),
      );

      expect(find.text('REC'), findsNothing);
      expect(find.byType(StreamRecorderBadgeWidget), findsOneWidget);
    });

    testWidgets('StreamRecorderBadgeWidget renders live badge when recording and handles stop', (tester) async {
      final controller = StreamRecorderController();
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamRecorderBadgeWidget(controller: controller),
          ),
        ),
      );

      // Start recording
      await controller.startRecording(
        mediaTitle: 'Live_News',
        mockDestinationDir: '/mock/path',
      );
      controller.tickForTesting(const Duration(minutes: 2, seconds: 15), 1024 * 1024 * 12);
      await tester.pump();

      // Badge is visible
      expect(find.text('REC'), findsOneWidget);
      expect(find.text('02:15'), findsOneWidget);
      expect(find.textContaining('12.0 MB'), findsOneWidget);

      // Tap stop icon button
      await tester.tap(find.byIcon(Icons.stop_circle));
      await tester.pump();

      expect(controller.isRecording, isFalse);
      expect(find.text('REC'), findsNothing);
    });

    testWidgets('StreamRecorderSheet renders status monitor, format chips, and starts recording', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = StreamRecorderController();
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamRecorderSheet(
              controller: controller,
              mediaTitle: 'Championship Final',
              sourceUrl: 'https://sports.stream/live.m3u8',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Stream Recorder'), findsOneWidget);
      expect(find.text('record.c'), findsOneWidget);
      expect(find.text('RECORDER IDLE'), findsOneWidget);
      expect(find.text('Start Stream Recording'), findsOneWidget);

      // Switch format chip to MPEG-TS
      await tester.tap(find.text('MPEG-TS (.ts)'));
      await tester.pumpAndSettle();
      expect(controller.config.format, equals(RecordingFormat.ts));

      // Tap start recording
      await tester.tap(find.byKey(const Key('stream_recorder_toggle_btn')));
      await tester.pumpAndSettle();

      expect(controller.isRecording, isTrue);
      expect(find.text('RECORDING IN PROGRESS'), findsOneWidget);
      expect(find.text('Stop Recording (Save Stream Dump)'), findsOneWidget);

      // Stop recording to cleanly cancel timer
      await controller.stopRecording();
      await tester.pumpAndSettle();
    });
  });
}
