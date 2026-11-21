import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';
import 'package:app/features/video_effects/ui/video_overlay_widget.dart';
import 'package:app/features/video_effects/ui/watermark_studio_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatermarkStudioSheet & VideoOverlayWidget UI Tests (VLC Parity)', () {
    testWidgets('1. Displays Watermark Studio Sheet and enables watermark toggle', (tester) async {
      final config = VideoEffectsConfig();
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatermarkStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Watermark & Logo Studio'), findsOneWidget);
      expect(find.text('Enable Watermark Overlay'), findsOneWidget);

      // Options should be hidden initially
      expect(find.byKey(const Key('watermark_mode_image')), findsNothing);

      // Toggle switch to ON
      final switchFinder = find.byKey(const Key('watermark_enable_switch'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(updatedConfig?.logoEnabled, isTrue);
      expect(find.byKey(const Key('watermark_mode_image')), findsOneWidget);
      expect(find.byKey(const Key('watermark_mode_text')), findsOneWidget);
    });

    testWidgets('2. 3x3 Grid selection updates position anchor', (tester) async {
      final config = VideoEffectsConfig(logoEnabled: true);
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatermarkStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap bottom-right position button
      final brFinder = find.byKey(const Key('watermark_pos_bottomRight'));
      expect(brFinder, findsOneWidget);
      await tester.tap(brFinder);
      await tester.pumpAndSettle();

      expect(updatedConfig?.logoPosition, equals(VideoOverlayPosition.bottomRight));

      // Tap center position button
      final centerFinder = find.byKey(const Key('watermark_pos_center'));
      expect(centerFinder, findsOneWidget);
      await tester.tap(centerFinder);
      await tester.pumpAndSettle();

      expect(updatedConfig?.logoPosition, equals(VideoOverlayPosition.center));
    });

    testWidgets('3. Switching to text watermark mode updates logoText', (tester) async {
      final config = VideoEffectsConfig(logoEnabled: true);
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatermarkStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to text mode
      final textChip = find.byKey(const Key('watermark_mode_text'));
      await tester.tap(textChip);
      await tester.pumpAndSettle();

      final textField = find.byKey(const Key('watermark_text_field'));
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'E-PLAYER • LIVE');
      await tester.pumpAndSettle();

      expect(updatedConfig?.logoText, equals('E-PLAYER • LIVE'));
    });

    testWidgets('4. VideoOverlayWidget renders text watermark on screen', (tester) async {
      final config = VideoEffectsConfig(
        logoEnabled: true,
        logoText: 'CYBERPUNK WATERMARK',
        logoPosition: VideoOverlayPosition.topRight,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: VideoOverlayWidget(
                config: config,
                mediaTitle: 'Test Video',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CYBERPUNK WATERMARK'), findsOneWidget);
    });
  });
}
