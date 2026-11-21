import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';
import 'package:app/features/video_effects/ui/anaglyph_studio_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnaglyphStudioSheet UI Widget Tests (VLC anaglyph.c Parity)', () {
    testWidgets('1. Displays Anaglyph Studio Sheet and enables 3D toggle', (tester) async {
      final config = VideoEffectsConfig();
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnaglyphStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3D Anaglyph Studio'), findsOneWidget);
      expect(find.text('Enable 3D Stereoscopic Filter'), findsOneWidget);

      // Options should be hidden initially
      expect(find.byKey(const Key('anaglyph_source_sideBySideHalf')), findsNothing);

      // Toggle switch to ON
      final switchFinder = find.byKey(const Key('anaglyph_enable_switch'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(updatedConfig?.anaglyphEnabled, isTrue);
      expect(find.byKey(const Key('anaglyph_source_synthetic2D')), findsOneWidget);
      expect(find.byKey(const Key('anaglyph_source_sideBySideHalf')), findsOneWidget);
      expect(find.byKey(const Key('anaglyph_source_topAndBottomHalf')), findsOneWidget);
    });

    testWidgets('2. Switching input video format chips updates anaglyphSource', (tester) async {
      final config = VideoEffectsConfig(anaglyphEnabled: true);
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnaglyphStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Side-by-Side chip
      final sbsChip = find.byKey(const Key('anaglyph_source_sideBySideHalf'));
      expect(sbsChip, findsOneWidget);
      await tester.tap(sbsChip);
      await tester.pumpAndSettle();

      expect(updatedConfig?.anaglyphSource, equals(AnaglyphSourceMode.sideBySideHalf));

      // Tap Top-and-Bottom chip
      final tabChip = find.byKey(const Key('anaglyph_source_topAndBottomHalf'));
      expect(tabChip, findsOneWidget);
      await tester.tap(tabChip);
      await tester.pumpAndSettle();

      expect(updatedConfig?.anaglyphSource, equals(AnaglyphSourceMode.topAndBottomHalf));
    });

    testWidgets('3. Switching glasses color scheme updates anaglyphMatrix', (tester) async {
      final config = VideoEffectsConfig(anaglyphEnabled: true);
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnaglyphStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Green-Magenta chip
      final gmChip = find.byKey(const Key('anaglyph_matrix_greenMagenta'));
      expect(gmChip, findsOneWidget);
      await tester.tap(gmChip);
      await tester.pumpAndSettle();

      expect(updatedConfig?.anaglyphMatrix, equals(AnaglyphColorMatrix.greenMagenta));

      // Tap Amber-Blue chip
      final abChip = find.byKey(const Key('anaglyph_matrix_amberBlue'));
      expect(abChip, findsOneWidget);
      await tester.tap(abChip);
      await tester.pumpAndSettle();

      expect(updatedConfig?.anaglyphMatrix, equals(AnaglyphColorMatrix.amberBlue));
    });

    testWidgets('4. Toggling Swap Eyes switch updates anaglyphSwapEyes', (tester) async {
      final config = VideoEffectsConfig(anaglyphEnabled: true);
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnaglyphStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final swapSwitch = find.byKey(const Key('anaglyph_swap_eyes_switch'));
      expect(swapSwitch, findsOneWidget);
      await tester.ensureVisible(swapSwitch);
      await tester.tap(swapSwitch);
      await tester.pumpAndSettle();

      expect(updatedConfig?.anaglyphSwapEyes, isTrue);
    });

    testWidgets('5. Tapping Reset button restores defaults', (tester) async {
      final config = VideoEffectsConfig(
        anaglyphEnabled: true,
        anaglyphSource: AnaglyphSourceMode.sideBySideHalf,
        anaglyphMatrix: AnaglyphColorMatrix.greenMagenta,
        anaglyphSwapEyes: true,
      );
      VideoEffectsConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnaglyphStudioSheet(
              config: config,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resetButton = find.byKey(const Key('anaglyph_reset_button'));
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(updatedConfig?.anaglyphEnabled, isFalse);
      expect(updatedConfig?.anaglyphSource, equals(AnaglyphSourceMode.synthetic2D));
      expect(updatedConfig?.anaglyphMatrix, equals(AnaglyphColorMatrix.redCyanDubois));
      expect(updatedConfig?.anaglyphSwapEyes, isFalse);
    });
  });
}
