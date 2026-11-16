import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/services/desktop_tray_audio_service.dart';

void main() {
  group('DesktopTrayAudioService Lifecycle & Command Dispatch Tests', () {
    late DesktopTrayAudioService trayService;

    setUp(() {
      trayService = DesktopTrayAudioService();
    });

    tearDown(() {
      trayService.dispose();
    });

    test('Initializes with default idle state', () {
      expect(trayService.currentState.isPlaying, isFalse);
      expect(trayService.currentState.mediaTitle, isEmpty);
      expect(trayService.currentState.volume, 100.0);
      expect(trayService.minimizeToTrayEnabled, isFalse);
      expect(trayService.currentState.isMinimizedToTray, isFalse);
    });

    test('Updates playback state and formats status string accurately', () {
      trayService.updatePlaybackState(
        isPlaying: true,
        mediaTitle: 'Blade Runner 2049.mkv',
        position: const Duration(minutes: 10),
        duration: const Duration(hours: 2, minutes: 43),
        volume: 125.0,
      );

      final state = trayService.currentState;
      expect(state.isPlaying, isTrue);
      expect(state.mediaTitle, 'Blade Runner 2049.mkv');
      expect(state.volume, 125.0);
      expect(state.position, const Duration(minutes: 10));
      expect(state.duration, const Duration(hours: 2, minutes: 43));
      expect(state.formattedStatus, 'Playing: Blade Runner 2049.mkv');
    });

    test('Dispatches tray transport commands to active listeners', () async {
      final receivedCommands = <TrayPlaybackCommand>[];
      final subscription = trayService.commandStream.listen(receivedCommands.add);

      trayService.dispatchCommand(TrayPlaybackCommand.playPause);
      trayService.dispatchCommand(TrayPlaybackCommand.volumeUp);
      trayService.dispatchCommand(TrayPlaybackCommand.toggleWindow);

      await pumpEventQueue();

      expect(receivedCommands, [
        TrayPlaybackCommand.playPause,
        TrayPlaybackCommand.volumeUp,
        TrayPlaybackCommand.toggleWindow,
      ]);

      await subscription.cancel();
    });

    test('Manages minimize to tray preference and window visibility flags', () {
      expect(trayService.minimizeToTrayEnabled, isFalse);

      trayService.setMinimizeToTray(true);
      expect(trayService.minimizeToTrayEnabled, isTrue);

      trayService.setMinimizedToTray(true);
      expect(trayService.currentState.isMinimizedToTray, isTrue);

      trayService.setMinimizedToTray(false);
      expect(trayService.currentState.isMinimizedToTray, isFalse);
    });

    test('Preserves state across partial updates without clobbering existing fields', () {
      trayService.updatePlaybackState(
        isPlaying: true,
        mediaTitle: 'Track01.flac',
        volume: 80.0,
      );

      // Partial update only changing position and volume
      trayService.updatePlaybackState(
        position: const Duration(seconds: 45),
        volume: 90.0,
      );

      expect(trayService.currentState.isPlaying, isTrue);
      expect(trayService.currentState.mediaTitle, 'Track01.flac');
      expect(trayService.currentState.volume, 90.0);
      expect(trayService.currentState.position, const Duration(seconds: 45));
    });
  });
}
