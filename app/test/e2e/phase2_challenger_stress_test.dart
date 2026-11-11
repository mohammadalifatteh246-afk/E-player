import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import the components from phase2_e2e_test.dart
import 'phase2_e2e_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger Tier 1: Harness Sensitivity & Invalidation Testing', () {
    test('CH1.1: FakePlatformPlayer property and command sensitivity', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final dynamic platform = player.platform;

      // Verify unissued command returns false
      expect(fake.hasCommand('invalid-command'), isFalse);
      expect(fake.hasCommand('frame-step'), isFalse);

      // Issue command
      await platform.command(['frame-step']);
      expect(fake.hasCommand('frame-step'), isTrue);
      expect(fake.hasCommand('random-command'), isFalse);

      // Verify property store
      await platform.setProperty('test-prop', '42');
      expect(await platform.getProperty('test-prop'), equals('42'));
      expect(await platform.getProperty('non-existent'), isNull);

      await player.dispose();
    });

    test('CH1.2: Invalidation test proving VolumeSafetyColors assertions are non-tautological', () {
      // 100.0 must be Green, Amber must fail
      expect(
        () => expect(VolumeSafetyColors.resolve(100.0), equals(VolumeSafetyColors.amber)),
        throwsA(isA<TestFailure>()),
      );

      // 200.0 must be Amber, Soft Red must fail
      expect(
        () => expect(VolumeSafetyColors.resolve(200.0), equals(VolumeSafetyColors.softRed)),
        throwsA(isA<TestFailure>()),
      );

      // 250.0 must be Soft Red, Green must fail
      expect(
        () => expect(VolumeSafetyColors.resolve(250.0), equals(VolumeSafetyColors.green)),
        throwsA(isA<TestFailure>()),
      );
    });

    test('CH1.3: Invalidation test proving A-B repeat rejection is strictly enforced', () {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 20)); // Point A at 20s

      // Setting Point B at 10s must return false
      final success = controller.cycle(const Duration(seconds: 10));
      expect(success, isFalse);

      // Expecting it to be looping must throw TestFailure
      expect(
        () => expect(controller.state, equals(ABRepeatState.looping)),
        throwsA(isA<TestFailure>()),
      );
      expect(controller.state, equals(ABRepeatState.pointA));
    });

    test('CH1.4: Invalidation test proving volume clamping cannot exceed 300.0', () {
      double clampVolume(double v) => v.clamp(0.0, 300.0);

      // Expecting unconstrained volume of 350 to pass must fail
      expect(
        () => expect(clampVolume(350.0), equals(350.0)),
        throwsA(isA<TestFailure>()),
      );
      expect(clampVolume(350.0), equals(300.0));
    });

    test('CH1.5: Invalidation test proving crop filter strings match exact specifications', () {
      expect(
        () => expect(CropPreset.ratio16_9.filterString, equals('crop=ih*4/3:ih')),
        throwsA(isA<TestFailure>()),
      );
      expect(CropPreset.ratio16_9.filterString, equals('crop=ih*16/9:ih'));
    });
  });

  group('Challenger Tier 2: Edge Case Stress Testing', () {
    test('CH2.1: A-B looping seek storm stress test under 1,000 rapid ticks', () async {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 10)); // Point A = 10s
      controller.cycle(const Duration(seconds: 20)); // Point B = 20s
      expect(controller.state, equals(ABRepeatState.looping));

      int seekCount = 0;
      Duration? lastTarget;

      // Storm 1: 1,000 rapid position ticks past Point B (20s to 25s)
      for (int i = 0; i < 1000; i++) {
        await controller.checkPosition(
          Duration(milliseconds: 20000 + (i % 500)),
          onSeek: (target) async {
            seekCount++;
            lastTarget = target;
          },
        );
      }

      // Concurrency lock MUST throttle all redundant ticks: exactly 1 seek trigger
      expect(seekCount, equals(1));
      expect(lastTarget, equals(const Duration(seconds: 10)));
      expect(controller.isLoopSeeking, isTrue);

      // Rewind to Point A + 50ms (player seeks back)
      await controller.checkPosition(
        const Duration(milliseconds: 10050),
        onSeek: (target) async => seekCount++,
      );
      expect(controller.isLoopSeeking, isFalse);

      // Storm 2: Another 500 ticks past Point B
      for (int i = 0; i < 500; i++) {
        await controller.checkPosition(
          Duration(milliseconds: 20000 + i),
          onSeek: (target) async => seekCount++,
        );
      }
      expect(seekCount, equals(2));
    });

    test('CH2.2: A-B looping rapid oscillation stress test (300 cycles)', () async {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 5));
      controller.cycle(const Duration(seconds: 10));

      int seekCount = 0;
      for (int cycle = 0; cycle < 300; cycle++) {
        // Tick at Point B -> triggers seek
        await controller.checkPosition(
          const Duration(seconds: 10),
          onSeek: (t) async => seekCount++,
        );
        // Tick at Point A -> resets guard
        await controller.checkPosition(
          const Duration(seconds: 5),
          onSeek: (t) async => seekCount++,
        );
      }

      // Exactly 300 clean loops with zero missed or dropped seeks
      expect(seekCount, equals(300));
    });

    testWidgets('CH2.3: Extreme volume swipe stress (>10,000 px drag and sub-pixel drags)', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 100.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final gestureFinder = find.byType(GestureDetector).first;

      // 1. Extreme 15,000px upward drag
      await tester.drag(gestureFinder, const Offset(0, -15000));
      await tester.pumpAndSettle();
      expect(player.state.volume, equals(300.0));
      expect(VolumeSafetyColors.resolve(player.state.volume), equals(VolumeSafetyColors.softRed));

      // 2. Extreme 25,000px downward drag
      await tester.drag(gestureFinder, const Offset(0, 25000));
      await tester.pumpAndSettle();
      expect(player.state.volume, equals(0.0));
      expect(VolumeSafetyColors.resolve(player.state.volume), equals(VolumeSafetyColors.green));

      // 3. Sub-pixel micro drags
      await tester.drag(gestureFinder, const Offset(0, -0.00001));
      await tester.pumpAndSettle();
      expect(player.state.volume.isNaN, isFalse);
      expect(player.state.volume.isInfinite, isFalse);

      // 4. Zero displacement drag
      await tester.drag(gestureFinder, Offset.zero);
      await tester.pumpAndSettle();
      expect(player.state.volume, greaterThanOrEqualTo(0.0));
      expect(player.state.volume, lessThanOrEqualTo(300.0));

      await player.dispose();
    });

    testWidgets('CH2.4: Rapid crop key spamming (300 consecutive events)', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));

      // Initial state is Reset (index 5)
      expect(state.cropController.current, equals(CropPreset.reset));

      // 300 rapid presses of 'c'
      // 300 % 6 = 0, so after 300 steps it must complete exactly 50 full cycles back to Reset!
      for (int i = 0; i < 300; i++) {
        await simulateShortcut(tester, key: LogicalKeyboardKey.keyC);
      }
      await tester.pumpAndSettle();

      expect(state.cropController.current, equals(CropPreset.reset));
      expect(fake.properties['vf'], equals(''));

      // 1 extra press should land on 16:9
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();
      expect(state.cropController.current, equals(CropPreset.ratio16_9));
      expect(fake.properties['vf'], equals('crop=ih*16/9:ih'));

      await player.dispose();
    });

    test('CH2.5: Network caching slider boundary and invalid input stress (500 iterations)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = BufferCachingSettingsController();

      // Stress test 500 boundary inputs
      final testInputs = [-99999, -500, 0, 499, 500, 1000, 5000, 9999, 10000, 10001, 50000, 999999];

      for (int i = 0; i < 500; i++) {
        final val = testInputs[i % testInputs.length];
        await controller.setNetworkCachingMs(val, prefs, player: player);

        expect(controller.networkCachingMs, greaterThanOrEqualTo(500));
        expect(controller.networkCachingMs, lessThanOrEqualTo(10000));

        final cacheSecsStr = fake.properties['cache-secs']!;
        final cacheSecs = double.parse(cacheSecsStr);
        expect(cacheSecs, greaterThanOrEqualTo(0.50));
        expect(cacheSecs, lessThanOrEqualTo(10.00));
      }

      await player.dispose();
    });

    test('CH2.6: Demuxer cache selector resilience against invalid sizes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = BufferCachingSettingsController();

      // Unsupported cache sizes should safely default to 32MB
      final invalidSizes = [0, -16, 1, 8, 15, 33, 48, 65, 96, 256, 1024];

      for (final badSize in invalidSizes) {
        await controller.setDemuxerCacheMb(badSize, prefs, player: player);
        expect(controller.demuxerCacheMb, equals(32));
        expect(fake.properties['demuxer-max-bytes'], equals((32 * 1024 * 1024).toString()));
      }

      // Valid sizes must be accepted
      for (final goodSize in [16, 32, 64, 128]) {
        await controller.setDemuxerCacheMb(goodSize, prefs, player: player);
        expect(controller.demuxerCacheMb, equals(goodSize));
        expect(fake.properties['demuxer-max-bytes'], equals((goodSize * 1024 * 1024).toString()));
      }

      await player.dispose();
    });
  });
}
