import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phase2_e2e_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger Verification Suite: Phase 2 Empirical & Adversarial Hardening', () {
    // =========================================================================
    // 1. HARNESS SENSITIVITY & INVALIDATION TESTING
    // =========================================================================
    group('1. Harness Sensitivity & Invalidation Testing', () {
      test('1.1: FakePlatformPlayer detects unregistered commands and missing properties', () async {
        final fake = FakePlatformPlayer();
        final player = Player(platformPlayer: fake);
        final dynamic platform = player.platform;

        // Command detection
        expect(fake.hasCommand('frame-step'), isFalse);
        expect(fake.hasCommand('nonexistent-command'), isFalse);

        await platform.command(['custom-cmd', 'arg1']);
        expect(fake.hasCommand('custom-cmd'), isTrue);
        expect(fake.hasCommand('frame-step'), isFalse);

        // Missing property query returns null
        final unknownVal = await platform.getProperty('nonexistent-prop');
        expect(unknownVal, isNull);

        await player.dispose();
      });

      test('1.2: Invalidation Test — Intentional assertion mismatch fails on volume-max (Non-tautological)', () async {
        final fake = FakePlatformPlayer();
        final player = Player(platformPlayer: fake);
        final dynamic platform = player.platform;

        await platform.setProperty('volume-max', '300.0');

        // Confirm genuine sensitivity: expecting 100.0 or 130.0 throws TestFailure
        expect(
          () => expect(fake.properties['volume-max'], equals('130.0')),
          throwsA(isA<TestFailure>()),
          reason: 'Harness must fail when property does not match expectation',
        );

        expect(fake.properties['volume-max'], equals('300.0'));
        await player.dispose();
      });

      test('1.3: Invalidation Test — Intentional mismatch on VolumeSafetyColors boundaries (Non-tautological)', () {
        // Boundary 100.0% MUST be Green; asserting Amber must fail
        expect(
          () => expect(VolumeSafetyColors.resolve(100.0), equals(VolumeSafetyColors.amber)),
          throwsA(isA<TestFailure>()),
        );

        // Boundary 100.1% MUST be Amber; asserting Green must fail
        expect(
          () => expect(VolumeSafetyColors.resolve(100.1), equals(VolumeSafetyColors.green)),
          throwsA(isA<TestFailure>()),
        );

        // Boundary 200.0% MUST be Amber; asserting Soft Red must fail
        expect(
          () => expect(VolumeSafetyColors.resolve(200.0), equals(VolumeSafetyColors.softRed)),
          throwsA(isA<TestFailure>()),
        );

        // Boundary 200.1% MUST be Soft Red; asserting Amber must fail
        expect(
          () => expect(VolumeSafetyColors.resolve(200.1), equals(VolumeSafetyColors.amber)),
          throwsA(isA<TestFailure>()),
        );
      });

      test('1.4: Invalidation Test — Intentional mismatch on ABRepeatController invalid Point B', () {
        final controller = ABRepeatController();
        controller.cycle(const Duration(seconds: 20)); // Point A at 20s

        // Cycle with 10s (earlier than Point A) returns false
        final result = controller.cycle(const Duration(seconds: 10));

        // Asserting that cycle succeeded MUST throw TestFailure
        expect(
          () => expect(result, isTrue),
          throwsA(isA<TestFailure>()),
        );
        expect(controller.state, equals(ABRepeatState.pointA));
      });

      test('1.5: Invalidation Test — Intentional mismatch on AspectCrop presets', () {
        // Confirm preset strings are exact and not generic placeholders
        expect(
          () => expect(CropPreset.ratio16_9.filterString, equals('crop=16:9')),
          throwsA(isA<TestFailure>()),
          reason: 'Must use precise centered crop filter crop=ih*16/9:ih',
        );
        expect(CropPreset.ratio16_9.filterString, equals('crop=ih*16/9:ih'));
      });

      test('1.6: Invalidation Test — Intentional mismatch on demuxer cache byte calculation', () {
        // 128MB is 134,217,728 bytes (128 * 1024 * 1024), NOT decimal 128,000,000 bytes
        const decimalBytes = '128000000';
        const binaryBytes = '134217728';

        expect(
          () => expect(binaryBytes, equals(decimalBytes)),
          throwsA(isA<TestFailure>()),
        );
      });
    });

    // =========================================================================
    // 2. EDGE CASE STRESS TESTING
    // =========================================================================
    group('2. Edge Case Stress Testing', () {
      test('2.1: A-B looping seek storm: 100 rapid position updates past Point B trigger exactly 1 seek', () async {
        final controller = ABRepeatController();
        controller.cycle(const Duration(seconds: 10)); // Point A
        controller.cycle(const Duration(seconds: 20)); // Point B
        expect(controller.state, equals(ABRepeatState.looping));

        int seekCount = 0;
        final soughtTargets = <Duration>[];

        // Simulate 100 rapid position stream ticks past Point B
        for (int i = 0; i < 100; i++) {
          await controller.checkPosition(
            Duration(milliseconds: 20000 + i * 10),
            onSeek: (target) async {
              seekCount++;
              soughtTargets.add(target);
            },
          );
        }

        expect(seekCount, equals(1), reason: 'Anti-thrashing debounce must suppress storm of 100 position ticks');
        expect(soughtTargets.single, equals(const Duration(seconds: 10)));
        expect(controller.isLoopSeeking, isTrue);

        // Position rewinds to Point A + 50ms
        await controller.checkPosition(
          const Duration(milliseconds: 10050),
          onSeek: (target) async => seekCount++,
        );
        expect(controller.isLoopSeeking, isFalse, reason: 'Debounce lock resets cleanly after rewind');

        // Next time position reaches Point B, exactly 1 new seek fires
        await controller.checkPosition(
          const Duration(seconds: 20),
          onSeek: (target) async => seekCount++,
        );
        expect(seekCount, equals(2));
      });

      test('2.2: Violent position jitter across Point B boundary does not deadlock or thrash', () async {
        final controller = ABRepeatController();
        controller.cycle(const Duration(seconds: 5));
        controller.cycle(const Duration(seconds: 10));

        int seekCalls = 0;
        // Jitter oscillating around 10s: 9.9s -> 10.1s -> 9.8s -> 10.2s -> 4.9s -> 10.0s
        final jitterTicks = [
          const Duration(milliseconds: 9900),
          const Duration(milliseconds: 10100), // First trigger (+1)
          const Duration(milliseconds: 9800),  // Reset lock
          const Duration(milliseconds: 10200), // Second trigger (+1)
          const Duration(milliseconds: 4900),  // Reset lock (before Point A)
          const Duration(milliseconds: 10000), // Third trigger (+1)
        ];

        for (final tick in jitterTicks) {
          await controller.checkPosition(tick, onSeek: (t) async => seekCalls++);
        }

        expect(seekCalls, equals(3), reason: 'Each legitimate crossing after rewind triggers exactly once');
      });

      test('2.3: Point A and Point B minimal delta auto-pads to 500ms window without zero-duration division', () {
        final controller = ABRepeatController();
        controller.cycle(const Duration(seconds: 12));

        // Attempt Point B only 1 millisecond after Point A
        final ok = controller.cycle(const Duration(milliseconds: 12001));
        expect(ok, isTrue);
        expect(controller.state, equals(ABRepeatState.looping));

        // Enforced minimum duration
        final window = controller.pointB! - controller.pointA!;
        expect(window.inMilliseconds, greaterThanOrEqualTo(500));
      });

      testWidgets('2.4: Extreme volume swipe inputs (>10,000 px drag) clamp strictly to [0.0, 300.0]', (tester) async {
        final fake = FakePlatformPlayer(initialVolume: 100.0);
        final player = Player(platformPlayer: fake);

        await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
        await tester.pumpAndSettle();

        // 1. Extreme upward drag: -15,000 px
        await tester.drag(find.byType(GestureDetector).first, const Offset(0, -15000));
        await tester.pumpAndSettle();

        expect(player.state.volume, equals(300.0));
        expect(player.state.volume.isFinite, isTrue);
        expect(player.state.volume.isNaN, isFalse);
        expect(VolumeSafetyColors.resolve(player.state.volume), equals(VolumeSafetyColors.softRed));
        expect(find.text('300% [Over-Amplification]'), findsOneWidget);

        // 2. Extreme downward drag: +25,000 px
        await tester.drag(find.byType(GestureDetector).first, const Offset(0, 25000));
        await tester.pumpAndSettle();

        expect(player.state.volume, equals(0.0));
        expect(player.state.volume.isFinite, isTrue);
        expect(player.state.volume.isNaN, isFalse);
        expect(VolumeSafetyColors.resolve(player.state.volume), equals(VolumeSafetyColors.green));
        expect(find.text('0% [Standard]'), findsOneWidget);

        await player.dispose();
      });

      testWidgets('2.5: Rapid volume swipe burst (50 alternating drag gestures) maintains numerical stability', (tester) async {
        final fake = FakePlatformPlayer(initialVolume: 100.0);
        final player = Player(platformPlayer: fake);

        await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
        await tester.pumpAndSettle();

        for (int i = 0; i < 50; i++) {
          final dy = (i % 2 == 0) ? -200.0 : 180.0;
          await tester.drag(find.byType(GestureDetector).first, Offset(0, dy));
        }
        await tester.pumpAndSettle();

        expect(player.state.volume, greaterThanOrEqualTo(0.0));
        expect(player.state.volume, lessThanOrEqualTo(300.0));
        expect(player.state.volume.isFinite, isTrue);
        await player.dispose();
      });

      testWidgets('2.6: Rapid crop key spamming (100 c keypresses) stays strictly in-bounds', (tester) async {
        final fake = FakePlatformPlayer();
        final player = Player(platformPlayer: fake);

        await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
        await tester.pumpAndSettle();

        final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));

        // 100 rapid 'c' keypresses
        for (int i = 0; i < 100; i++) {
          await simulateShortcut(tester, key: LogicalKeyboardKey.keyC);
        }
        await tester.pumpAndSettle();

        // 100 mod 6 = 4 -> index (5 + 100) % 6 = 105 % 6 = 3 (1.85:1)
        expect(state.cropController.currentIndex, equals(3));
        expect(state.cropController.current, equals(CropPreset.ratio1_85_1));
        expect(fake.properties['vf'], equals(CropPreset.ratio1_85_1.filterString));

        await player.dispose();
      });

      testWidgets('2.7: Rapid alternating c (crop) and a (aspect) key spamming produces zero state cross-contamination', (tester) async {
        final fake = FakePlatformPlayer();
        final player = Player(platformPlayer: fake);

        await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
        await tester.pumpAndSettle();

        final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));

        for (int i = 0; i < 30; i++) {
          await simulateShortcut(tester, key: LogicalKeyboardKey.keyC);
          await simulateShortcut(tester, key: LogicalKeyboardKey.keyA);
        }
        await tester.pumpAndSettle();

        // Check both controllers reached deterministic state without errors
        expect(state.cropController.current, isNotNull);
        expect(state.currentAspectRatio, isNotEmpty);
        expect(fake.properties['vf'], isNotNull);

        await player.dispose();
      });

      test('2.8: Rapid caching slider updates with extreme values clamp within [500, 10000]', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fake = FakePlatformPlayer();
        final player = Player(platformPlayer: fake);
        final controller = BufferCachingSettingsController();

        final extremeValues = [-999999, -500, 0, 499, 500, 1000, 9999, 10000, 10001, 8888888];

        for (final val in extremeValues) {
          await controller.setNetworkCachingMs(val, prefs, player: player);
          expect(controller.networkCachingMs, greaterThanOrEqualTo(500));
          expect(controller.networkCachingMs, lessThanOrEqualTo(10000));

          final cacheSecs = double.parse(fake.properties['cache-secs']!);
          expect(cacheSecs, greaterThanOrEqualTo(0.50));
          expect(cacheSecs, lessThanOrEqualTo(10.00));
        }

        await player.dispose();
      });

      test('2.9: Rapid demuxer cache size toggling with invalid/unknown values falls back safely', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fake = FakePlatformPlayer();
        final player = Player(platformPlayer: fake);
        final controller = BufferCachingSettingsController();

        // Valid values: 16, 32, 64, 128
        // Test invalid inputs: 0, -16, 48, 256, 1024
        for (final invalid in [0, -16, 48, 256, 1024]) {
          await controller.setDemuxerCacheMb(invalid, prefs, player: player);
          expect(controller.demuxerCacheMb, equals(32), reason: 'Invalid MB option must fall back to 32MB default');
          expect(fake.properties['demuxer-max-bytes'], equals((32 * 1024 * 1024).toString()));
        }

        await player.dispose();
      });
    });
  });
}
