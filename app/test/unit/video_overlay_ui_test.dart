import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';
import 'package:app/features/video_effects/domain/video_effects_service.dart';
import 'package:app/features/video_effects/ui/video_effects_sheet.dart';
import 'package:app/features/video_effects/ui/video_overlay_widget.dart';

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
  group('Video Overlay Widget & VideoEffectsSheet Overlay Tab Tests', () {
    testWidgets('VideoOverlayWidget renders marquee text with format tokens without blocking gestures', (tester) async {
      final config = VideoEffectsConfig(
        marqueeEnabled: true,
        marqueeText: 'E-Player • %t • %p',
        marqueePosition: VideoOverlayPosition.topCenter,
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    tapped = true;
                  },
                  child: const SizedBox.expand(
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
                VideoOverlayWidget(
                  config: config,
                  mediaTitle: 'Blade Runner 2049',
                  position: const Duration(minutes: 5, seconds: 12),
                  duration: const Duration(hours: 2, minutes: 43),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify formatted text is rendered on screen
      expect(find.text('E-Player • Blade Runner 2049 • 05:12'), findsOneWidget);

      // Verify taps pass through IgnorePointer to underlying gesture detector
      await tester.tap(find.text('E-Player • Blade Runner 2049 • 05:12'), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('VideoEffectsSheet renders Overlay tab and interacts with Logo and Marquee controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final platform = _FakePlatformPlayer();
      final player = _FakePlayer(platform);
      final config = VideoEffectsConfig();
      final service = VideoEffectsService();

      int changeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoEffectsSheet(
              player: player,
              config: config,
              service: service,
              onConfigChanged: () {
                changeCount++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Switch to Overlay tab
      final overlayTab = find.text('Overlay');
      expect(overlayTab, findsOneWidget);
      await tester.tap(overlayTab);
      await tester.pumpAndSettle();

      // 2. Verify Section Headers and Switches
      expect(find.text('Video Logo & Watermark (VLC logo.c)'), findsOneWidget);
      expect(find.text('Enable Watermark / Logo'), findsOneWidget);
      expect(find.text('Text Marquee & Dynamic OSD (VLC marq.c)'), findsOneWidget);
      expect(find.text('Enable Text Marquee OSD'), findsOneWidget);

      // Initially disabled
      expect(config.logoEnabled, isFalse);
      expect(config.marqueeEnabled, isFalse);

      // 3. Toggle Watermark switch on
      final logoTile = find.widgetWithText(SwitchListTile, 'Enable Watermark / Logo');
      await tester.tap(logoTile);
      await tester.pumpAndSettle();
      expect(config.logoEnabled, isTrue);

      // Position chips & sliders rendered
      expect(find.text('Logo Position'), findsOneWidget);
      expect(find.text('Logo Opacity'), findsOneWidget);
      expect(find.text('Logo Scale'), findsOneWidget);

      // 4. Select Logo Position (Bottom-Right)
      final brChip = find.widgetWithText(InkWell, 'Bottom-Right').first;
      await tester.tap(brChip);
      await tester.pumpAndSettle();
      expect(config.logoPosition, equals(VideoOverlayPosition.bottomRight));

      // 5. Toggle Marquee switch on
      final marqueeTile = find.widgetWithText(SwitchListTile, 'Enable Text Marquee OSD');
      await tester.tap(marqueeTile);
      await tester.pumpAndSettle();
      expect(config.marqueeEnabled, isTrue);

      // Verify marquee controls
      expect(find.text('Marquee Position'), findsOneWidget);
      expect(find.text('Font Size'), findsOneWidget);
      expect(find.text('Text Opacity'), findsOneWidget);
      expect(find.text('Contrast Background Badge'), findsOneWidget);

      // Tap preset chip 'Clock Time'
      final clockChip = find.text('Clock Time');
      expect(clockChip, findsOneWidget);
      await tester.tap(clockChip);
      await tester.pumpAndSettle();
      expect(config.marqueeText, equals('%Y-%m-%d %H:%M:%S'));
      expect(changeCount, greaterThan(0));
    });
  });
}
