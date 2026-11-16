import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';
import 'package:app/features/video_effects/domain/video_effects_service.dart';
import 'package:app/features/video_effects/ui/video_effects_sheet.dart';

class _FakePlatformPlayer extends Fake implements PlatformPlayer {
  final Map<String, String> properties = {};

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
  }
}

class _FakePlayerState extends Fake implements PlayerState {
  @override
  Duration get position => Duration.zero;
  @override
  double get volume => 100.0;
  @override
  bool get playing => false;
}

class _FakePlayer extends Fake implements Player {
  @override
  final PlatformPlayer platform;
  @override
  final PlayerState state = _FakePlayerState();

  _FakePlayer(this.platform);
}

void main() {
  group('Video Effects Colors Tab & Color Threshold UI Tests', () {
    testWidgets('Renders Colors tab, toggles Invert and Color Threshold with color chips', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final platform = _FakePlatformPlayer();
      final player = _FakePlayer(platform);
      final config = VideoEffectsConfig();
      final service = VideoEffectsService();

      int changeNotifications = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoEffectsSheet(
              player: player,
              config: config,
              service: service,
              onConfigChanged: () {
                changeNotifications++;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Switch to Colors Tab
      final colorsTab = find.text('Colors');
      expect(colorsTab, findsOneWidget);
      await tester.tap(colorsTab);
      await tester.pumpAndSettle();

      // 2. Verify Invert switch and Sepia switch are rendered
      expect(find.text('Negate / Invert Colors'), findsOneWidget);
      expect(find.text('Sepia Tone Filter'), findsOneWidget);

      // Verify Color Threshold Isolation is rendered
      expect(find.text('Color Threshold Isolation'), findsOneWidget);
      expect(find.text('Isolates selected color while turning other hues monochrome (Sin City / Pleasantville)'), findsOneWidget);

      // Initially colorThreshold is disabled
      expect(config.colorThreshold, isFalse);
      expect(find.text('Target Color Preset'), findsNothing);

      // 3. Toggle Invert switch on
      final invertTile = find.widgetWithText(SwitchListTile, 'Negate / Invert Colors');
      expect(invertTile, findsOneWidget);
      await tester.tap(invertTile);
      await tester.pumpAndSettle();
      expect(config.invert, isTrue);
      expect(changeNotifications, greaterThan(0));

      // 4. Toggle Color Threshold Isolation switch on
      final thresholdTile = find.widgetWithText(SwitchListTile, 'Color Threshold Isolation');
      expect(thresholdTile, findsOneWidget);
      await tester.tap(thresholdTile);
      await tester.pumpAndSettle();

      expect(config.colorThreshold, isTrue);
      expect(find.text('Target Color Preset'), findsOneWidget);

      // Verify preset color chips are rendered
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Green'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Yellow'), findsOneWidget);
      expect(find.text('Cyan'), findsOneWidget);
      expect(find.text('Magenta'), findsOneWidget);
      expect(find.text('Orange'), findsOneWidget);

      // Verify sliders
      expect(find.text('Similarity Tolerance'), findsOneWidget);
      expect(find.text('Saturation Threshold'), findsOneWidget);

      // 5. Select Green swatch
      await tester.tap(find.text('Green'));
      await tester.pumpAndSettle();
      expect(config.colorThresholdColor, equals(0x00FF00));

      // 6. Select Blue swatch
      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();
      expect(config.colorThresholdColor, equals(0x0000FF));

      // 7. Verify libmpv vf string holds colorhold filter
      final vf = config.buildMpvVfString();
      expect(vf, contains('negate'));
      expect(vf, contains('colorhold=color=0x0000FF:similarity=0.30:blend=0.05'));
    });
  });
}
