import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/telnet_rc/domain/telnet_rc_models.dart';
import 'package:app/features/telnet_rc/data/telnet_rc_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Telnet Remote Control Models (VLC rc.c Parity)', () {
    test('TelnetCommandLog serializes and deserializes accurately', () {
      final now = DateTime.now();
      final log = TelnetCommandLog(
        timestamp: now,
        direction: TelnetLogDirection.incoming,
        text: 'seek +30',
        clientAddress: '127.0.0.1:54321',
      );

      final json = log.toJson();
      expect(json['direction'], 'incoming');
      expect(json['text'], 'seek +30');
      expect(json['clientAddress'], '127.0.0.1:54321');

      final restored = TelnetCommandLog.fromJson(json);
      expect(restored.direction, TelnetLogDirection.incoming);
      expect(restored.text, 'seek +30');
      expect(restored.clientAddress, '127.0.0.1:54321');
    });

    test('TelnetPlayerSnapshot formats VLC rc.c parity status string', () {
      const snapshot = TelnetPlayerSnapshot(
        isPlaying: true,
        title: 'Cyberpunk_2077_OST.flac',
        position: Duration(minutes: 2, seconds: 15),
        duration: Duration(minutes: 5, seconds: 0),
        volume: 120.0,
      );

      final statusStr = snapshot.toVlcStatusString();
      expect(statusStr, contains('( state playing )'));
      expect(statusStr, contains('( title Cyberpunk_2077_OST.flac )'));
      expect(statusStr, contains('( position 135/300 [02:15/05:00] )'));
      expect(statusStr, contains('( volume 120% )'));
    });
  });

  group('TelnetRcService Direct Command Dispatching', () {
    late TelnetRcService service;
    late bool playCalled;
    late bool pauseCalled;
    late bool stopCalled;
    late Duration? seekTarget;
    late double? setVolumeVal;
    late bool stepFrameCalled;
    late bool fullscreenCalled;
    late String? addedMedia;
    late bool playImmediate;

    setUp(() {
      service = TelnetRcService();
      playCalled = false;
      pauseCalled = false;
      stopCalled = false;
      seekTarget = null;
      setVolumeVal = null;
      stepFrameCalled = false;
      fullscreenCalled = false;
      addedMedia = null;
      playImmediate = false;

      service.onPlay = () => playCalled = true;
      service.onPause = () => pauseCalled = true;
      service.onStop = () => stopCalled = true;
      service.onSeek = (t) => seekTarget = t;
      service.onSetVolume = (v) => setVolumeVal = v;
      service.onStepFrame = () => stepFrameCalled = true;
      service.onToggleFullscreen = () => fullscreenCalled = true;
      service.onAddMedia = (m, p) {
        addedMedia = m;
        playImmediate = p;
      };

      service.statusProvider = () => const TelnetPlayerSnapshot(
            isPlaying: true,
            title: 'Interstellar.mp4',
            position: Duration(minutes: 10), // 600s
            duration: Duration(hours: 2), // 7200s
            volume: 100.0,
            aspectRatio: '16:9',
            audioTrack: 'English 5.1',
            subtitleTrack: 'English',
          );
    });

    tearDown(() {
      service.dispose();
    });

    test('executes playback commands (play, pause, stop, is_playing)', () async {
      expect(await service.executeCommand('play'), 'status: playing');
      expect(playCalled, isTrue);

      expect(await service.executeCommand('pause'), 'status: paused');
      expect(pauseCalled, isTrue);

      expect(await service.executeCommand('stop'), 'status: stopped');
      expect(stopCalled, isTrue);

      expect(await service.executeCommand('is_playing'), '1');
    });

    test('executes query commands (get_time, get_length, get_title, status)', () async {
      expect(await service.executeCommand('get_time'), '600');
      expect(await service.executeCommand('get_length'), '7200');
      expect(await service.executeCommand('get_title'), 'Interstellar.mp4');

      final statusOutput = await service.executeCommand('status');
      expect(statusOutput, contains('( state playing )'));
      expect(statusOutput, contains('Interstellar.mp4'));
    });

    test('executes seek with absolute, relative, and percentage targets', () async {
      // Absolute seek 120s
      final replyAbs = await service.executeCommand('seek 120');
      expect(replyAbs, contains('02:00'));
      expect(seekTarget, const Duration(seconds: 120));

      // Relative seek +30s (600 + 30 = 630s)
      final replyRelPos = await service.executeCommand('seek +30');
      expect(replyRelPos, contains('10:30'));
      expect(seekTarget, const Duration(seconds: 630));

      // Relative seek -45s (600 - 45 = 555s)
      final replyRelNeg = await service.executeCommand('seek -45');
      expect(replyRelNeg, contains('09:15'));
      expect(seekTarget, const Duration(seconds: 555));

      // Percentage seek 50% of 7200s = 3600s (01:00:00)
      final replyPct = await service.executeCommand('seek 50%');
      expect(replyPct, contains('1:00:00'));
      expect(seekTarget, const Duration(seconds: 3600));
    });

    test('executes volume, volup, voldown with 300% boost limit', () async {
      // Query volume
      expect(await service.executeCommand('volume'), 'volume: 100%');

      // Set volume 250%
      expect(await service.executeCommand('volume 250'), 'volume: 250%');
      expect(setVolumeVal, 250.0);

      // Volume boost clamp at 300%
      expect(await service.executeCommand('volume 350'), 'volume: 300%');
      expect(setVolumeVal, 300.0);

      // volup with step 15 (100 + 15 = 115)
      expect(await service.executeCommand('volup 15'), 'volume: 115%');
      expect(setVolumeVal, 115.0);

      // voldown with default step 5 (100 - 5 = 95)
      expect(await service.executeCommand('voldown'), 'volume: 95%');
      expect(setVolumeVal, 95.0);
    });

    test('executes step, fullscreen, add, enqueue, playlist, help', () async {
      expect(await service.executeCommand('step'), 'step: advanced 1 frame');
      expect(stepFrameCalled, isTrue);

      expect(await service.executeCommand('fullscreen'), 'fullscreen: toggled');
      expect(fullscreenCalled, isTrue);

      expect(await service.executeCommand('add /movies/video.mkv'), 'added and playing: /movies/video.mkv');
      expect(addedMedia, '/movies/video.mkv');
      expect(playImmediate, isTrue);

      expect(await service.executeCommand('enqueue /music/song.mp3'), 'enqueued: /music/song.mp3');
      expect(addedMedia, '/music/song.mp3');
      expect(playImmediate, isFalse);

      final helpText = await service.executeCommand('help');
      expect(helpText, contains('+----[ VLC rc.c Remote Control CLI Commands ]'));
      expect(helpText, contains('seek <sec|+delta|-delta|pct%>'));
    });
  });

  group('TelnetRcService Real TCP Socket Lifecycle', () {
    late TelnetRcService service;

    setUp(() {
      service = TelnetRcService();
      service.statusProvider = () => const TelnetPlayerSnapshot(
            isPlaying: true,
            title: 'Matrix.mp4',
            position: Duration(seconds: 42),
            duration: Duration(minutes: 120),
            volume: 100.0,
          );
    });

    tearDown(() async {
      await service.stop();
      service.dispose();
    });

    test('Starts TCP server, accepts client, replies to CLI command, and disconnects on quit', () async {
      // Start server on dynamic loopback port
      final started = await service.start(preferredPort: 14212, loopbackOnly: true);
      expect(started, isTrue);
      expect(service.isRunning, isTrue);
      expect(service.status.port, greaterThanOrEqualTo(14212));

      // Connect real TCP client
      final clientSocket = await Socket.connect('127.0.0.1', service.status.port);
      expect(clientSocket, isNotNull);

      final receivedData = <String>[];
      final completerBanner = Completer<void>();
      final completerReply = Completer<void>();

      clientSocket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        receivedData.add(line);
        if (line.contains('Remote Control CLI Interface')) {
          if (!completerBanner.isCompleted) completerBanner.complete();
        }
        if (line.contains('( state playing )')) {
          if (!completerReply.isCompleted) completerReply.complete();
        }
      });

      // Wait for banner
      await completerBanner.future.timeout(const Duration(seconds: 3));
      expect(receivedData.any((l) => l.contains('E-Player v1.0')), isTrue);
      expect(service.activeClientsCount, 1);

      // Send status command
      clientSocket.write('status\r\n');
      await clientSocket.flush();

      // Wait for status reply
      await completerReply.future.timeout(const Duration(seconds: 3));
      expect(receivedData.any((l) => l.contains('( title Matrix.mp4 )')), isTrue);

      // Disconnect client
      clientSocket.write('quit\r\n');
      await clientSocket.flush();
      await Future.delayed(const Duration(milliseconds: 200));

      await clientSocket.close();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(service.activeClientsCount, 0);

      // Stop server
      await service.stop();
      expect(service.isRunning, isFalse);
    });
  });
}
