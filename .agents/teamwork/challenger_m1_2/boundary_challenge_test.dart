import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/domain/decoder_models.dart';
import 'package:app/features/player/domain/decoder_pipeline_service.dart';

/// Test platform simulating `libmpv` property store.
class FakeMpvPlatform {
  final Map<String, String> properties = {};
  final List<String> setPropertyCalls = [];
  void Function(String property, String value)? onSetProperty;

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    setPropertyCalls.add('$property=$value');
    onSetProperty?.call(property, value);
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }
}

void main() {
  group('Empirical Challenge 1: Sliding 2000ms Drop-Frame Monitoring', () {
    late DecoderPipelineService service;
    late FakeMpvPlatform fakePlatform;

    setUp(() async {
      fakePlatform = FakeMpvPlatform();
      service = DecoderPipelineService();
      await service.initialize(null, fakePlatform);
      await service.setMode(DecoderMode.hw);
    });

    tearDown(() {
      service.dispose();
    });

    test('Boundary: Exactly 9 drops in 2000ms -> MUST NOT trigger fallback', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      // t = 0ms: 0 drops
      final r0 = await service.recordFrameDropSample(0, timestamp: baseTime);
      expect(r0, isNull);

      // t = 1000ms: 4 drops
      final r1 = await service.recordFrameDropSample(4, timestamp: baseTime.add(const Duration(milliseconds: 1000)));
      expect(r1, isNull);

      // t = 1999ms: 9 drops (delta = 9 drops across 1999ms)
      final r2 = await service.recordFrameDropSample(9, timestamp: baseTime.add(const Duration(milliseconds: 1999)));
      expect(r2, isNull);

      // Verify mode remains HW and no fallback was triggered
      expect(service.currentMode, DecoderMode.hw);
      expect(service.droppedFrames, 9);
      expect(service.lastFallbackReason, isNull);
    });

    test('Boundary: Exactly 10 drops in 2000ms -> MUST NOT trigger fallback (>10 threshold)', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      // t = 0ms: 0 drops
      await service.recordFrameDropSample(0, timestamp: baseTime);

      // t = 1000ms: 5 drops
      await service.recordFrameDropSample(5, timestamp: baseTime.add(const Duration(milliseconds: 1000)));

      // t = 2000ms: exactly 10 drops (delta = 10 drops across 2000ms)
      final r = await service.recordFrameDropSample(10, timestamp: baseTime.add(const Duration(milliseconds: 2000)));

      // 10 is NOT > 10, so fallback must NOT trigger
      expect(r, isNull);
      expect(service.currentMode, DecoderMode.hw);
      expect(service.droppedFrames, 10);
      expect(service.lastFallbackReason, isNull);
    });

    test('Boundary: Exactly 11 drops in 2000ms -> MUST trigger fallback', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      // t = 0ms: 0 drops
      await service.recordFrameDropSample(0, timestamp: baseTime);

      // t = 1200ms: 6 drops
      await service.recordFrameDropSample(6, timestamp: baseTime.add(const Duration(milliseconds: 1200)));

      // t = 1950ms: exactly 11 drops (delta = 11 > 10)
      final fallbackResult = await service.recordFrameDropSample(
        11,
        timestamp: baseTime.add(const Duration(milliseconds: 1950)),
      );

      // Must trigger fallback from HW -> HW+
      expect(fallbackResult, isNotNull);
      expect(fallbackResult!.success, isTrue);
      expect(fallbackResult.activeMode, DecoderMode.hwPlus);
      expect(service.currentMode, DecoderMode.hwPlus);
      expect(fakePlatform.properties['hwdec'], 'auto-copy');
      expect(service.lastFallbackReason, contains('11 drops > threshold 10'));
    });

    test('Old drops (>2000ms ago) -> MUST be pruned and not count toward current window', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      // t = 0ms: 0 drops
      await service.recordFrameDropSample(0, timestamp: baseTime);

      // t = 800ms: 8 drops
      await service.recordFrameDropSample(8, timestamp: baseTime.add(const Duration(milliseconds: 800)));

      // t = 1600ms: 9 drops (9 drops in 1600ms <= 10 -> no fallback)
      await service.recordFrameDropSample(9, timestamp: baseTime.add(const Duration(milliseconds: 1600)));
      expect(service.currentMode, DecoderMode.hw);

      // t = 2801ms: 15 drops.
      // Notice: baseTime (t=0ms) is 2801ms ago (>2000ms) -> pruned!
      // But t=800ms is 2001ms ago (>2000ms) -> pruned!
      // Only t=1600ms (1201ms ago) and t=2801ms (0ms ago) remain in window.
      // Delta = 15 - 9 = 6 drops (< 10 threshold).
      final r = await service.recordFrameDropSample(
        15,
        timestamp: baseTime.add(const Duration(milliseconds: 2801)),
      );

      expect(r, isNull);
      expect(service.currentMode, DecoderMode.hw);
      expect(service.droppedFrames, 15);
      expect(service.lastFallbackReason, isNull);
    });

    test('Sliding window boundary: exact 2000ms vs 2001ms difference', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      // Test case A: Sample at t=0ms and t=2000ms (difference == 2000ms, not >2000ms)
      // Delta = 11 - 0 = 11 drops in exactly 2000ms -> Triggers fallback
      await service.recordFrameDropSample(0, timestamp: baseTime);
      final rA = await service.recordFrameDropSample(
        11,
        timestamp: baseTime.add(const Duration(milliseconds: 2000)),
      );
      expect(rA, isNotNull);
      expect(service.currentMode, DecoderMode.hwPlus);

      // Reset service for Test case B
      service.dispose();
      service = DecoderPipelineService();
      await service.initialize(null, fakePlatform);
      await service.setMode(DecoderMode.hw);

      // Test case B: Sample at t=0ms and t=2001ms (difference == 2001ms > 2000ms)
      // Sample at t=0ms is pruned because 2001 > 2000ms.
      // Only 1 sample remains at t=2001ms (drops = 11).
      // Since length < 2, no delta can be calculated yet -> No fallback!
      await service.recordFrameDropSample(0, timestamp: baseTime);
      final rB = await service.recordFrameDropSample(
        11,
        timestamp: baseTime.add(const Duration(milliseconds: 2001)),
      );
      expect(rB, isNull);
      expect(service.currentMode, DecoderMode.hw);
    });

    test('reportIncrementalDrops boundary challenge (9 vs 10 vs 11 drops)', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      // t = 0ms: baseline 0
      await service.recordFrameDropSample(0, timestamp: baseTime);

      // Incremental 4 drops at 500ms
      await service.reportIncrementalDrops(4, timestamp: baseTime.add(const Duration(milliseconds: 500)));
      expect(service.currentMode, DecoderMode.hw);

      // Incremental 5 drops at 1200ms -> Total 9 drops (delta = 9 <= 10)
      await service.reportIncrementalDrops(5, timestamp: baseTime.add(const Duration(milliseconds: 1200)));
      expect(service.currentMode, DecoderMode.hw);

      // Incremental 1 drop at 1800ms -> Total 10 drops (delta = 10 <= 10)
      await service.reportIncrementalDrops(1, timestamp: baseTime.add(const Duration(milliseconds: 1800)));
      expect(service.currentMode, DecoderMode.hw);

      // Incremental 1 drop at 1900ms -> Total 11 drops (delta = 11 > 10) -> MUST TRIGGER FALLBACK!
      final r = await service.reportIncrementalDrops(1, timestamp: baseTime.add(const Duration(milliseconds: 1900)));
      expect(r, isNotNull);
      expect(service.currentMode, DecoderMode.hwPlus);
    });

    test('Cascading through excessive drops: HW -> HW+ -> SW -> Terminal SW', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      // 1. In HW mode, drop 12 frames in 1000ms -> Fallback to HW+
      await service.recordFrameDropSample(0, timestamp: baseTime);
      final r1 = await service.recordFrameDropSample(12, timestamp: baseTime.add(const Duration(milliseconds: 1000)));
      expect(r1, isNotNull);
      expect(service.currentMode, DecoderMode.hwPlus);

      // 2. In HW+ mode, drop 12 more frames in next 1000ms (cumulative 24) -> Fallback to SW
      final t2 = baseTime.add(const Duration(milliseconds: 1500));
      await service.recordFrameDropSample(12, timestamp: t2);
      final r2 = await service.recordFrameDropSample(24, timestamp: t2.add(const Duration(milliseconds: 800)));
      expect(r2, isNotNull);
      expect(service.currentMode, DecoderMode.sw);

      // 3. In SW mode, drop 15 more frames (cumulative 39) -> SW is terminal, cannot fallback further
      final t3 = t2.add(const Duration(milliseconds: 1200));
      await service.recordFrameDropSample(24, timestamp: t3);
      final r3 = await service.recordFrameDropSample(39, timestamp: t3.add(const Duration(milliseconds: 800)));
      expect(r3, isNull); // Cannot fallback from SW
      expect(service.currentMode, DecoderMode.sw);
      expect(service.isHardwareAccelerated, isFalse);
    });
  });

  group('Empirical Challenge 2: Playback Position Recovery Tolerance (<= 250ms vs > 250ms)', () {
    late DecoderPipelineService service;
    late FakeMpvPlatform fakePlatform;
    Duration? soughtTarget;
    int seekCallCount = 0;

    setUp(() async {
      fakePlatform = FakeMpvPlatform();
      service = DecoderPipelineService();
      soughtTarget = null;
      seekCallCount = 0;
      service.onCustomSeek = (target) async {
        seekCallCount++;
        soughtTarget = target;
      };
      await service.initialize(null, fakePlatform);
      await service.setMode(DecoderMode.hw);
    });

    tearDown(() {
      service.dispose();
    });

    test('Boundary: Drift == 0ms -> No re-seek triggered', () async {
      const original = Duration(seconds: 120);
      service.setCurrentPosition(original);

      // Active position remains exactly at saved position
      fakePlatform.onSetProperty = (prop, val) {
        if (prop == 'hwdec') {
          service.setCurrentPosition(original);
        }
      };

      await service.setMode(DecoderMode.hwPlus);

      expect(seekCallCount, 0);
      expect(soughtTarget, isNull);
      expect(service.lastSeekDriftMs, 0);
      expect(service.lastRestoredPosition, original);
    });

    test('Boundary: Drift == 50ms -> No re-seek triggered', () async {
      const original = Duration(seconds: 120);
      service.setCurrentPosition(original);

      fakePlatform.onSetProperty = (prop, val) {
        if (prop == 'hwdec') {
          service.setCurrentPosition(original + const Duration(milliseconds: 50));
        }
      };

      await service.setMode(DecoderMode.hwPlus);

      expect(seekCallCount, 0);
      expect(soughtTarget, isNull);
      expect(service.lastSeekDriftMs, 50);
      expect(service.lastRestoredPosition, original + const Duration(milliseconds: 50));
    });

    test('Boundary: Drift == 249ms -> No re-seek triggered', () async {
      const original = Duration(seconds: 120);
      service.setCurrentPosition(original);

      fakePlatform.onSetProperty = (prop, val) {
        if (prop == 'hwdec') {
          service.setCurrentPosition(original + const Duration(milliseconds: 249));
        }
      };

      await service.setMode(DecoderMode.hwPlus);

      expect(seekCallCount, 0);
      expect(soughtTarget, isNull);
      expect(service.lastSeekDriftMs, 249);
    });

    test('Boundary: Drift == 250ms (EXACT TOLERANCE) -> No re-seek triggered', () async {
      const original = Duration(seconds: 120);
      service.setCurrentPosition(original);

      fakePlatform.onSetProperty = (prop, val) {
        if (prop == 'hwdec') {
          service.setCurrentPosition(original + const Duration(milliseconds: 250));
        }
      };

      await service.setMode(DecoderMode.hwPlus);

      // Drift <= 250ms: MUST NOT re-seek (avoids unnecessary seek jitter)
      expect(seekCallCount, 0);
      expect(soughtTarget, isNull);
      expect(service.lastSeekDriftMs, 250);
    });

    test('Boundary: Drift == 251ms (EXACT TOLERANCE + 1ms) -> MUST trigger re-seek', () async {
      const original = Duration(seconds: 120);
      service.setCurrentPosition(original);

      fakePlatform.onSetProperty = (prop, val) {
        if (prop == 'hwdec') {
          service.setCurrentPosition(original + const Duration(milliseconds: 251));
        }
      };

      await service.setMode(DecoderMode.hwPlus);

      // Drift > 250ms: MUST re-seek to restore original position
      expect(seekCallCount, 1);
      expect(soughtTarget, original);
      expect(service.lastRestoredPosition, original);
      expect(service.lastSeekDriftMs, 0); // Reset to 0 after re-seek
    });

    test('Boundary: Large forward drift (e.g. 5000ms) -> MUST trigger re-seek', () async {
      const original = Duration(seconds: 300);
      service.setCurrentPosition(original);

      fakePlatform.onSetProperty = (prop, val) {
        if (prop == 'hwdec') {
          service.setCurrentPosition(original + const Duration(milliseconds: 5000));
        }
      };

      await service.triggerFallback('Frame drop fallback with large forward jump');

      expect(seekCallCount, 1);
      expect(soughtTarget, original);
      expect(service.lastRestoredPosition, original);
      expect(service.lastSeekDriftMs, 0);
    });

    test('Boundary: Negative drift <= 250ms (e.g. -250ms) -> No re-seek triggered', () async {
      const original = Duration(seconds: 120);
      service.setCurrentPosition(original);

      fakePlatform.onSetProperty = (prop, val) {
        if (prop == 'hwdec') {
          service.setCurrentPosition(original - const Duration(milliseconds: 250));
        }
      };

      await service.setMode(DecoderMode.hwPlus);

      expect(seekCallCount, 0);
      expect(soughtTarget, isNull);
      expect(service.lastSeekDriftMs, 250);
    });

    test('Boundary: Negative drift > 250ms (e.g. stream resets to 0 from 45s) -> MUST trigger re-seek', () async {
      const original = Duration(seconds: 45);
      service.setCurrentPosition(original);

      // Stream reset to 0 upon decoder reconfiguration
      fakePlatform.onSetProperty = (prop, val) {
        if (prop == 'hwdec') {
          service.setCurrentPosition(Duration.zero);
        }
      };

      await service.triggerFallback('HEVC decode error at 45s');

      // 45000ms drift > 250ms -> MUST re-seek back to 45s
      expect(seekCallCount, 1);
      expect(soughtTarget, original);
      expect(service.lastRestoredPosition, original);
      expect(service.lastSeekDriftMs, 0);
    });

    test('Boundary: Saved position is Duration.zero -> No re-seek triggered even if position changed', () async {
      service.setCurrentPosition(Duration.zero);

      fakePlatform.onSetProperty = (prop, val) {
        if (prop == 'hwdec') {
          service.setCurrentPosition(const Duration(milliseconds: 1000));
        }
      };

      await service.setMode(DecoderMode.hwPlus);

      // savedPosition == Duration.zero -> no re-seek to 0
      expect(seekCallCount, 0);
      expect(soughtTarget, isNull);
    });
  });
}
