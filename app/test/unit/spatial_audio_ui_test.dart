import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/player/ui/audio_studio_sheet.dart';
import 'package:app/features/audio/domain/spatial_audio_models.dart';

class _FakePlayer extends Fake implements Player {
  @override
  PlayerState get state => const PlayerState();
}

void main() {
  group('Spatial Audio UI Tests', () {
    testWidgets('AudioStudioSheet renders Spatial Audio card and toggles crossfeed options', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final config = AudioConfig();
      final player = _FakePlayer();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioStudioSheet(
              player: player,
              config: config,
              isFullScreen: true,
            ),
          ),
        ),
      );

      // Verify header and card
      expect(find.text('Spatial Audio & Crossfeed'), findsOneWidget);
      expect(find.byKey(const Key('spatial_audio_crossfeed_card')), findsOneWidget);

      // Toggle Spatial Audio switch
      final switchFinder = find.byKey(const Key('spatial_audio_toggle'));
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(config.spatialAudio.enabled, isTrue);

      // Verify crossfeed chips are rendered
      expect(find.text('Bauer Std (700Hz/4.5dB)'), findsOneWidget);
      expect(find.text('Chu Moy (700Hz/6dB)'), findsOneWidget);
      expect(find.text('Jan Meier (650Hz/9.5dB)'), findsOneWidget);

      // Select 'Chu Moy' chip
      await tester.tap(find.text('Chu Moy (700Hz/6dB)'));
      await tester.pumpAndSettle();

      expect(config.spatialAudio.crossfeedMode, equals(CrossfeedPreset.chuMoy));
    });
  });
}
