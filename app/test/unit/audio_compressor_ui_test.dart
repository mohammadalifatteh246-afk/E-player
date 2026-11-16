import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/audio_studio_sheet.dart';
import 'package:app/features/audio/domain/audio_compressor_models.dart';

class _FakePlayerState extends Fake implements PlayerState {
  @override
  Duration get position => Duration.zero;
  @override
  double get volume => 100.0;
  @override
  bool get playing => false;
}

class _FakePlatformPlayer extends Fake implements PlatformPlayer {
  final Map<String, String> properties = {};

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
  }
}

class _FakePlayer extends Fake implements Player {
  @override
  final PlatformPlayer platform;
  @override
  final PlayerState state = _FakePlayerState();

  _FakePlayer(this.platform);
}

void main() {
  group('Audio Compressor DRC UI Tests', () {
    testWidgets('AudioStudioSheet renders Compressor card and responds to controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final platform = _FakePlatformPlayer();
      final player = _FakePlayer(platform);
      final config = AudioConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AudioStudioSheet(
                player: player,
                config: config,
                isFullScreen: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Compressor Card is rendered
      expect(find.byKey(const Key('audio_compressor_card')), findsOneWidget);
      expect(find.text('Dynamic Range Compressor (DRC)'), findsOneWidget);
      expect(find.byKey(const Key('compressor_toggle')), findsOneWidget);

      // Initially disabled
      expect(config.compressor.enabled, isFalse);

      // 2. Toggle switch on
      await tester.tap(find.byKey(const Key('compressor_toggle')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(config.compressor.enabled, isTrue);

      // 3. Verify presets and controls appear
      expect(find.text('Acoustic Compression Profiles'), findsOneWidget);
      expect(find.text('Night Cinema'), findsOneWidget);
      expect(find.text('Hard Limiter'), findsOneWidget);
      expect(find.byKey(const Key('compressor_threshold_slider')), findsOneWidget);
      expect(find.byKey(const Key('compressor_ratio_slider')), findsOneWidget);
      expect(find.byKey(const Key('compressor_makeup_slider')), findsOneWidget);

      // 4. Tap Night Cinema preset
      await tester.tap(find.text('Night Cinema'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(config.compressor.threshold, equals(-20.0));
      expect(config.compressor.ratio, equals(6.0));
      expect(config.compressor.preset, equals(AudioCompressorPreset.nightCinema));
      expect(find.text('-20.0 dB'), findsOneWidget);
      expect(find.text('6.0:1'), findsOneWidget);

      // 5. Toggle RMS Detection switch
      expect(config.compressor.rmsDetection, isTrue);
      await tester.tap(find.byKey(const Key('compressor_rms_toggle')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(config.compressor.rmsDetection, isFalse);

      // 6. Tap Reset DRC button
      await tester.tap(find.byKey(const Key('compressor_reset_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(config.compressor.threshold, equals(-11.0));
      expect(config.compressor.ratio, equals(4.0));
      expect(config.compressor.rmsDetection, isTrue);
      expect(config.compressor.preset, equals(AudioCompressorPreset.balancedDefault));
    });
  });
}
