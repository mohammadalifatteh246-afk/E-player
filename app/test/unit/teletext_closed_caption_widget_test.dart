import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/subtitles/models/teletext_closed_caption_models.dart';
import 'package:app/features/subtitles/data/teletext_closed_caption_controller.dart';
import 'package:app/features/subtitles/ui/teletext_osd_overlay_widget.dart';
import 'package:app/features/subtitles/ui/teletext_closed_captions_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Teletext & Closed-Captions Widget Tests (zvbi.c & cc.c Parity)', () {
    testWidgets('TeletextOsdOverlayWidget is hidden when teletext and CC are disabled', (tester) async {
      final controller = TeletextClosedCaptionController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeletextOsdOverlayWidget(controller: controller),
          ),
        ),
      );

      expect(find.byType(TeletextOsdOverlayWidget), findsOneWidget);
      expect(find.textContaining('P100'), findsNothing);
      expect(find.textContaining('CC1'), findsNothing);
    });

    testWidgets('TeletextOsdOverlayWidget renders retro teletext screen when enabled and navigates via Fastext', (tester) async {
      final controller = TeletextClosedCaptionController(
        teletextConfig: TeletextConfig(enabled: true, page: 100),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeletextOsdOverlayWidget(controller: controller),
          ),
        ),
      );

      await tester.pump();

      // Page badge is visible (can appear in header and yellow fastext pill)
      expect(find.text('P100'), findsWidgets);
      expect(find.textContaining('E-PLAYER TELETEXT'), findsOneWidget);

      // Fastext pills are rendered: Red (P101), Green (P200), Yellow (P777 or P100), Blue (P888)
      expect(find.text('P101'), findsOneWidget);
      expect(find.text('P200'), findsOneWidget);
      expect(find.text('P888'), findsOneWidget);

      // Tap Blue Fastext button (P888 Subtitles)
      await tester.tap(find.text('P888'));
      await tester.pump();

      expect(controller.teletextConfig.page, equals(888));
      expect(find.text('P888'), findsWidgets);
    });

    testWidgets('TeletextOsdOverlayWidget renders CC badge when Closed Captions are active', (tester) async {
      final controller = TeletextClosedCaptionController(
        captionConfig: ClosedCaptionConfig(channel: ClosedCaptionChannel.cc1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeletextOsdOverlayWidget(controller: controller),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('CC1'), findsOneWidget);
      expect(find.byIcon(Icons.closed_caption), findsOneWidget);
    });

    testWidgets('TeletextClosedCaptionsSheet renders Teletext & CC tabs with numeric keypad', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = TeletextClosedCaptionController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 1400,
              child: TeletextClosedCaptionsSheet(controller: controller),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Teletext & Closed-Captions'), findsOneWidget);
      expect(find.text('Teletext (VBI / zvbi.c)'), findsOneWidget);
      expect(find.text('Closed-Captions (cc.c)'), findsOneWidget);

      // Numeric Keypad digits
      expect(find.byKey(const Key('teletext_digit_8')), findsOneWidget);

      // Input 3 digits using keypad
      await tester.tap(find.byKey(const Key('teletext_digit_8')));
      await tester.pumpAndSettle();
      expect(controller.keypadBuffer, equals('8'));

      await tester.tap(find.byKey(const Key('teletext_digit_8')));
      await tester.pumpAndSettle();
      expect(controller.keypadBuffer, equals('88'));

      await tester.tap(find.byKey(const Key('teletext_digit_8')));
      await tester.pumpAndSettle();
      expect(controller.teletextConfig.page, equals(888));
    });
  });
}
