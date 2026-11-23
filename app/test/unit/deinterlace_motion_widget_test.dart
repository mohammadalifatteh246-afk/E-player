import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';
import 'package:app/features/video_effects/ui/deinterlace_motion_studio_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeinterlaceMotionStudioSheet Widget Tests (VLC deinterlace.c & motionblur.c Parity)', () {
    testWidgets('1. Displays studio sheet with deinterlacer and motion blur sections', (tester) async {
      final config = VideoEffectsConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeinterlaceMotionStudioSheet(
              config: config,
              onConfigChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deinterlace & Motion Blur Studio'), findsOneWidget);
      expect(find.text('VLC deinterlace.c & motionblur.c parity'), findsOneWidget);
      expect(find.text('Interlaced Video Deinterlacer'), findsOneWidget);
      expect(find.text('Frame-by-Frame Motion Blur'), findsOneWidget);

      // Deinterlacing is off initially; algorithm & parity chips should not be shown
      expect(find.byKey(const Key('algo_chip_yadif')), findsNothing);
      expect(find.byKey(const Key('field_order_tff')), findsNothing);

      // Motion blur is off initially; preset chips should not be shown
      expect(find.byKey(const Key('motion_preset_cinematic')), findsNothing);
    });

    testWidgets('2. Toggling deinterlace mode to On displays algorithms and parity choices', (tester) async {
      final config = VideoEffectsConfig();
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeinterlaceMotionStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "On" segment in SegmentedButton
      final onSegment = find.text('On');
      expect(onSegment, findsOneWidget);
      await tester.tap(onSegment);
      await tester.pumpAndSettle();

      expect(updatedConfig?.deinterlaceMode, equals(DeinterlaceMode.on));

      // Algorithm chips should now be visible
      expect(find.byKey(const Key('algo_chip_yadif')), findsOneWidget);
      expect(find.byKey(const Key('algo_chip_yadif2x')), findsOneWidget);
      expect(find.byKey(const Key('algo_chip_bob')), findsOneWidget);
      expect(find.byKey(const Key('algo_chip_blend')), findsOneWidget);

      // Field order parity chips should now be visible
      expect(find.byKey(const Key('field_order_auto')), findsOneWidget);
      expect(find.byKey(const Key('field_order_tff')), findsOneWidget);
      expect(find.byKey(const Key('field_order_bff')), findsOneWidget);

      // Tap YADIF (2x) chip
      await tester.tap(find.byKey(const Key('algo_chip_yadif2x')));
      await tester.pumpAndSettle();
      expect(updatedConfig?.deinterlaceAlgorithm, equals(DeinterlaceAlgorithm.yadif2x));

      // Tap Top Field First (TFF) chip
      await tester.tap(find.byKey(const Key('field_order_tff')));
      await tester.pumpAndSettle();
      expect(updatedConfig?.deinterlaceFieldOrder, equals(DeinterlaceFieldOrder.tff));
    });

    testWidgets('3. Enabling Motion Blur switch reveals presets, slider, and kernel badge', (tester) async {
      final config = VideoEffectsConfig();
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeinterlaceMotionStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle switch to ON
      final switchFinder = find.byKey(const Key('motion_blur_enable_switch'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(updatedConfig?.motionBlurEnabled, isTrue);

      // Presets chips should be visible
      expect(find.byKey(const Key('motion_preset_subtle')), findsOneWidget);
      expect(find.byKey(const Key('motion_preset_cinematic')), findsOneWidget);
      expect(find.byKey(const Key('motion_preset_sports')), findsOneWidget);
      expect(find.byKey(const Key('motion_preset_dreamy')), findsOneWidget);
      expect(find.byKey(const Key('motion_preset_custom')), findsOneWidget);

      // Frame slider should be visible
      expect(find.byKey(const Key('motion_blur_frames_slider')), findsOneWidget);

      // Kernel badge should show default 3 frames
      expect(find.textContaining('tmix=frames=3:weights="1 2 1"'), findsOneWidget);

      // Select "Sports Action Smoothing" preset (4 frames)
      await tester.tap(find.byKey(const Key('motion_preset_sports')));
      await tester.pumpAndSettle();

      expect(updatedConfig?.motionBlurPreset, equals(MotionBlurPreset.sports));
      expect(updatedConfig?.motionBlurFrames, equals(4));
      expect(find.textContaining('tmix=frames=4:weights="1 2 2 1"'), findsOneWidget);

      // Select "Dreamy / Artistic Trail" preset (6 frames)
      await tester.tap(find.byKey(const Key('motion_preset_dreamy')));
      await tester.pumpAndSettle();

      expect(updatedConfig?.motionBlurPreset, equals(MotionBlurPreset.dreamy));
      expect(updatedConfig?.motionBlurFrames, equals(6));
      expect(find.textContaining('tmix=frames=6:weights="1 2 3 3 2 1"'), findsOneWidget);
    });

    testWidgets('4. Tapping Reset button restores deinterlace and motion blur defaults', (tester) async {
      final config = VideoEffectsConfig(
        deinterlaceMode: DeinterlaceMode.on,
        deinterlaceAlgorithm: DeinterlaceAlgorithm.bob,
        deinterlaceFieldOrder: DeinterlaceFieldOrder.bff,
        motionBlurEnabled: true,
        motionBlurPreset: MotionBlurPreset.sports,
        motionBlurFrames: 4,
      );
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeinterlaceMotionStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resetButton = find.byKey(const Key('deinterlace_motion_reset_button'));
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(updatedConfig?.deinterlaceMode, equals(DeinterlaceMode.off));
      expect(updatedConfig?.deinterlaceAlgorithm, equals(DeinterlaceAlgorithm.yadif));
      expect(updatedConfig?.deinterlaceFieldOrder, equals(DeinterlaceFieldOrder.auto));
      expect(updatedConfig?.motionBlurEnabled, isFalse);
      expect(updatedConfig?.motionBlurPreset, equals(MotionBlurPreset.cinematic));
      expect(updatedConfig?.motionBlurFrames, equals(3));
    });
  });
}
