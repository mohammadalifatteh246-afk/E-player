import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/domain/decoder_models.dart';
import 'package:app/features/player/domain/decoder_pipeline_service.dart';

class MockFailingPlatform {
  bool failNext = false;
  final Map<String, String> properties = {};

  Future<void> setProperty(String property, String value) async {
    if (failNext) {
      failNext = false;
      throw Exception('Simulated native libmpv property failure');
    }
    properties[property] = value;
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }
}

void main() {
  group('Empirical Challenge 3: Adversarial Stress & Edge Cases', () {
    late DecoderPipelineService service;
    late MockFailingPlatform platform;

    setUp(() async {
      platform = MockFailingPlatform();
      service = DecoderPipelineService();
      await service.initialize(null, platform);
      await service.setMode(DecoderMode.hw);
    });

    tearDown(() {
      service.dispose();
    });

    test('Stress: Rapid concurrent frame drop reports do not corrupt history', () async {
      final baseTime = DateTime(2026, 10, 22, 14, 0, 0);

      // Fire 50 asynchronous drop reports with varying intervals
      final futures = <Future>[];
      for (int i = 1; i <= 50; i++) {
        final t = baseTime.add(Duration(milliseconds: i * 30));
        futures.add(service.recordFrameDropSample(i, timestamp: t));
      }

      await Future.wait(futures);

      // Must cleanly handle all events without throwing state errors
      expect(service.droppedFrames, 50);
      expect(service.isHardwareAccelerated, isTrue);
    });

    test('Adversarial: Non-monotonic / reset cumulative drop frame counts', () async {
      final baseTime = DateTime(2026, 10, 22, 14, 0, 0);

      // Sample 1: 100 drops at t=0
      await service.recordFrameDropSample(100, timestamp: baseTime);

      // Sample 2: Counter resets to 0 at t=500ms (e.g. video loop or mpv stream change)
      await service.recordFrameDropSample(0, timestamp: baseTime.add(const Duration(milliseconds: 500)));

      // Sample 3: Counter climbs to 5 at t=1000ms
      await service.recordFrameDropSample(5, timestamp: baseTime.add(const Duration(milliseconds: 1000)));

      // Delta between last (5) and first (100) is negative (-95), which is <= 10 -> MUST NOT trigger fallback
      expect(service.currentMode, DecoderMode.hw);
      expect(service.lastFallbackReason, isNull);
    });

    test('Adversarial: Platform setProperty failure is safely caught without throwing', () async {
      expect(service.currentMode, DecoderMode.hw);

      // Next setProperty will fail (e.g. GPU device lost or driver crashed)
      platform.failNext = true;

      // Must catch exception safely without crashing the service
      final result = await service.setMode(DecoderMode.hw, force: true);
      expect(result.success, isTrue);

      // When the native backend subsequently fires a decode error event, fallback triggers
      await service.handleDecodeError('Native hwdec init failure');
      expect(service.currentMode, DecoderMode.hwPlus);
      expect(service.lastFallbackReason, contains('Native hwdec init failure'));
    });

    test('Adversarial: Custom seek failure does not crash pipeline', () async {
      service.onCustomSeek = (target) async {
        throw Exception('Seek failed on corrupt media timestamp');
      };

      const targetPos = Duration(seconds: 40);
      service.setCurrentPosition(targetPos);

      platform.properties['hwdec-current'] = 'mediacodec';

      // Drift > 250ms triggers seek, which will throw exception
      service.setCurrentPosition(Duration.zero); // Reset to 0 simulates 40s drift

      // Must complete without unhandled exception propagating
      final res = await service.setMode(DecoderMode.hwPlus);
      expect(res.success, isTrue);
      expect(service.currentMode, DecoderMode.hwPlus);
    });

    test('Adversarial: Rapid consecutive fallbacks from HW directly to SW', () async {
      expect(service.currentMode, DecoderMode.hw);

      // Trigger 2 consecutive fallbacks
      final r1 = await service.triggerFallback('Error 1');
      expect(r1.activeMode, DecoderMode.hwPlus);

      final r2 = await service.triggerFallback('Error 2');
      expect(r2.activeMode, DecoderMode.sw);

      // SW is terminal
      final r3 = await service.triggerFallback('Error 3');
      expect(r3.success, isFalse);
      expect(r3.activeMode, DecoderMode.sw);
    });
  });
}
