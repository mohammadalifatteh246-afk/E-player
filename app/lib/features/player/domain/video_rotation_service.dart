import 'package:flutter/services.dart';

enum ScreenOrientationMode {
  sensor,     // VLC Auto/Sensor: Follows accelerometer
  landscape,  // VLC Landscape Lock: Fixed to Landscape
  portrait,   // VLC Portrait Lock: Fixed to Portrait
  matchVideo, // VLC Smart Auto-Orient: Automatically matches video aspect ratio
}

/// Service managing screen orientation modes and video rotation
/// matching VLC media player's orientation and rotation mechanics.
class VideoRotationService {
  /// Applies a specific screen orientation mode
  static Future<void> applyOrientation(
    ScreenOrientationMode mode, {
    int? videoWidth,
    int? videoHeight,
  }) async {
    switch (mode) {
      case ScreenOrientationMode.sensor:
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
          DeviceOrientation.portraitUp,
        ]);
        break;
      case ScreenOrientationMode.landscape:
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        break;
      case ScreenOrientationMode.portrait:
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        break;
      case ScreenOrientationMode.matchVideo:
        if (videoWidth != null && videoHeight != null && videoHeight > videoWidth) {
          // Portrait video (vertical video / smartphone recording)
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
        } else {
          // Landscape widescreen video (default for movies/shows)
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
        break;
    }
  }

  /// Cycles to the next orientation mode (Sensor -> Landscape -> Portrait -> Sensor)
  static ScreenOrientationMode getNextMode(ScreenOrientationMode current) {
    switch (current) {
      case ScreenOrientationMode.sensor:
        return ScreenOrientationMode.landscape;
      case ScreenOrientationMode.landscape:
        return ScreenOrientationMode.portrait;
      case ScreenOrientationMode.portrait:
      case ScreenOrientationMode.matchVideo:
        return ScreenOrientationMode.sensor;
    }
  }

  /// Restores natural system orientation upon exiting player
  static Future<void> resetOrientation() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// Formats orientation mode for user display
  static String getModeLabel(ScreenOrientationMode mode) {
    switch (mode) {
      case ScreenOrientationMode.sensor:
        return 'Auto (Sensor)';
      case ScreenOrientationMode.landscape:
        return 'Landscape Lock';
      case ScreenOrientationMode.portrait:
        return 'Portrait Lock';
      case ScreenOrientationMode.matchVideo:
        return 'Match Video Aspect';
    }
  }

  /// Returns the next quarter turns (0 -> 1 -> 2 -> 3 -> 0)
  static int getNextQuarterTurns(int currentTurns) {
    return (currentTurns + 1) % 4;
  }

  /// Returns degree representation for quarter turns (0°, 90°, 180°, 270°)
  static int getRotationDegrees(int quarterTurns) {
    return ((quarterTurns % 4) + 4) % 4 * 90;
  }

  /// Determines if video is portrait aspect ratio
  static bool isPortraitVideo(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) return false;
    return height > width;
  }
}
