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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Deinterlacing Filter UI Tests (deinterlace.c Parity)', () {
    testWidgets('VideoEffectsSheet renders Deinterlacing controls and updates mode and algorithm', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final platform = _FakePlatformPlayer();
      final player = _FakePlayer(platform);
      final config = VideoEffectsConfig(deinterlaceMode: DeinterlaceMode.off);
      final service = VideoEffectsService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoEffectsSheet(
              player: player,
              config: config,
              service: service,
              onConfigChanged: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Deinterlacing header is present
      expect(find.text('Deinterlacing (VLC deinterlace.c)'), findsOneWidget);

      // Segmented buttons Off, Auto, On
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);

      // Initially Off, so algorithm chips are not shown
      expect(find.text('YADIF (2x)'), findsNothing);

      // Switch mode to On
      await tester.tap(find.text('On'));
      await tester.pumpAndSettle();

      expect(config.deinterlaceMode, equals(DeinterlaceMode.on));
      expect(find.text('Deinterlace Algorithm Preset'), findsOneWidget);
      expect(find.text('YADIF'), findsOneWidget);
      expect(find.text('YADIF (2x)'), findsOneWidget);
      expect(find.text('Bob / BWDIF'), findsOneWidget);

      // Select YADIF (2x)
      await tester.tap(find.text('YADIF (2x)'));
      await tester.pumpAndSettle();

      expect(config.deinterlaceAlgorithm, equals(DeinterlaceAlgorithm.yadif2x));
      expect(config.toMpvFilterString(), contains('yadif=mode=send_field:parity=auto:deint=all'));

      // Switch back to Off
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();

      expect(config.deinterlaceMode, equals(DeinterlaceMode.off));
      expect(find.text('YADIF (2x)'), findsNothing);
    });
  });
}
