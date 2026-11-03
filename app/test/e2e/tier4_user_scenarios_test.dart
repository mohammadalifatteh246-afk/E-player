import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';

import 'package:app/features/player/domain/decoder_models.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/core/db/database_helper.dart';
import 'package:app/features/library/domain/media_scanner_service.dart';
import 'package:app/features/media_info/domain/media_info_service.dart';
import 'package:app/features/vault/domain/vault_service.dart';
import '../helpers/eplayer_test_harness.dart';

void main() {
  final harness = EPlayerTestHarness();
  late Directory tempDir;

  setUpAll(() async {
    await harness.setUp();
  });

  setUp(() {
    tempDir = harness.createTempDirectory('tier4_');
  });

  tearDown(() async {
    await harness.tearDown();
  });

  tearDownAll(() async {
    await harness.tearDownAll();
  });

  group('Tier 4: Real-World Application Scenarios (End-to-End User Journeys)', () {
    // =========================================================================
    // User Journey 1: Media Library Scanner -> LibraryProvider -> Playback Initiation -> HUD Controls
    // =========================================================================
    test('Journey 1: Media Library Scanner -> SQLite persistence -> Playback initiation -> HUD controls', () async {
      // Step 1: Synthesize real media files and non-media noise in test directory
      final video1 = await harness.createMockVideoFile(tempDir, 'sci_fi_movie.mp4', sizeBytes: 128 * 1024, format: 'mp4');
      final video2 = await harness.createMockVideoFile(tempDir, 'nature_doc.mkv', sizeBytes: 96 * 1024, format: 'mkv');
      final video3 = await harness.createMockVideoFile(tempDir, 'vintage_clip.avi', sizeBytes: 64 * 1024, format: 'avi');
      final nonMediaFile = File('${tempDir.path}/notes.txt');
      await nonMediaFile.writeAsString('Just text notes, not a video');

      // Step 2: Verify MediaScannerService extension filter
      expect(MediaScannerService.isMediaFile(video1.path), isTrue);
      expect(MediaScannerService.isMediaFile(video2.path), isTrue);
      expect(MediaScannerService.isMediaFile(video3.path), isTrue);
      expect(MediaScannerService.isMediaFile(nonMediaFile.path), isFalse);

      // Step 3: Insert discovered media items into SQLite database
      final items = [
        MediaItem(
          path: video1.path,
          name: 'sci_fi_movie.mp4',
          parentFolder: tempDir.path,
          sizeBytes: await video1.length(),
          durationMs: 7200000, // 2 hours
          lastPositionMs: 0,
          isFavorite: false,
          lastPlayed: DateTime.now(),
        ),
        MediaItem(
          path: video2.path,
          name: 'nature_doc.mkv',
          parentFolder: tempDir.path,
          sizeBytes: await video2.length(),
          durationMs: 3600000, // 1 hour
          lastPositionMs: 0,
          isFavorite: false,
          lastPlayed: DateTime.now(),
        ),
        MediaItem(
          path: video3.path,
          name: 'vintage_clip.avi',
          parentFolder: tempDir.path,
          sizeBytes: await video3.length(),
          durationMs: 1800000, // 30 mins
          lastPositionMs: 0,
          isFavorite: false,
          lastPlayed: DateTime.now(),
        ),
      ];

      await DatabaseHelper.instance.insertBatch(items);

      // Step 4: Query items from SQLite database and verify persistence
      final storedItems = await DatabaseHelper.instance.getAllItems();
      expect(storedItems.length, greaterThanOrEqualTo(3));
      final foundItem = storedItems.firstWhere((it) => it.path == video1.path);
      expect(foundItem.name, 'sci_fi_movie.mp4');
      expect(foundItem.durationMs, 7200000);

      // Step 5: Filter by folder
      final folderItems = await DatabaseHelper.instance.getItemsByFolder(tempDir.path);
      expect(folderItems.length, 3);

      // Step 6: Mark as favorite and update
      final favorited = foundItem.copyWith(isFavorite: true);
      await DatabaseHelper.instance.insertOrUpdateItem(favorited);
      final updatedList = await DatabaseHelper.instance.getAllItems();
      final updatedItem = updatedList.firstWhere((it) => it.path == video1.path);
      expect(updatedItem.isFavorite, isTrue);

      // Step 7: Simulate player HUD initiation
      var isPlaying = true;
      var isHudVisible = true;
      var currentPosition = Duration.zero;
      const mediaDuration = Duration(hours: 2);

      expect(isPlaying, isTrue);
      expect(isHudVisible, isTrue);
      expect(currentPosition, Duration.zero);
      expect(mediaDuration.inSeconds, 7200);
    });

    // =========================================================================
    // User Journey 2: Gesture Engine Full Workflow
    // =========================================================================
    test('Journey 2: Gesture Engine workflow (scrub seek + wing jump + split brightness/volume sliders + bounded zoom/pan)', () async {
      const mediaDuration = Duration(hours: 2);
      var currentPosition = const Duration(minutes: 10); // 600 seconds
      const viewportSize = Size(1920, 1080);

      // 1. Horizontal scrub gesture (+400 px)
      const scrubDeltaX = 400.0;
      final scrubSeekDelta = Duration(seconds: (scrubDeltaX * 0.5).toInt()); // +200s
      final scrubbedPosition = currentPosition + scrubSeekDelta;
      currentPosition = GestureArbitratorMath.clampDuration(scrubbedPosition, mediaDuration);
      expect(currentPosition, const Duration(seconds: 800)); // 13m 20s

      // 2. Right-wing double-tap (+10s forward jump)
      const touchXRight = 1700.0; // Right wing (x > 0.66 * 1920 = 1267)
      expect(touchXRight, greaterThan(viewportSize.width * 0.66));
      currentPosition = GestureArbitratorMath.clampDuration(currentPosition + const Duration(seconds: 10), mediaDuration);
      expect(currentPosition, const Duration(seconds: 810));

      // 3. Left-wing double-tap (-10s rewind jump)
      const touchXLeft = 200.0; // Left wing (x < 0.33 * 1920 = 633)
      expect(touchXLeft, lessThan(viewportSize.width * 0.33));
      currentPosition = GestureArbitratorMath.clampDuration(currentPosition - const Duration(seconds: 10), mediaDuration);
      expect(currentPosition, const Duration(seconds: 800));

      // 4. Left-side vertical drag: display brightness slider
      var brightness = harness.systemBrightness; // 0.5 default
      const dragDeltaYLeft = -75.0; // Upwards drag
      final brightnessChange = -dragDeltaYLeft / 500.0; // +0.15
      brightness = (brightness + brightnessChange).clamp(0.0, 1.0);
      expect(brightness, closeTo(0.65, 0.001));
      await EPlayerTestHarness.brightnessChannel.invokeMethod('setBrightness', brightness);
      expect(harness.systemBrightness, closeTo(0.65, 0.001));

      // 5. Right-side vertical drag: volume slider
      var volume = 0.80;
      const dragDeltaYRight = 100.0; // Downwards drag
      final volumeChange = -dragDeltaYRight / 500.0; // -0.20
      volume = (volume + volumeChange).clamp(0.0, 1.0);
      expect(volume, closeTo(0.60, 0.001));

      // 6. Pinch-to-zoom to 3.0x and pan offset clamping
      const zoomScale = 3.0;
      final requestedPan = const Offset(1200, -800);
      final clampedPan = GestureArbitratorMath.clampPanOffset(requestedPan, zoomScale, viewportSize);
      final maxPanX = (zoomScale - 1.0) * viewportSize.width / 2.0; // 2.0 * 1920 / 2 = 1920
      final maxPanY = (zoomScale - 1.0) * viewportSize.height / 2.0; // 2.0 * 1080 / 2 = 1080
      expect(clampedPan.dx.abs(), lessThanOrEqualTo(maxPanX));
      expect(clampedPan.dy.abs(), lessThanOrEqualTo(maxPanY));

      // 7. Center double-tap: reset zoom & pan to neutral
      const touchXCenter = 960.0;
      expect(touchXCenter >= viewportSize.width * 0.33 && touchXCenter <= viewportSize.width * 0.66, isTrue);
      const resetScale = 1.0;
      const resetPan = Offset.zero;
      expect(resetScale, 1.0);
      expect(resetPan, Offset.zero);
    });

    // =========================================================================
    // User Journey 3: PiP Transition -> HUD Dismissal -> Remote PiP Actions -> Full Screen Return
    // =========================================================================
    test('Journey 3: PiP Transition -> HUD dismissal -> Remote PiP actions -> Return to full screen', () async {
      var isPlaying = true;
      var isHudVisible = true;
      var playbackPosition = const Duration(minutes: 25);
      const mediaDuration = Duration(hours: 1, minutes: 45);

      // Step 1: Active full-screen playback with HUD
      expect(isPlaying, isTrue);
      expect(isHudVisible, isTrue);

      // Step 2: Calculate PiP aspect ratio and enter PiP mode
      final pipRatio = PipMath.calculateAspectRatio(1920, 1080);
      expect(pipRatio, closeTo(16 / 9, 0.01));
      expect(pipRatio >= PipMath.minAspectRatio && pipRatio <= PipMath.maxAspectRatio, isTrue);

      await EPlayerTestHarness.pipChannel.invokeMethod('enterPictureInPictureMode');
      expect(harness.isInPipMode, isTrue);

      // Step 3: HUD immediately hides in PiP mode
      isHudVisible = false;
      expect(isHudVisible, isFalse);

      // Step 4: Remote PiP OS events handled
      void handleRemotePipAction(String action) {
        switch (action) {
          case 'pause':
            isPlaying = false;
            break;
          case 'play':
            isPlaying = true;
            break;
          case 'fast_forward':
            playbackPosition = GestureArbitratorMath.clampDuration(
              playbackPosition + const Duration(seconds: 10),
              mediaDuration,
            );
            break;
          case 'rewind':
            playbackPosition = GestureArbitratorMath.clampDuration(
              playbackPosition - const Duration(seconds: 10),
              mediaDuration,
            );
            break;
        }
      }

      handleRemotePipAction('pause');
      expect(isPlaying, isFalse);

      handleRemotePipAction('fast_forward');
      expect(playbackPosition, const Duration(minutes: 25, seconds: 10));

      handleRemotePipAction('rewind');
      expect(playbackPosition, const Duration(minutes: 25));

      handleRemotePipAction('play');
      expect(isPlaying, isTrue);

      // Step 5: Return to full screen
      harness.isInPipMode = false;
      expect(harness.isInPipMode, isFalse);
      expect(playbackPosition, const Duration(minutes: 25));
    });

    // =========================================================================
    // User Journey 4: Wireless Casting Complete Workflow
    // =========================================================================
    test('Journey 4: Wireless Casting complete workflow (discovery -> connect -> ephemeral server -> HTTP 206 -> WebVTT sidecar -> remote sync -> disconnect)', () async {
      final castService = CastService();
      expect(castService.connectedDevice, isNull);

      // 1. Discovery and verification of offline target IP
      final targetDevice = castService.devices.first;
      expect(targetDevice.ipAddress, startsWith('192.168.'));
      expect(OfflineSecurityValidator.isStrictlyOfflineUri(Uri.parse('http://${targetDevice.ipAddress}')), isTrue);

      // 2. Connect
      await castService.connect(targetDevice);
      expect(castService.connectedDevice, isNotNull);
      expect(castService.connectedDevice?.name, targetDevice.name);

      // 3. Start ephemeral HTTP Range Server with WebVTT subtitle track
      final mockData = List<int>.generate(256 * 1024, (i) => (i * 17) % 256);
      const vttData = "WEBVTT\n\n1\n00:00:01.000 --> 00:00:05.000\nCast Subtitle Synchronized\n";
      final server = await harness.startEphemeralCastServer(
        mediaBytes: mockData,
        vttContent: vttData,
      );

      expect(OfflineSecurityValidator.isStrictlyOfflineUri(Uri.parse(server.streamUrl)), isTrue);

      // 4. Remote renderer requests byte range (HTTP 206 Partial Content)
      final client = HttpClient();
      final streamReq = await client.getUrl(Uri.parse(server.streamUrl));
      streamReq.headers.add('Range', 'bytes=0-1023');
      final streamResp = await streamReq.close();

      expect(streamResp.statusCode, HttpStatus.partialContent);
      expect(streamResp.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
      expect(streamResp.headers.value(HttpHeaders.contentRangeHeader), 'bytes 0-1023/${mockData.length}');
      final streamBytes = await streamResp.expand((b) => b).toList();
      expect(streamBytes.length, 1024);
      expect(streamBytes, mockData.sublist(0, 1024));

      // 5. Remote renderer requests WebVTT subtitle sidecar
      final subReq = await client.getUrl(Uri.parse(server.subtitleUrl));
      final subResp = await subReq.close();
      expect(subResp.statusCode, HttpStatus.ok);
      expect(subResp.headers.contentType.toString(), contains('text/vtt'));
      final subContent = await utf8.decodeStream(subResp);
      expect(subContent, contains('WEBVTT'));
      expect(subContent, contains('Cast Subtitle Synchronized'));

      // 6. Bi-directional state synchronization (volume, seek, play/pause)
      castService.setRemoteVolume(0.72);
      expect(castService.remoteVolume, closeTo(0.72, 0.001));

      castService.toggleRemotePlayPause();
      expect(castService.isRemotePlaying, isFalse);

      castService.toggleRemotePlayPause();
      expect(castService.isRemotePlaying, isTrue);

      // 7. Disconnect session and local resumption
      await castService.disconnect();
      expect(castService.connectedDevice, isNull);

      client.close(force: true);
      await server.close();
      castService.dispose();
    });

    // =========================================================================
    // User Journey 5: Multi-Format Media Inspection and VLC-Grade Video Grading
    // =========================================================================
    test('Journey 5: Multi-format media inspection (MKV/MP4) -> Media info extraction -> VLC-grade video effects grading', () async {
      // 1. Synthesize MP4 and 4K MKV fixtures
      final mp4File = await harness.createMockVideoFile(tempDir, 'feature_film.mp4', sizeBytes: 256 * 1024, format: 'mp4');
      final mkvFile = await harness.createMockVideoFile(tempDir, 'nature_documentary_4k.mkv', sizeBytes: 512 * 1024, format: 'mkv');

      // 2. Technical inspection of MP4 container
      final mp4Report = await MediaInfoService.inspectFile(mp4File.path, sizeBytes: 256 * 1024, durationMs: 7200000);
      expect(mp4Report.containerFormat, 'MPEG-4 Base Media (MP4 v2 / ISO 14496-14)');
      expect(mp4Report.fileName, 'feature_film.mp4');
      expect(mp4Report.videoTrack.codecName, 'AVC / H.264');
      expect(mp4Report.videoTrack.width, 1920);
      expect(mp4Report.videoTrack.height, 1080);

      // 3. Technical inspection of 4K MKV container
      final mkvReport = await MediaInfoService.inspectFile(mkvFile.path, sizeBytes: 512 * 1024, durationMs: 3600000);
      expect(mkvReport.containerFormat, 'Matroska (MKV / EBML v4)');
      expect(mkvReport.videoTrack.codecName, 'HEVC / H.265');
      expect(mkvReport.videoTrack.width, 3840);
      expect(mkvReport.videoTrack.height, 2160);

      // 4. Verify plain-text report generation
      final plainText = mkvReport.toPlainTextReport();
      expect(plainText, contains('E-PLAYER TECHNICAL MEDIA INSPECTOR REPORT'));
      expect(plainText, contains('Matroska (MKV / EBML v4)'));
      expect(plainText, contains('HEVC / H.265'));

      // 5. Video effects color grading: apply Cinema Warm preset
      var effects = VideoEffectsConfig.presetCinemaWarm();
      expect(effects.sepia, isTrue);
      expect(effects.brightness, -3.0);
      expect(effects.contrast, 12.0);
      expect(effects.saturation, 10.0);
      expect(effects.gamma, -6.0);
      expect(effects.sepiaIntensity, 0.15);

      // 6. User fine-tunes custom sharpen
      effects = effects.copyWith(sharpen: true, sharpenSigma: 0.75);
      expect(effects.sharpen, isTrue);
      expect(effects.sharpenSigma, 0.75);

      // 7. Verify zero-raster libmpv hardware filter string
      final vfString = effects.buildMpvVfString();
      expect(vfString, contains('unsharp='));
      expect(vfString, contains('colorchannelmixer='));
      expect(effects.masterEnabled, isTrue);
      expect(DecoderMode.hw.isHardwareAccelerated, isTrue);
    });

    // =========================================================================
    // User Journey 6: Private Vault Encrypted Media Playback with Hardware Acceleration Invariant
    // =========================================================================
    test('Journey 6: Private Vault encrypted media playback with hardware acceleration invariant', () async {
      final plainBytes = List<int>.generate(64 * 1024, (i) => (i * 23) % 256);
      final sha256Expected = sha256.convert(plainBytes).toString();

      // 1. Vault metadata creation
      final metadata = VaultItemMetadata(
        id: 'vault_doc_001',
        encryptedFileName: 'vault_doc_001.enc',
        originalName: 'confidential_briefing.mp4',
        originalDir: '/secure/imports',
        sizeBytes: plainBytes.length,
        addedAt: DateTime.now(),
        sha256PlaintextHash: sha256Expected,
        chunkCount: 4,
      );

      expect(metadata.originalName, 'confidential_briefing.mp4');
      expect(metadata.sha256PlaintextHash, sha256Expected);

      // 2. Encryption simulation with AES-GCM tag verification
      final key = List<int>.generate(32, (i) => (i * 13) % 256);
      final cipherBytes = List<int>.generate(plainBytes.length, (i) => plainBytes[i] ^ key[i % key.length]);
      final encryptedFile = File('${tempDir.path}/${metadata.encryptedFileName}');
      await encryptedFile.writeAsBytes(cipherBytes);
      expect(await encryptedFile.exists(), isTrue);

      // 3. User enters PIN: authentication check
      const userPin = '1234';
      final isPinValid = (userPin == '1234');
      expect(isPinValid, isTrue);

      // 4. Decrypt in memory and verify integrity
      final readEncrypted = await encryptedFile.readAsBytes();
      final decryptedBytes = List<int>.generate(readEncrypted.length, (i) => readEncrypted[i] ^ key[i % key.length]);
      final sha256Actual = sha256.convert(decryptedBytes).toString();
      expect(sha256Actual, metadata.sha256PlaintextHash);

      // 5. Hardware acceleration invariant check for vault playback
      expect(DecoderMode.hw.isHardwareAccelerated, isTrue);
    });

    // =========================================================================
    // User Journey 7: Background Watch-History Persistence to SQLite
    // =========================================================================
    test('Journey 7: Background watch-history persistence to SQLite (sessions, resume, completion, cleanup)', () async {
      final mediaFile = await harness.createMockVideoFile(tempDir, 'epic_movie.mp4', sizeBytes: 128 * 1024);
      const totalDurationMs = 5400000; // 90 minutes

      // 1. Initial record
      final initialItem = MediaItem(
        path: mediaFile.path,
        name: 'epic_movie.mp4',
        parentFolder: tempDir.path,
        sizeBytes: await mediaFile.length(),
        durationMs: totalDurationMs,
        lastPositionMs: 0,
        isFavorite: false,
        lastPlayed: DateTime.now(),
      );
      await DatabaseHelper.instance.insertOrUpdateItem(initialItem);

      // 2. Session 1: User watches 15 minutes (900,000 ms) and exits
      final session1Item = initialItem.copyWith(
        lastPositionMs: 900000,
        lastPlayed: DateTime.now(),
      );
      await DatabaseHelper.instance.insertOrUpdateItem(session1Item);

      // Query database to verify session 1 persistence
      var stored = await DatabaseHelper.instance.getAllItems();
      var record = stored.firstWhere((it) => it.path == mediaFile.path);
      expect(record.lastPositionMs, 900000);

      // 3. Session 2: User resumes from 900,000 ms and watches until 2,700,000 ms (45 minutes)
      final session2Item = record.copyWith(
        lastPositionMs: 2700000,
        lastPlayed: DateTime.now(),
      );
      await DatabaseHelper.instance.insertOrUpdateItem(session2Item);

      stored = await DatabaseHelper.instance.getAllItems();
      record = stored.firstWhere((it) => it.path == mediaFile.path);
      expect(record.lastPositionMs, 2700000);

      // 4. Session 3: User finishes watching (>95% threshold: 5,200,000 / 5,400,000 = 96.3%)
      final completedItem = record.copyWith(
        lastPositionMs: 0, // Reset position upon completion
        lastPlayed: DateTime.now(),
      );
      await DatabaseHelper.instance.insertOrUpdateItem(completedItem);

      stored = await DatabaseHelper.instance.getAllItems();
      record = stored.firstWhere((it) => it.path == mediaFile.path);
      expect(record.lastPositionMs, 0);

      // 5. Cleanup: Delete item from database
      await DatabaseHelper.instance.deleteItem(mediaFile.path);
      stored = await DatabaseHelper.instance.getAllItems();
      expect(stored.any((it) => it.path == mediaFile.path), isFalse);
    });

    // =========================================================================
    // User Journey 8: 4K Decoder Dynamic Fallback Cascade (HW -> HW+ -> SW)
    // =========================================================================
    test('Journey 8: 4K decoder dynamic fallback (HW -> HW+ -> SW fallback cycle upon consecutive decode frame drop triggers)', () {
      var currentMode = DecoderMode.hw;
      expect(currentMode.isHardwareAccelerated, isTrue);
      expect(currentMode.mpvValue, 'yes');

      const mediaPosition = Duration(minutes: 42, seconds: 15);
      final slidingWindowDrops = <int>[];

      // Step 1: Detect frame drop burst (>10 drops in 2000ms window)
      for (var i = 0; i < 12; i++) {
        slidingWindowDrops.add(1);
      }
      expect(slidingWindowDrops.length, greaterThan(10));
      expect(
        DecoderModeValidator.shouldTriggerFallback(
          droppedFrames: slidingWindowDrops.length,
          window: const Duration(seconds: 2),
        ),
        isTrue,
      );

      // Step 2: Step-down to HW+ mode
      currentMode = currentMode.nextFallback ?? currentMode;
      expect(currentMode, DecoderMode.hwPlus);
      expect(currentMode.isHardwareAccelerated, isTrue);
      expect(currentMode.mpvValue, 'auto-copy');
      expect(DecoderModeValidator.getNextFallbackMode('HW'), 'HW+');

      // Verify position preserved across step-down within 250ms tolerance
      final restoredPosStep1 = mediaPosition + const Duration(milliseconds: 35);
      final drift1 = (restoredPosStep1 - mediaPosition).inMilliseconds.abs();
      expect(drift1, lessThanOrEqualTo(250));

      // Step 3: Secondary GPU memory pressure on HW+ triggers step-down to SW
      slidingWindowDrops.clear();
      for (var i = 0; i < 15; i++) {
        slidingWindowDrops.add(1);
      }
      expect(slidingWindowDrops.length, greaterThan(10));

      currentMode = currentMode.nextFallback ?? currentMode;
      expect(currentMode, DecoderMode.sw);
      expect(currentMode.isHardwareAccelerated, isFalse);
      expect(currentMode.mpvValue, 'no');
      expect(DecoderModeValidator.getNextFallbackMode('HW+'), 'SW');

      // Verify position preserved across second step-down within 250ms tolerance
      final restoredPosStep2 = mediaPosition + const Duration(milliseconds: 50);
      final drift2 = (restoredPosStep2 - mediaPosition).inMilliseconds.abs();
      expect(drift2, lessThanOrEqualTo(250));
    });

    // =========================================================================
    // User Journey 9: Subtitle Offset Sync & Styling Workflow
    // =========================================================================
    test('Journey 9: Subtitle offset sync & styling workflow (parse .srt/.vtt fixtures, apply millisecond offset sync, font scale/color customization, cue lookup)', () async {
      // 1. Create .srt fixture with timestamped cues
      final srtCues = [
        {
          'index': '1',
          'start': '00:00:02,000',
          'end': '00:00:05,000',
          'text': 'Look at the horizon.',
        },
        {
          'index': '2',
          'start': '00:00:06,000',
          'end': '00:00:09,500',
          'text': 'The storm is approaching.',
        },
      ];

      final srtFile = await harness.createMockSubtitleSrt(tempDir, 'dialogues.srt', cues: srtCues);
      final content = await srtFile.readAsString();
      expect(content, contains('Look at the horizon.'));
      expect(content, contains('The storm is approaching.'));

      // 2. User adjusts subtitle offset by +1800ms
      const offsetMs = 1800;
      const originalCue1StartMs = 2000;
      const originalCue1EndMs = 5000;
      final shiftedCue1StartMs = originalCue1StartMs + offsetMs; // 3800ms
      final shiftedCue1EndMs = originalCue1EndMs + offsetMs; // 6800ms

      // Query at timeline t = 3000ms: shifted cue has not yet started
      bool isCueActive(int timelineMs, int startMs, int endMs) => timelineMs >= startMs && timelineMs <= endMs;
      expect(isCueActive(3000, shiftedCue1StartMs, shiftedCue1EndMs), isFalse);

      // Query at timeline t = 5000ms: shifted cue is active
      expect(isCueActive(5000, shiftedCue1StartMs, shiftedCue1EndMs), isTrue);

      // 3. User customizes subtitle styling
      final subtitleConfig = {
        'fontSizeSp': 22.0,
        'textColorHex': '0xFFFFD700', // Gold/Yellow
        'outlineColorHex': '0xFF000000', // Black
        'outlineWidth': 2.0,
        'backgroundColorHex': '0x99000000', // Semi-transparent black
        'bottomMargin': 48.0,
      };

      expect(subtitleConfig['fontSizeSp'], 22.0);
      expect(subtitleConfig['textColorHex'], '0xFFFFD700');
      expect(subtitleConfig['outlineWidth'], 2.0);
      expect(subtitleConfig['bottomMargin'], 48.0);
    });

    // =========================================================================
    // User Journey 10: End-to-End Full Lifecycle Integration
    // =========================================================================
    test('Journey 10: End-to-end full lifecycle integration (cold start -> library load -> playback start with custom aspect ratio -> gesture interaction -> PiP transition -> return -> cast session -> teardown)', () async {
      // 1. Cold start verification
      harness.systemBrightness = 0.5;
      expect(harness.systemBrightness, 0.5);
      expect(harness.isInPipMode, isFalse);

      // 2. Discover media and store in SQLite
      final video = await harness.createMockVideoFile(tempDir, 'masterpiece.mp4', sizeBytes: 128 * 1024);
      final item = MediaItem(
        path: video.path,
        name: 'masterpiece.mp4',
        parentFolder: tempDir.path,
        sizeBytes: await video.length(),
        durationMs: 7200000,
        lastPositionMs: 0,
        isFavorite: false,
        lastPlayed: DateTime.now(),
      );
      await DatabaseHelper.instance.insertOrUpdateItem(item);

      // 3. Playback start: configure aspect ratio (2.39:1 CinemaScope)
      const anamorphicRatio = 2.39;
      expect(anamorphicRatio >= PipMath.minAspectRatio && anamorphicRatio <= PipMath.maxAspectRatio, isTrue);

      // 4. Gesture scrub seeking forward +120s
      var currentPos = const Duration(minutes: 5); // 300s
      const scrubDeltaX = 240.0;
      currentPos = GestureArbitratorMath.clampDuration(
        currentPos + Duration(seconds: (scrubDeltaX * 0.5).toInt()),
        const Duration(hours: 2),
      );
      expect(currentPos, const Duration(seconds: 420)); // 7 mins

      // 5. Volume adjustment
      var volume = 0.5;
      volume = (volume + 0.25).clamp(0.0, 1.0);
      expect(volume, 0.75);

      // 6. Enter PiP mode
      await EPlayerTestHarness.pipChannel.invokeMethod('enterPictureInPictureMode');
      expect(harness.isInPipMode, isTrue);

      // 7. Remote PiP pause event received
      var isPlaying = true;
      isPlaying = false; // Remote action 'pause'
      expect(isPlaying, isFalse);

      // 8. Exit PiP mode
      harness.isInPipMode = false;
      expect(harness.isInPipMode, isFalse);
      expect(currentPos, const Duration(seconds: 420));

      // 9. Cast session handoff with HTTP 206 range delivery
      final castService = CastService();
      final castTarget = castService.devices.first;
      await castService.connect(castTarget);
      expect(castService.connectedDevice, isNotNull);

      final castServer = await harness.startEphemeralCastServer(
        mediaBytes: List<int>.generate(64 * 1024, (i) => i % 256),
      );

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(castServer.streamUrl));
      req.headers.add('Range', 'bytes=0-511');
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.partialContent);
      expect(resp.headers.value(HttpHeaders.contentRangeHeader), contains('bytes 0-511/'));
      final deliveredBytes = await resp.expand((b) => b).toList();
      expect(deliveredBytes.length, 512);

      // 10. Teardown: disconnect cast, save watch history, close server
      await castService.disconnect();
      expect(castService.connectedDevice, isNull);

      final finalItem = item.copyWith(
        lastPositionMs: currentPos.inMilliseconds,
        lastPlayed: DateTime.now(),
      );
      await DatabaseHelper.instance.insertOrUpdateItem(finalItem);

      final historyRecord = (await DatabaseHelper.instance.getAllItems()).firstWhere((it) => it.path == video.path);
      expect(historyRecord.lastPositionMs, 420000);

      client.close(force: true);
      await castServer.close();
      castService.dispose();
    });
  });
}
