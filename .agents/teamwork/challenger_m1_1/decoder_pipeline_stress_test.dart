import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/domain/decoder_models.dart';
import 'package:app/features/player/domain/decoder_pipeline_service.dart';

/// Test platform simulating `libmpv` property store with optional delay and error injection.
class StressFakeMpvPlatform {
  final Map<String, String> properties = {};
  final List<String> setPropertyLog = [];
  int simulatedDelayMs = 0;
  bool shouldFailSetProperty = false;
  void Function(String property, String value)? onSetProperty;

  Future<void> setProperty(String property, String value) async {
    if (simulatedDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: simulatedDelayMs));
    }
    if (shouldFailSetProperty) {
      throw Exception('Simulated platform failure for setProperty($property, $value)');
    }
    properties[property] = value;
    setPropertyLog.add('$property=$value');
    onSetProperty?.call(property, value);
  }

  Future<dynamic> getProperty(String property) async {
    if (simulatedDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: simulatedDelayMs));
    }
    return properties[property];
  }
}

void main() {
  group('Empirical Stress Suite 1: Rapid Mode Transitions (50+ Switches)', () {
    late DecoderPipelineService service;
    late StressFakeMpvPlatform fakePlatform;

    setUp(() async {
      fakePlatform = StressFakeMpvPlatform();
      service = DecoderPipelineService();
      await service.initialize(null, fakePlatform);
    });

    tearDown(() {
      service.dispose();
    });

    test('50 rapid sequential mode switches maintain strict state consistency and correct mpv properties', () async {
      final modes = [
        DecoderMode.hw,
        DecoderMode.hwPlus,
        DecoderMode.sw,
        DecoderMode.auto,
      ];

      final stopwatch = Stopwatch()..start();
      const int iterations = 50;
      final history = <DecoderMode>[];

      for (int i = 0; i < iterations; i++) {
        final targetMode = modes[i % modes.length];
        fakePlatform.properties['hwdec-current'] = targetMode == DecoderMode.sw ? 'no' : 'test_backend';
        
        final result = await service.setMode(targetMode, force: true);
        
        expect(result.success, isTrue, reason: 'Switch iteration $i to ${targetMode.label} must succeed');
        expect(result.activeMode, targetMode);
        expect(service.currentMode, targetMode);
        expect(fakePlatform.properties['hwdec'], targetMode.mpvValue);
        expect(service.isHardwareAccelerated, targetMode.isHardwareAccelerated);
        history.add(service.currentMode);
      }

      stopwatch.stop();
      print('[EMPIRICAL] 50 rapid sequential switches completed in ${stopwatch.elapsedMilliseconds}ms (${(stopwatch.elapsedMilliseconds / iterations).toStringAsFixed(2)}ms/switch)');
      expect(history.length, iterations);
    });

    test('50 rapid randomized mode switches with changing position do not corrupt state or drift', () async {
      final modes = [DecoderMode.auto, DecoderMode.hw, DecoderMode.hwPlus, DecoderMode.sw];
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 50; i++) {
        final targetMode = modes[(i * 7 + 3) % modes.length];
        service.setCurrentPosition(Duration(seconds: 10 + i * 5));
        
        final result = await service.setMode(targetMode, force: true);
        
        expect(result.success, isTrue);
        expect(service.currentMode, targetMode);
        expect(service.lastSeekDriftMs, lessThanOrEqualTo(250));
      }

      stopwatch.stop();
      print('[EMPIRICAL] 50 randomized switches completed in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Concurrent burst: 50 simultaneous setMode calls resolve cleanly without unhandled crashes', () async {
      final modes = [DecoderMode.hw, DecoderMode.hwPlus, DecoderMode.sw, DecoderMode.auto];
      
      // Fire 50 simultaneous async setMode requests without awaiting each sequentially
      final futures = <Future<DecoderSwitchResult>>[];
      for (int i = 0; i < 50; i++) {
        final mode = modes[i % modes.length];
        futures.add(service.setMode(mode, force: true));
      }

      final results = await Future.wait(futures);

      expect(results.length, 50);
      for (final res in results) {
        expect(res.success, isTrue);
      }

      // Final state must match one of the valid modes and mpv property must be valid
      expect([DecoderMode.hw, DecoderMode.hwPlus, DecoderMode.sw, DecoderMode.auto], contains(service.currentMode));
      expect(fakePlatform.properties['hwdec'], isNotNull);
      expect(fakePlatform.properties['hwdec'], service.currentMode.mpvValue);
      print('[EMPIRICAL] Concurrent 50-switch burst resolved into stable final mode: ${service.currentMode.label} (mpv: ${fakePlatform.properties['hwdec']})');
    });
  });

  group('Empirical Stress Suite 2: High-Frequency Drop Spikes (100 drops in 500ms)', () {
    late DecoderPipelineService service;
    late StressFakeMpvPlatform fakePlatform;

    setUp(() async {
      fakePlatform = StressFakeMpvPlatform();
      service = DecoderPipelineService();
      await service.initialize(null, fakePlatform);
      await service.setMode(DecoderMode.hw);
    });

    tearDown(() {
      service.dispose();
    });

    test('Simulating 100 drops in 500ms triggers cascade immediately and halts at SW without infinite loop', () async {
      expect(service.currentMode, DecoderMode.hw);

      final startTime = DateTime(2026, 10, 22, 14, 0, 0);
      final transitions = <String>[];
      int fallbackTriggerCount = 0;

      service.addListener(() {
        final lastLog = service.fallbackAuditLog.isNotEmpty ? service.fallbackAuditLog.last : '';
        if (transitions.isEmpty || transitions.last != '${service.currentMode.label} ($lastLog)') {
          transitions.add('${service.currentMode.label} ($lastLog)');
        }
      });

      final stopwatch = Stopwatch()..start();

      // Simulate 100 drops over 500ms (1 drop every 5ms)
      for (int drop = 1; drop <= 100; drop++) {
        final sampleTime = startTime.add(Duration(milliseconds: drop * 5));
        final fallbackResult = await service.recordFrameDropSample(drop, timestamp: sampleTime);
        if (fallbackResult != null) {
          fallbackTriggerCount++;
        }
      }

      stopwatch.stop();

      print('[EMPIRICAL] 100-drop spike over 500ms processed in ${stopwatch.elapsedMilliseconds}ms.');
      print('[EMPIRICAL] Fallback triggers fired: $fallbackTriggerCount');
      print('[EMPIRICAL] Final Mode: ${service.currentMode.label}');
      print('[EMPIRICAL] Audit Log: ${service.fallbackAuditLog}');

      // Must have cascaded: HW -> HW+ -> SW
      expect(service.currentMode, DecoderMode.sw, reason: 'Excessive drops must cause degradation to terminal SW');
      expect(service.isHardwareAccelerated, isFalse);
      expect(fakePlatform.properties['hwdec'], 'no');

      // The cascade should trigger exactly twice: HW -> HW+, then HW+ -> SW
      // Once in SW, further drops must NOT trigger fallback or loop infinitely!
      expect(fallbackTriggerCount, 2, reason: 'Must trigger exactly 2 fallbacks (HW->HW+ and HW+->SW), then halt');
      expect(service.fallbackAuditLog.length, 2);
      expect(service.fallbackAuditLog[0], contains('HW -> HW+'));
      expect(service.fallbackAuditLog[1], contains('HW+ -> SW'));
    });

    test('Sudden massive 100-drop burst in single sample triggers immediate fallback', () async {
      expect(service.currentMode, DecoderMode.hw);
      final t0 = DateTime(2026, 10, 22, 15, 0, 0);

      // Baseline sample
      await service.recordFrameDropSample(0, timestamp: t0);
      
      // Sudden burst of 100 drops within 50ms (window delta = 100 > 10)
      final step1 = await service.recordFrameDropSample(100, timestamp: t0.add(const Duration(milliseconds: 50)));
      expect(step1, isNotNull);
      expect(step1!.activeMode, DecoderMode.hwPlus);
      expect(service.currentMode, DecoderMode.hwPlus);

      // Post-fallback reference sample in HW+ mode
      await service.recordFrameDropSample(100, timestamp: t0.add(const Duration(milliseconds: 60)));

      // Second sudden burst of 100 drops (total 200, window delta = 100 > 10)
      final step2 = await service.recordFrameDropSample(200, timestamp: t0.add(const Duration(milliseconds: 100)));
      expect(step2, isNotNull);
      expect(step2!.activeMode, DecoderMode.sw);
      expect(service.currentMode, DecoderMode.sw);

      // Post-fallback reference sample in SW mode
      await service.recordFrameDropSample(200, timestamp: t0.add(const Duration(milliseconds: 110)));

      // Third burst of 100 drops (total 300) in SW mode
      final step3 = await service.recordFrameDropSample(300, timestamp: t0.add(const Duration(milliseconds: 150)));
      expect(step3, isNull, reason: 'In SW mode, further drop bursts must return null and not loop or crash');
      expect(service.currentMode, DecoderMode.sw);
    });

    test('Microtask flood: 100 simultaneous reportIncrementalDrops calls execute safely', () async {
      expect(service.currentMode, DecoderMode.hw);
      final baseTime = DateTime.now();

      // Launch 100 microtask drop reports without await
      final futures = <Future<DecoderSwitchResult?>>[];
      for (int i = 0; i < 100; i++) {
        futures.add(service.reportIncrementalDrops(1, timestamp: baseTime.add(Duration(milliseconds: i * 2))));
      }

      await Future.wait(futures);

      // Verify pipeline ended at terminal SW or HW+ depending on interleaving, and did not crash
      expect([DecoderMode.hwPlus, DecoderMode.sw], contains(service.currentMode));
      print('[EMPIRICAL] Microtask flood completed. Final mode: ${service.currentMode.label}, drops: ${service.droppedFrames}');
    });
  });

  group('Empirical Stress Suite 3: Terminal State Safety (SW Mode Resilience)', () {
    late DecoderPipelineService service;
    late StressFakeMpvPlatform fakePlatform;

    setUp(() async {
      fakePlatform = StressFakeMpvPlatform();
      service = DecoderPipelineService();
      await service.initialize(null, fakePlatform);
      // Force service into terminal SW mode
      await service.setMode(DecoderMode.sw);
    });

    tearDown(() {
      service.dispose();
    });

    test('SW mode is impervious to storm of 50 consecutive decode errors', () async {
      expect(service.currentMode, DecoderMode.sw);
      expect(service.isHardwareAccelerated, isFalse);

      for (int i = 0; i < 50; i++) {
        final result = await service.handleDecodeError('Fatal bitstream error #$i: corrupt slice header');
        expect(result, isNull, reason: 'SW mode must ignore decode errors for fallback');
        expect(service.currentMode, DecoderMode.sw, reason: 'Mode must never leave SW');
        expect(fakePlatform.properties['hwdec'], 'no');
      }

      print('[EMPIRICAL] 50 decode errors handled safely in terminal SW mode with 0 side effects');
    });

    test('SW mode is impervious to massive drop flood (1,000 drops)', () async {
      expect(service.currentMode, DecoderMode.sw);
      final startTime = DateTime(2026, 10, 22, 16, 0, 0);

      for (int i = 1; i <= 1000; i++) {
        final res = await service.recordFrameDropSample(i, timestamp: startTime.add(Duration(milliseconds: i)));
        expect(res, isNull);
        expect(service.currentMode, DecoderMode.sw);
      }

      expect(service.droppedFrames, 1000);
      expect(fakePlatform.properties['hwdec'], 'no');
      print('[EMPIRICAL] 1,000-drop flood processed in SW mode. Dropped frame count recorded: ${service.droppedFrames}');
    });

    test('Direct triggerFallback calls in SW mode return failed result and do not loop or crash', () async {
      expect(service.currentMode, DecoderMode.sw);

      for (int i = 0; i < 10; i++) {
        final result = await service.triggerFallback('Manual challenge fallback attempt #$i');
        expect(result.success, isFalse);
        expect(result.activeMode, DecoderMode.sw);
        expect(result.backend, isNotNull);
        expect(result.fallbackReason, contains('Terminal decoder tier reached (SW)'));
        expect(service.currentMode, DecoderMode.sw);
      }

      expect(service.fallbackAuditLog.length, 10);
      for (final log in service.fallbackAuditLog) {
        expect(log, contains('Terminal SW: Manual challenge fallback attempt'));
      }
      print('[EMPIRICAL] 10 consecutive explicit triggerFallback calls in SW safely handled');
    });

    test('User can manually re-elevate from SW mode back to HW mode', () async {
      expect(service.currentMode, DecoderMode.sw);

      final recoveryResult = await service.setMode(DecoderMode.hw);
      expect(recoveryResult.success, isTrue);
      expect(recoveryResult.activeMode, DecoderMode.hw);
      expect(service.currentMode, DecoderMode.hw);
      expect(service.isHardwareAccelerated, isTrue);
      expect(fakePlatform.properties['hwdec'], 'yes');

      // Once back in HW, drop threshold triggers fallback again as expected
      final t0 = DateTime(2026, 10, 22, 17, 0, 0);
      await service.recordFrameDropSample(0, timestamp: t0);
      final fb = await service.recordFrameDropSample(25, timestamp: t0.add(const Duration(milliseconds: 100)));
      expect(fb, isNotNull);
      expect(service.currentMode, DecoderMode.hwPlus);
      print('[EMPIRICAL] Re-elevation from SW to HW and subsequent fallback cycle verified successfully');
    });
  });

  group('Empirical Stress Suite 4: Invariants, Re-Seek & Teardown Boundary Tests', () {
    late DecoderPipelineService service;
    late StressFakeMpvPlatform fakePlatform;

    setUp(() async {
      fakePlatform = StressFakeMpvPlatform();
      service = DecoderPipelineService();
      await service.initialize(null, fakePlatform);
    });

    tearDown(() {
      service.dispose();
    });

    test('Preserves position with re-seek tolerance <= 250ms across rapid cascade', () async {
      final soughtPositions = <Duration>[];
      service.onCustomSeek = (target) async {
        soughtPositions.add(target);
        // Simulates the player's asynchronous position update following a seek
        service.setCurrentPosition(target);
      };

      const highPosition = Duration(hours: 2, minutes: 15, seconds: 42); // 8142s
      service.setCurrentPosition(highPosition);

      // Simulate hardware decoder drop causing position reset to zero
      fakePlatform.onSetProperty = (property, value) {
        if (property == 'hwdec') {
          service.setCurrentPosition(Duration.zero);
        }
      };

      await service.setMode(DecoderMode.hw);
      expect(soughtPositions.length, 1);
      expect(soughtPositions.last, highPosition);
      expect(service.lastSeekDriftMs, lessThanOrEqualTo(250));

      // Trigger fallback to HW+
      await service.triggerFallback('Stutter in HW');
      expect(soughtPositions.length, 2);
      expect(soughtPositions.last, highPosition);
      expect(service.lastSeekDriftMs, lessThanOrEqualTo(250));

      // Trigger fallback to SW
      await service.triggerFallback('Stutter in HW+');
      expect(soughtPositions.length, 3);
      expect(soughtPositions.last, highPosition);
      expect(service.lastSeekDriftMs, lessThanOrEqualTo(250));

      print('[EMPIRICAL] Re-seek tolerance <= 250ms strictly preserved across entire cascade: $soughtPositions');
    });

    test('Disposal mid-stream during high-frequency drop flood does not throw unhandled stream errors', () async {
      final localService = DecoderPipelineService();
      await localService.initialize(null, fakePlatform);
      await localService.setMode(DecoderMode.hw);
      final baseTime = DateTime.now();

      // Start 50 drop events and dispose service midway at i=20
      bool disposalCompleted = false;
      for (int i = 0; i < 50; i++) {
        if (i == 20) {
          localService.dispose();
          disposalCompleted = true;
        }
        try {
          await localService.reportIncrementalDrops(1, timestamp: baseTime.add(Duration(milliseconds: i * 10)));
        } catch (e) {
          fail('Calling methods post-disposal threw unhandled exception: $e');
        }
      }

      expect(disposalCompleted, isTrue);
      print('[EMPIRICAL] Mid-stream disposal verified: no exceptions thrown on post-disposal calls');
    });

    test('20 concurrent telemetryStream listeners receive valid snapshots under heavy load', () async {
      final receivedCounts = List.filled(20, 0);
      final subs = <StreamSubscription>[];

      for (int i = 0; i < 20; i++) {
        final index = i;
        subs.add(service.telemetryStream.listen((telemetry) {
          expect(telemetry.codec, isNotNull);
          expect(telemetry.droppedFrames, greaterThanOrEqualTo(0));
          receivedCounts[index]++;
        }));
      }

      // Generate 20 telemetry events
      service.setVideoCodec('hevc');
      for (int i = 0; i < 10; i++) {
        await service.setMode(i.isEven ? DecoderMode.hw : DecoderMode.hwPlus, force: true);
        await service.reportIncrementalDrops(2);
      }

      await Future.delayed(const Duration(milliseconds: 50));
      for (final sub in subs) {
        await sub.cancel();
      }

      for (int i = 0; i < 20; i++) {
        expect(receivedCounts[i], greaterThan(0), reason: 'Listener $i should have received telemetry events');
      }
      print('[EMPIRICAL] 20 concurrent telemetry listeners received average of ${receivedCounts[0]} events each without contention');
    });
  });
}
