import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/audio_studio_sheet.dart';
import 'package:app/features/audio/domain/audio_pitch_models.dart';

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
  group('Audio Pitch Shifter UI Tests', () {
    testWidgets('AudioStudioSheet renders Pitch Shifter card and responds to controls', (tester) async {
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

      // 1. Verify Pitch Shifter Card is rendered
      expect(find.byKey(const Key('audio_pitch_shifter_card')), findsOneWidget);
      expect(find.text('Pitch Shifter & Scaler'), findsOneWidget);
      expect(find.byKey(const Key('pitch_shifter_toggle')), findsOneWidget);

      // Initially disabled
      expect(config.pitch.enabled, isFalse);

      // 2. Toggle switch on
      await tester.tap(find.byKey(const Key('pitch_shifter_toggle')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(config.pitch.enabled, isTrue);

      // 3. Verify presets and controls appear
      expect(find.text('Acoustic Pitch Presets'), findsOneWidget);
      expect(find.text('Chipmunk (+12st)'), findsOneWidget);
      expect(find.text('Deep Voice (-12st)'), findsOneWidget);
      expect(find.byKey(const Key('pitch_semitone_slider')), findsOneWidget);
      expect(find.byKey(const Key('pitch_cents_slider')), findsOneWidget);

      // 4. Tap Chipmunk preset (+12 semitones)
      await tester.tap(find.text('Chipmunk (+12st)'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(config.pitch.semitones, equals(12));
      expect(config.pitch.preset, equals(AudioPitchPreset.chipmunk));
      expect(find.text('+12 st (2.00x)'), findsOneWidget);

      // 5. Tap Nudge Semitone minus button
      await tester.tap(find.byKey(const Key('pitch_nudge_semitone_minus')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(config.pitch.semitones, equals(11));
      expect(config.pitch.preset, equals(AudioPitchPreset.custom));

      // 6. Tap Reset Pitch button
      await tester.tap(find.byKey(const Key('pitch_reset_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(config.pitch.semitones, equals(0));
      expect(config.pitch.cents, equals(0.0));
      expect(config.pitch.preset, equals(AudioPitchPreset.flat));
    });
  });
}
