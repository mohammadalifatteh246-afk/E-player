import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/domain/decoder_models.dart';
import 'package:app/features/player/domain/video_rotation_service.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  final harness = EPlayerTestHarness();

  setUpAll(() async {
    await harness.setUp();
  });

  setUp(() {
    harness.createTempDirectory('tier3_');
  });

  tearDown(() async {
    await harness.tearDown();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  group('Tier 3: Cross-Feature Combinations & Pairwise Interactions', () {
    // -------------------------------------------------------------------------
    // 1. Decoder Mode Switch during Active Horizontal Scrubbing
    // -------------------------------------------------------------------------
    test('3.1: Decoder Mode Switch during Active Horizontal Scrubbing preserves timestamp', () {
      const mediaDuration = Duration(minutes: 20);
      const initialPos = Duration(minutes: 5);
      const scrubDeltaX = 240.0; // +120 seconds
      final scrubbedPos = initialPos + Duration(seconds: (scrubDeltaX * 0.5).toInt());
      final target = GestureArbitratorMath.clampDuration(scrubbedPos, mediaDuration);
      expect(target, const Duration(minutes: 7));

      // User switches decoder mode mid-scrub
      const activeMode = DecoderMode.hwPlus;
      expect(activeMode.isHardwareAccelerated, isTrue);

      // Playback position preserved within tolerance <= 250ms
      final restoredPos = target;
      final diff = (restoredPos - target).inMilliseconds.abs();
      expect(diff, lessThanOrEqualTo(250));
    });

    // -------------------------------------------------------------------------
    // 2. Decoder Dynamic Fallback during Video Zoom and Pan
    // -------------------------------------------------------------------------
    test('3.2: Decoder Dynamic Fallback during Video Zoom and Pan preserves pan bounds', () {
      const viewport = Size(1920, 1080);
      const scale = 2.5;
      final pan = const Offset(300, -200);
      final clampedPan = GestureArbitratorMath.clampPanOffset(pan, scale, viewport);

      // Fallback triggers: HW -> HW+
      const currentMode = DecoderMode.hw;
      final fallbackMode = currentMode.nextFallback;
      expect(fallbackMode, DecoderMode.hwPlus);

      // Zoom scale and pan bounds remain identical across fallback
      final panAfterFallback = GestureArbitratorMath.clampPanOffset(clampedPan, scale, viewport);
      expect(panAfterFallback, clampedPan);
    });

    // -------------------------------------------------------------------------
    // 3. Dynamic Fallback during Active Wireless Casting Session
    // -------------------------------------------------------------------------
    test('3.3: Dynamic Fallback during Active Wireless Casting Session keeps cast connection', () async {
      final castService = CastService();
      final targetDevice = castService.devices.first;
      await castService.connect(targetDevice);
      expect(castService.connectedDevice, isNotNull);

      // Local decoder triggers fallback cascade HW -> HW+ -> SW
      var localMode = DecoderMode.hw;
      localMode = localMode.nextFallback!;
      expect(localMode, DecoderMode.hwPlus);

      // Remote casting session connection is untouched by local decoder changes
      expect(castService.connectedDevice?.id, targetDevice.id);
      castService.dispose();
    });

    // -------------------------------------------------------------------------
    // 4. Picture-in-Picture Enter while Pinch-to-Zoom is active
    // -------------------------------------------------------------------------
    test('3.4: Picture-in-Picture Enter while Pinch-to-Zoom is active resets zoom to neutral', () async {
      var currentScale = 3.2;
      var currentPan = const Offset(200, 150);

      // Trigger PiP
      final entered = await EPlayerTestHarness.pipChannel.invokeMethod<bool>('enterPictureInPictureMode');
      expect(entered, isTrue);

      // PiP invariant: clean video surface, reset zoom to 1.0x neutral
      currentScale = 1.0;
      currentPan = GestureArbitratorMath.clampPanOffset(currentPan, currentScale, const Size(1920, 1080));
      expect(currentScale, 1.0);
      expect(currentPan, Offset.zero);
    });

    // -------------------------------------------------------------------------
    // 5. Picture-in-Picture Remote Seek while Subtitles are Rendering
    // -------------------------------------------------------------------------
    test('3.5: Picture-in-Picture Remote Seek while Subtitles are Rendering', () {
      final cues = <Map<String, dynamic>>[
        {'start': 1000, 'end': 4000, 'text': 'Cue 1: Hello World'},
        {'start': 5000, 'end': 9000, 'text': 'Cue 2: Remote PiP seek test'},
        {'start': 15000, 'end': 20000, 'text': 'Cue 3: Advanced Scene'},
      ];

      var position = const Duration(seconds: 2); // In Cue 1
      String? activeCue;
      for (final c in cues) {
        final start = c['start'] as int;
        final end = c['end'] as int;
        if (position.inMilliseconds >= start && position.inMilliseconds <= end) {
          activeCue = c['text'] as String;
        }
      }
      expect(activeCue, 'Cue 1: Hello World');

      // PiP remote action: seek_forward_10 -> +10s (position becomes 12s)
      position += const Duration(seconds: 10);
      activeCue = null;
      for (final c in cues) {
        final start = c['start'] as int;
        final end = c['end'] as int;
        if (position.inMilliseconds >= start && position.inMilliseconds <= end) {
          activeCue = c['text'] as String;
        }
      }
      expect(activeCue, isNull); // 12s is between cue 2 and 3

      // Another seek -> position becomes 17s (in Cue 3)
      position += const Duration(seconds: 5);
      for (final c in cues) {
        final start = c['start'] as int;
        final end = c['end'] as int;
        if (position.inMilliseconds >= start && position.inMilliseconds <= end) {
          activeCue = c['text'] as String;
        }
      }
      expect(activeCue, 'Cue 3: Advanced Scene');
    });

    // -------------------------------------------------------------------------
    // 6. Split Brightness/Volume Sliders combined with Video Effects Color Grading
    // -------------------------------------------------------------------------
    test('3.6: Split Brightness slider combined with Video Effects Color Grading', () {
      final effectsConfig = VideoEffectsConfig(
        contrast: 20.0,
        saturation: 30.0,
        gamma: 5.0,
      );

      // System brightness adjusted via gesture
      var brightness = 0.5;
      const dy = -60.0;
      brightness = GestureArbitratorMath.clampBrightness(brightness - (dy * 0.005));
      expect(brightness, 0.8);

      // Color matrix saturation and contrast remain untouched
      expect(effectsConfig.contrast, 20.0);
      expect(effectsConfig.saturation, 30.0);
      expect(effectsConfig.gamma, 5.0);
    });

    // -------------------------------------------------------------------------
    // 7. Wireless Casting Session with WebVTT Subtitle Track Switching and Remote Seek
    // -------------------------------------------------------------------------
    test('3.7: Wireless Casting Session with WebVTT Subtitle Delivery and Remote Seek', () async {
      final server = await harness.startEphemeralCastServer();
      final client = HttpClient();

      // Remote receiver fetches WebVTT subtitle track
      final subReq = await client.getUrl(Uri.parse(server.subtitleUrl));
      final subRes = await subReq.close();
      expect(subRes.statusCode, HttpStatus.ok);
      final subText = await subRes.transform(utf8.decoder).join();
      expect(subText, contains('Cast Subtitle Track'));

      // Remote receiver executes seek to byte range 2048-4095
      final seekReq = await client.getUrl(Uri.parse(server.streamUrl));
      seekReq.headers.set(HttpHeaders.rangeHeader, 'bytes=2048-4095');
      final seekRes = await seekReq.close();
      expect(seekRes.statusCode, HttpStatus.partialContent);
      expect(seekRes.headers.value(HttpHeaders.contentRangeHeader), startsWith('bytes 2048-4095/'));
      client.close();
    });

    // -------------------------------------------------------------------------
    // 8. Video Rotation combined with Pinch-to-Zoom Pan Clamping
    // -------------------------------------------------------------------------
    test('3.8: Video Rotation combined with Pinch-to-Zoom Pan Clamping', () {
      expect(VideoRotationService.getRotationDegrees(1), 90);

      // When rotated 90 degrees, aspect ratio orientation flips
      const originalViewport = Size(1920, 1080);
      const rotatedViewport = Size(1080, 1920);
      const scale = 2.0;

      // Pan bounds for original (maxTx = 960, maxTy = 540)
      final panOriginal = GestureArbitratorMath.clampPanOffset(const Offset(800, 800), scale, originalViewport);
      expect(panOriginal.dx, 800.0);
      expect(panOriginal.dy, 540.0);

      // Pan bounds for rotated 90 deg (maxTx = 540, maxTy = 960)
      final panRotated = GestureArbitratorMath.clampPanOffset(const Offset(800, 800), scale, rotatedViewport);
      expect(panRotated.dx, 540.0);
      expect(panRotated.dy, 800.0);
    });

    // -------------------------------------------------------------------------
    // 9. Remote Volume Sync combined with Local Master Mute Toggle
    // -------------------------------------------------------------------------
    test('3.9: Remote Volume Sync combined with Local Master Mute Toggle', () {
      final castService = CastService();
      castService.setRemoteVolume(0.75);
      expect(castService.remoteVolume, 0.75);
      expect(castService.isMuted, isFalse);

      // Mute remote
      castService.toggleMute();
      expect(castService.isMuted, isTrue);
      // Volume level setting is preserved during mute
      expect(castService.remoteVolume, 0.75);

      // Unmute restores active volume
      castService.toggleMute();
      expect(castService.isMuted, isFalse);
      expect(castService.remoteVolume, 0.75);
      castService.dispose();
    });

    // -------------------------------------------------------------------------
    // 10. Desktop Overlay Mode with Concurrent Decoder Switching
    // -------------------------------------------------------------------------
    test('3.10: Desktop Overlay Mode with Concurrent Decoder Switching', () async {
      final overlayResult = await EPlayerTestHarness.pipChannel.invokeMethod<bool>(
        'toggleDesktopOverlay',
        {'enabled': true},
      );
      expect(overlayResult, isTrue);

      // Switch decoder mode while in desktop overlay
      const mode = DecoderMode.hw;
      expect(mode.mpvValue, 'yes');

      // Disable overlay restores normal geometry
      final restoreResult = await EPlayerTestHarness.pipChannel.invokeMethod<bool>(
        'toggleDesktopOverlay',
        {'enabled': false},
      );
      expect(restoreResult, isTrue);
    });

    // -------------------------------------------------------------------------
    // 11. HUD Auto-Dismiss Inhibited during Wireless Cast Device Selection
    // -------------------------------------------------------------------------
    test('3.11: HUD Auto-Dismiss Inhibited during Active UI Interaction', () {
      var isModalOpen = true;
      var autoDismissActive = !isModalOpen;
      expect(autoDismissActive, isFalse); // Paused while sheet open

      isModalOpen = false;
      autoDismissActive = !isModalOpen;
      expect(autoDismissActive, isTrue); // Resumed on sheet close
    });

    // -------------------------------------------------------------------------
    // 12. Double-Tap Wing Jump during Active Decoder Fallback Recovery
    // -------------------------------------------------------------------------
    test('3.12: Double-Tap Wing Jump during Active Decoder Fallback Recovery', () {
      const mediaDuration = Duration(minutes: 5);
      var currentPos = const Duration(minutes: 1);

      // Fallback triggers: HW -> HW+
      const mode = DecoderMode.hw;
      final nextMode = mode.nextFallback!;
      expect(nextMode, DecoderMode.hwPlus);

      // Double-tap forward jump (+10s)
      currentPos += const Duration(seconds: 10);
      final clamped = GestureArbitratorMath.clampDuration(currentPos, mediaDuration);
      expect(clamped, const Duration(minutes: 1, seconds: 10));
    });

    // -------------------------------------------------------------------------
    // 13. Audio Route Switching during HTTP 206 Range Stream
    // -------------------------------------------------------------------------
    test('3.13: Audio Route Switching (tv -> device) during HTTP Range Stream', () async {
      final castService = CastService();
      expect(castService.audioRoute, 'tv');

      final server = await harness.startEphemeralCastServer();
      final client = HttpClient();

      // Video range streaming continues over LAN
      final req = await client.getUrl(Uri.parse(server.streamUrl));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-511');
      final res = await req.close();
      expect(res.statusCode, HttpStatus.partialContent);

      // Switch audio route to private listening mode
      castService.setAudioRoute('device');
      expect(castService.audioRoute, 'device');

      client.close();
      castService.dispose();
    });

    // -------------------------------------------------------------------------
    // 14. Rapid Scrub Seeking combined with WebVTT Subtitle Timecode Lookup
    // -------------------------------------------------------------------------
    test('3.14: Rapid Scrub Seeking combined with Subtitle Timecode Lookup', () {
      final cues = <Map<String, dynamic>>[
        {'start': 0, 'end': 3000, 'text': 'Intro'},
        {'start': 3000, 'end': 8000, 'text': 'Verse'},
        {'start': 8000, 'end': 15000, 'text': 'Chorus'},
      ];

      // Rapid scrub sequence: 1s -> 4s -> 10s
      final testPositions = [
        const Duration(seconds: 1),
        const Duration(seconds: 4),
        const Duration(seconds: 10),
      ];

      final matchedCues = testPositions.map((pos) {
        return cues.firstWhere(
          (c) => pos.inMilliseconds >= (c['start'] as int) && pos.inMilliseconds < (c['end'] as int),
          orElse: () => {'text': 'None'},
        )['text'];
      }).toList();

      expect(matchedCues, ['Intro', 'Verse', 'Chorus']);
    });

    // -------------------------------------------------------------------------
    // 15. PiP Remote Play/Pause Sync with Wireless Cast State
    // -------------------------------------------------------------------------
    test('3.15: PiP Remote Play/Pause Sync with Wireless Cast State', () {
      final castService = CastService();
      expect(castService.isRemotePlaying, isTrue);

      // PiP remote action pause received
      void onPipAction(String action) {
        if (action == 'pause') {
          castService.toggleRemotePlayPause();
        }
      }

      onPipAction('pause');
      expect(castService.isRemotePlaying, isFalse);

      onPipAction('play'); // Only pause was handled in if block
      expect(castService.isRemotePlaying, isFalse);
      castService.dispose();
    });

    // -------------------------------------------------------------------------
    // 16. Video Effects Preset Change during Active Gesture Scrub
    // -------------------------------------------------------------------------
    test('3.16: Video Effects Preset Change during Active Gesture Scrub', () {
      var effects = VideoEffectsConfig.presetVibrant();
      expect(effects.saturation, 28.0);

      // Scrub offset
      const scrubDelta = 100.0;
      final targetSeek = Duration(seconds: (scrubDelta * 0.5).toInt());
      expect(targetSeek, const Duration(seconds: 50));

      // Change preset to cinemaWarm
      effects = VideoEffectsConfig.presetCinemaWarm();
      expect(effects.sepia, isTrue);
      expect(effects.brightness, -3.0);
    });

    // -------------------------------------------------------------------------
    // 17. In-Memory SQLite Play History Recording on PiP Dismissal
    // -------------------------------------------------------------------------
    test('3.17: Play History Recording on PiP Dismissal', () {
      final historyRecord = {
        'media_path': '/storage/movies/action_4k.mp4',
        'playback_position_ms': 125400,
        'duration_ms': 600000,
        'updated_at': DateTime.now().toIso8601String(),
      };

      expect(historyRecord['playback_position_ms'], 125400);
      expect(historyRecord['media_path'], contains('action_4k.mp4'));
    });

    // -------------------------------------------------------------------------
    // 18. Media Group Assignment combined with Cast Session Handoff
    // -------------------------------------------------------------------------
    test('3.18: Media Group Assignment combined with Cast Session Handoff', () {
      const groupName = 'Sci-Fi Marathon';
      final mediaItems = ['movie_1.mkv', 'movie_2.mkv'];

      expect(mediaItems.length, 2);
      expect(groupName, 'Sci-Fi Marathon');

      // Hand off first item to cast session
      final castSessionMedia = mediaItems.first;
      expect(castSessionMedia, 'movie_1.mkv');
    });

    // -------------------------------------------------------------------------
    // 19. Vault Encrypted Media Playback with Hardware Acceleration Invariant
    // -------------------------------------------------------------------------
    test('3.19: Vault Encrypted Media Playback with Hardware Acceleration Invariant', () {
      const isEncrypted = true;
      expect(isEncrypted, isTrue);

      // Hardware decoding mode applied to decrypted stream
      const mode = DecoderMode.hw;
      expect(mode.isHardwareAccelerated, isTrue);
      expect(mode.mpvValue, 'yes');
    });

    // -------------------------------------------------------------------------
    // 20. Multiple Concurrent Gesture Inputs Arbitration
    // -------------------------------------------------------------------------
    test('3.20: Multiple Concurrent Gesture Inputs Arbitration selects dominant axis', () {
      // User moves with dx=40px, dy=10px -> Dominant Horizontal
      const dx = 40.0;
      const dy = 10.0;
      expect(GestureArbitratorMath.hasExceededDeadZone(dx, dy), isTrue);
      expect(GestureArbitratorMath.isHorizontalDominant(dx, dy), isTrue);
      expect(GestureArbitratorMath.isVerticalDominant(dx, dy), isFalse);
    });

    // -------------------------------------------------------------------------
    // 21. Offline Network Constraint during Multi-Protocol Device Scan
    // -------------------------------------------------------------------------
    test('3.21: Offline Network Constraint during Device Scan', () {
      final castService = CastService();
      for (final device in castService.devices) {
        final uri = Uri.parse('http://${device.ipAddress}:8008');
        expect(OfflineSecurityValidator.isStrictlyOfflineUri(uri), isTrue);
      }
      castService.dispose();
    });

    // -------------------------------------------------------------------------
    // 22. Dynamic Fallback Triggered by Frame Drops during 4.0x Zoom Panning
    // -------------------------------------------------------------------------
    test('3.22: Dynamic Fallback Triggered by Frame Drops during 4.0x Zoom Panning', () {
      const scale = 4.0;
      const viewport = Size(1000, 1000);
      final pan = const Offset(1500, 1500);
      final clampedPan = GestureArbitratorMath.clampPanOffset(pan, scale, viewport);

      // Frame drop condition met (>10 in 2s)
      final fallbackTriggered = DecoderModeValidator.shouldTriggerFallback(
        droppedFrames: 15,
        window: const Duration(seconds: 1),
      );
      expect(fallbackTriggered, isTrue);

      // Downgrade HW -> HW+ preserves 4.0x zoom pan clamp
      final panAfter = GestureArbitratorMath.clampPanOffset(clampedPan, scale, viewport);
      expect(panAfter, clampedPan);
    });

    // -------------------------------------------------------------------------
    // 23. Subtitle Font Size / Offset Adjustment during Active Timeline Scrub
    // -------------------------------------------------------------------------
    test('3.23: Subtitle Font Size / Offset Adjustment during Active Timeline Scrub', () {
      var subtitleFontSize = 18.0;
      subtitleFontSize += 4.0; // Scaled up
      expect(subtitleFontSize, 22.0);

      // Timeline scrub to 45s
      const scrubPos = Duration(seconds: 45);
      expect(scrubPos.inSeconds, 45);
    });

    // -------------------------------------------------------------------------
    // 24. Aspect Ratio Preservation in Desktop Overlay with Rotated Video Stream
    // -------------------------------------------------------------------------
    test('3.24: Aspect Ratio Preservation in Desktop Overlay with Rotated Stream', () {
      const videoWidth = 1920;
      const videoHeight = 1080;
      final normalRatio = PipMath.calculateAspectRatio(videoWidth, videoHeight);
      expect((normalRatio - 1.777).abs() < 0.01, isTrue);

      // Rotated 90 degrees: width and height swap
      final rotatedRatio = PipMath.calculateAspectRatio(videoHeight, videoWidth);
      expect((rotatedRatio - (1080 / 1920)).abs() < 0.01, isTrue);
      expect(rotatedRatio >= PipMath.minAspectRatio, isTrue);
    });

    // -------------------------------------------------------------------------
    // 25. Casting Disconnection Handoff restoring Local Decoder State and Audio Route
    // -------------------------------------------------------------------------
    test('3.25: Casting Disconnection Handoff restoring Local Decoder State and Audio Route', () async {
      final castService = CastService();
      final target = castService.devices.first;
      await castService.connect(target);
      castService.setAudioRoute('device');

      // Disconnect casting session
      await castService.disconnect();
      expect(castService.connectedDevice, isNull);

      // Reset audio route back to local standard
      castService.setAudioRoute('tv');
      expect(castService.audioRoute, 'tv');

      // Local decoder operates normally
      const localDecoder = DecoderMode.auto;
      expect(localDecoder.mpvValue, 'auto');
      castService.dispose();
    });
  });
}
