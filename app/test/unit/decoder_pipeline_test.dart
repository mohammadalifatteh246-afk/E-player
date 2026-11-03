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
  group('DecoderMode Model & Enum Tests', () {
    test('Labels and libmpv option strings match specifications', () {
      expect(DecoderMode.auto.label, 'Auto');
      expect(DecoderMode.hw.label, 'HW');
      expect(DecoderMode.hwPlus.label, 'HW+');
      expect(DecoderMode.sw.label, 'SW');

      expect(DecoderMode.auto.mpvValue, 'auto');
      expect(DecoderMode.hw.mpvValue, 'yes');
      expect(DecoderMode.hwPlus.mpvValue, 'auto-copy');
      expect(DecoderMode.sw.mpvValue, 'no');
    });

    test('nextFallback cascade conforms to HW -> HW+ -> SW -> null', () {
      expect(DecoderMode.auto.nextFallback, DecoderMode.hwPlus);
      expect(DecoderMode.hw.nextFallback, DecoderMode.hwPlus);
      expect(DecoderMode.hwPlus.nextFallback, DecoderMode.sw);
      expect(DecoderMode.sw.nextFallback, isNull);
    });

    test('isHardwareAccelerated correctly identifies HW tiers', () {
      expect(DecoderMode.auto.isHardwareAccelerated, isTrue);
      expect(DecoderMode.hw.isHardwareAccelerated, isTrue);
      expect(DecoderMode.hwPlus.isHardwareAccelerated, isTrue);
      expect(DecoderMode.sw.isHardwareAccelerated, isFalse);
    });

    test('fromString parses various representations gracefully', () {
      expect(DecoderMode.fromString('Auto'), DecoderMode.auto);
      expect(DecoderMode.fromString('auto'), DecoderMode.auto);
      expect(DecoderMode.fromString('HW'), DecoderMode.hw);
      expect(DecoderMode.fromString('hardware'), DecoderMode.hw);
      expect(DecoderMode.fromString('yes'), DecoderMode.hw);
      expect(DecoderMode.fromString('HW+'), DecoderMode.hwPlus);
      expect(DecoderMode.fromString('hwplus'), DecoderMode.hwPlus);
      expect(DecoderMode.fromString('auto-copy'), DecoderMode.hwPlus);
      expect(DecoderMode.fromString('SW'), DecoderMode.sw);
      expect(DecoderMode.fromString('software'), DecoderMode.sw);
      expect(DecoderMode.fromString('no'), DecoderMode.sw);
      expect(DecoderMode.fromString(null), DecoderMode.auto);
      expect(DecoderMode.fromString('unknown_value'), DecoderMode.auto);
    });
  });

  group('DecoderTelemetry & DecoderSwitchResult Models', () {
    test('DecoderTelemetry immutability, fields, and activeMode deduction', () {
      const telemetryHw = DecoderTelemetry(
        requestedMode: DecoderMode.hw,
        activeDecoder: 'mediacodec',
        codec: 'hevc',
        droppedFrames: 3,
        fps: 59.94,
        bitrate: 15000000,
        width: 3840,
        height: 2160,
      );

      expect(telemetryHw.requestedMode, DecoderMode.hw);
      expect(telemetryHw.activeDecoder, 'mediacodec');
      expect(telemetryHw.codec, 'hevc');
      expect(telemetryHw.droppedFrames, 3);
      expect(telemetryHw.fps, 59.94);
      expect(telemetryHw.bitrate, 15000000);
      expect(telemetryHw.width, 3840);
      expect(telemetryHw.height, 2160);
      expect(telemetryHw.activeMode, DecoderMode.hw);
      expect(telemetryHw.isHardwareAccelerated, isTrue);

      const telemetryCopy = DecoderTelemetry(
        requestedMode: DecoderMode.hwPlus,
        activeDecoder: 'd3d11va-copy',
        codec: 'h264',
        droppedFrames: 0,
        fps: 60.0,
      );
      expect(telemetryCopy.activeMode, DecoderMode.hwPlus);

      const telemetrySw = DecoderTelemetry(
        requestedMode: DecoderMode.sw,
        activeDecoder: 'no',
        codec: 'av1',
        droppedFrames: 12,
        fps: 24.0,
      );
      expect(telemetrySw.activeMode, DecoderMode.sw);
      expect(telemetrySw.isHardwareAccelerated, isFalse);

      final copy = telemetryHw.copyWith(droppedFrames: 4);
      expect(copy.droppedFrames, 4);
      expect(copy.codec, 'hevc');
      expect(telemetryHw.toString(), contains('mediacodec'));
      expect(telemetryHw == copy, isFalse);
    });

    test('DecoderSwitchResult values and equality', () {
      const result = DecoderSwitchResult(
        success: true,
        activeMode: DecoderMode.hw,
        backend: 'yes',
        fallbackReason: null,
      );
      expect(result.success, isTrue);
      expect(result.activeMode, DecoderMode.hw);
      expect(result.backend, 'yes');
      expect(result.fallbackReason, isNull);
      expect(result.toString(), contains('DecoderSwitchResult'));

      const resultFail = DecoderSwitchResult(
        success: false,
        activeMode: DecoderMode.sw,
        backend: 'no',
        fallbackReason: 'Failed on hardware decode',
      );
      expect(resultFail.success, isFalse);
      expect(resultFail.fallbackReason, 'Failed on hardware decode');
      expect(result == resultFail, isFalse);
    });
  });

  group('DecoderPipelineService Manual Switching & Binding', () {
    late DecoderPipelineService service;
    late FakeMpvPlatform fakePlatform;

    setUp(() async {
      fakePlatform = FakeMpvPlatform();
      service = DecoderPipelineService();
      await service.initialize(null, fakePlatform);
    });

    tearDown(() {
      service.dispose();
    });

    test('Initializes with default Auto mode and dispatches hwdec=auto', () {
      expect(service.currentMode, DecoderMode.auto);
      expect(service.requestedMode, DecoderMode.auto);
      expect(fakePlatform.properties['hwdec'], 'auto');
      expect(service.isHardwareAccelerated, isTrue);
    });

    test('setMode(hw) sets hwdec=yes and updates active state', () async {
      fakePlatform.properties['hwdec-current'] = 'mediacodec';
      final result = await service.setMode(DecoderMode.hw);

      expect(result.success, isTrue);
      expect(result.activeMode, DecoderMode.hw);
      expect(fakePlatform.properties['hwdec'], 'yes');
      expect(service.currentMode, DecoderMode.hw);
      expect(service.activeDecoder, 'mediacodec');
      expect(service.isZeroCopyGpu, isTrue);
      expect(service.isHardwareAccelerated, isTrue);
    });

    test('setMode(hwPlus) sets hwdec=auto-copy and updates state', () async {
      fakePlatform.properties['hwdec-current'] = 'd3d11va-copy';
      final result = await service.setMode(DecoderMode.hwPlus);

      expect(result.success, isTrue);
      expect(result.activeMode, DecoderMode.hwPlus);
      expect(fakePlatform.properties['hwdec'], 'auto-copy');
      expect(service.currentMode, DecoderMode.hwPlus);
      expect(service.isCopyBackHw, isTrue);
      expect(service.isHardwareAccelerated, isTrue);
    });

    test('setMode(sw) sets hwdec=no and deactivates hardware acceleration', () async {
      fakePlatform.properties['hwdec-current'] = 'no';
      final result = await service.setMode(DecoderMode.sw);

      expect(result.success, isTrue);
      expect(result.activeMode, DecoderMode.sw);
      expect(fakePlatform.properties['hwdec'], 'no');
      expect(service.currentMode, DecoderMode.sw);
      expect(service.isHardwareAccelerated, isFalse);
    });
  });

  group('DecoderPipelineService Dynamic Fallback Cascade', () {
    late DecoderPipelineService service;
    late FakeMpvPlatform fakePlatform;

    setUp(() async {
      fakePlatform = FakeMpvPlatform();
      service = DecoderPipelineService();
      await service.initialize(null, fakePlatform);
    });

    tearDown(() {
      service.dispose();
    });

    test('Step-down cascade: HW -> HW+ -> SW -> Terminal SW', () async {
      // 1. Start in HW mode
      await service.setMode(DecoderMode.hw);
      expect(service.currentMode, DecoderMode.hw);

      // 2. First fallback (e.g. 4K 10-bit HEVC crash)
      final step1 = await service.triggerFallback('4K HEVC hardware decode failure');
      expect(step1.success, isTrue);
      expect(step1.activeMode, DecoderMode.hwPlus);
      expect(service.currentMode, DecoderMode.hwPlus);
      expect(fakePlatform.properties['hwdec'], 'auto-copy');
      expect(service.lastFallbackReason, '4K HEVC hardware decode failure');

      // 3. Second fallback (e.g. Excessive stutter on copy-back)
      final step2 = await service.triggerFallback('Severe stutter on 60fps copy-back');
      expect(step2.success, isTrue);
      expect(step2.activeMode, DecoderMode.sw);
      expect(service.currentMode, DecoderMode.sw);
      expect(fakePlatform.properties['hwdec'], 'no');

      // 4. Third fallback attempt from SW (terminal tier)
      final step3 = await service.triggerFallback('Software CPU overload');
      expect(step3.success, isFalse);
      expect(step3.activeMode, DecoderMode.sw);
      expect(service.currentMode, DecoderMode.sw);
      expect(service.lastFallbackReason, contains('Terminal decoder tier reached (SW)'));
      expect(service.fallbackAuditLog.length, 3);
    });

    test('Auto mode falls back to HW+ on failure', () async {
      expect(service.currentMode, DecoderMode.auto);
      final result = await service.triggerFallback('GPU probe failure in auto');
      expect(result.success, isTrue);
      expect(result.activeMode, DecoderMode.hwPlus);
      expect(service.currentMode, DecoderMode.hwPlus);
      expect(fakePlatform.properties['hwdec'], 'auto-copy');
    });

    test('handleDecodeError triggers fallback for hardware modes', () async {
      await service.setMode(DecoderMode.hw);
      expect(service.currentMode, DecoderMode.hw);

      await service.handleDecodeError('mpv: libva error: hardware surface allocation failed');
      expect(service.currentMode, DecoderMode.hwPlus);
      expect(service.lastFallbackReason, contains('Player decode error'));
    });
  });

  group('DecoderPipelineService Sliding Window Drop Monitoring', () {
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

    test('Does not trigger fallback when frame drops <= 10 in 2000ms', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      await service.recordFrameDropSample(0, timestamp: baseTime);
      await service.recordFrameDropSample(4, timestamp: baseTime.add(const Duration(milliseconds: 500)));
      await service.recordFrameDropSample(8, timestamp: baseTime.add(const Duration(milliseconds: 1200)));

      // 8 drops total in 1200ms (<= 10 threshold)
      expect(service.currentMode, DecoderMode.hw);
      expect(service.droppedFrames, 8);
    });

    test('Triggers automated fallback when drops > 10 in 2000ms window', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      await service.recordFrameDropSample(0, timestamp: baseTime);
      await service.recordFrameDropSample(5, timestamp: baseTime.add(const Duration(milliseconds: 600)));
      // Jumps to 16 drops (delta = 16 > 10 threshold)
      await service.recordFrameDropSample(16, timestamp: baseTime.add(const Duration(milliseconds: 1400)));

      // Must have automatically cascaded from HW -> HW+
      expect(service.currentMode, DecoderMode.hwPlus);
      expect(service.lastFallbackReason, contains('Excessive frame drops in 2000ms window'));
    });

    test('Old drops outside 2000ms window are pruned and do not false-trigger', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      // Sample at t=0s: 0 drops
      await service.recordFrameDropSample(0, timestamp: baseTime);
      // Sample at t=1s: 8 drops
      await service.recordFrameDropSample(8, timestamp: baseTime.add(const Duration(milliseconds: 1000)));
      // Sample at t=3.5s (2500ms after t=1s): 15 drops
      // The sample at t=0s and t=1s is older than 2000ms from t=3.5s!
      await service.recordFrameDropSample(15, timestamp: baseTime.add(const Duration(milliseconds: 3500)));

      // Delta within the active sliding window is 0 (only 1 sample left)
      expect(service.currentMode, DecoderMode.hw);
    });

    test('reportIncrementalDrops accumulates and triggers correctly', () async {
      final baseTime = DateTime(2026, 10, 22, 12, 0, 0);

      await service.recordFrameDropSample(0, timestamp: baseTime);
      await service.reportIncrementalDrops(6, timestamp: baseTime.add(const Duration(milliseconds: 400)));
      await service.reportIncrementalDrops(7, timestamp: baseTime.add(const Duration(milliseconds: 900)));

      // Total delta = 13 > 10 threshold
      expect(service.currentMode, DecoderMode.hwPlus);
    });
  });

  group('Playback Position Preservation & Tolerance Tests', () {
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

    test('Captures position and re-seeks when position drifts beyond 250ms', () async {
      Duration? soughtTarget;
      service.onCustomSeek = (target) async {
        soughtTarget = target;
      };

      // Set initial playing timestamp at 01:24:30 (5070 seconds)
      const targetPos = Duration(seconds: 5070);
      service.setCurrentPosition(targetPos);

      // Simulate that when decoder property switches, video stream reloads and position resets to 0
      fakePlatform.onSetProperty = (property, value) {
        if (property == 'hwdec') {
          service.setCurrentPosition(Duration.zero);
        }
      };

      // Trigger fallback to HW+
      await service.triggerFallback('Decode stutter at 01:24:30');

      // Verify captured saved position and successful re-seek
      expect(service.lastSavedPosition, targetPos);
      expect(soughtTarget, targetPos);
      expect(service.lastRestoredPosition, targetPos);
      expect(service.lastSeekDriftMs, lessThanOrEqualTo(250));
    });

    test('Tolerates minor position variation <= 250ms without unnecessary seek', () async {
      bool seekCalled = false;
      service.onCustomSeek = (target) async {
        seekCalled = true;
      };

      const originalPos = Duration(seconds: 100);
      service.setCurrentPosition(originalPos);

      // Minor drift within tolerance (e.g. 50ms)
      await service.setMode(DecoderMode.hwPlus);

      expect(seekCalled, isFalse);
      expect(service.lastSeekDriftMs, lessThanOrEqualTo(250));
    });
  });

  group('Telemetry Stream & Hardware Acceleration Invariant Tests', () {
    late DecoderPipelineService service;
    late FakeMpvPlatform fakePlatform;

    setUp(() async {
      fakePlatform = FakeMpvPlatform();
      service = DecoderPipelineService();
      await service.initialize(null, fakePlatform);
    });

    tearDown(() {
      service.dispose();
    });

    test('telemetryStream emits real-time updates upon configuration and drops', () async {
      final emitted = <DecoderTelemetry>[];
      final sub = service.telemetryStream.listen(emitted.add);

      service.setVideoCodec('av1');
      await service.setMode(DecoderMode.hw);
      service.reportIncrementalDrops(5);

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(emitted.isNotEmpty, isTrue);
      final latest = emitted.last;
      expect(latest.codec, 'av1');
      expect(latest.requestedMode, DecoderMode.hw);
      expect(latest.droppedFrames, 5);
      expect(service.currentTelemetry.codec, 'av1');
    });

    test('Offloads color adjustments and geometric filters directly to libmpv [INV-HW-002]', () async {
      expect(service.verifyHardwareOffload(), isTrue);

      await service.configureHardwareFilters(
        contrast: 15,
        brightness: -5,
        saturation: 20,
        gamma: 10,
        hue: 30,
        vf: 'hflip,vflip',
      );

      expect(fakePlatform.properties['contrast'], '15');
      expect(fakePlatform.properties['brightness'], '-5');
      expect(fakePlatform.properties['saturation'], '20');
      expect(fakePlatform.properties['gamma'], '10');
      expect(fakePlatform.properties['hue'], '30');
      expect(fakePlatform.properties['vf'], 'hflip,vflip');
    });
  });
}
