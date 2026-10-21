import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_effects_config.dart';

/// Service responsible for orchestrating real-time video effects on the
/// underlying playback engine (libmpv via media_kit), maintaining hardware
/// vs software filter separation, latency hiding, and persistence.
class VideoEffectsService {
  static const String _prefsKey = 'eplayer_video_effects_config';

  Timer? _vfDebounceTimer;
  String _lastAppliedVf = '';
  bool _isDisposed = false;

  /// Applies the effects configuration to the [Player].
  ///
  /// Hardware-accelerated properties (contrast, brightness, saturation, gamma, hue)
  /// are applied synchronously with 0ms latency.
  /// Complex ffmpeg video filter graphs (vf) are debounced by default to prevent
  /// decoder pipeline stutters during slider scrubs.
  void apply(
    Player player,
    VideoEffectsConfig config, {
    bool immediateVf = false,
  }) {
    if (_isDisposed) return;
    try {
      final dynamic platform = player.platform;

      if (!config.masterEnabled) {
        // Master Bypass: Reset native properties and clear filter graph
        platform.setProperty('contrast', '0');
        platform.setProperty('brightness', '0');
        platform.setProperty('saturation', '0');
        platform.setProperty('gamma', '0');
        platform.setProperty('hue', '0');
        _cancelDebounce();
        if (_lastAppliedVf.isNotEmpty) {
          platform.setProperty('vf', '');
          _lastAppliedVf = '';
        }
        return;
      }

      // 1. Tier-1: Zero-latency Hardware Properties (VLC adjust.c parity)
      // MPV accepts integer values -100 to 100 for color grading
      platform.setProperty('contrast', config.contrast.round().toString());
      platform.setProperty('brightness', config.brightness.round().toString());
      platform.setProperty('saturation', config.saturation.round().toString());
      platform.setProperty('gamma', config.gamma.round().toString());
      platform.setProperty('hue', config.mpvHue.toString());

      // 2. Tier-2: libmpv Video Filter Pipeline (vf)
      final vfString = config.buildMpvVfString();

      if (immediateVf) {
        _cancelDebounce();
        if (vfString != _lastAppliedVf) {
          platform.setProperty('vf', vfString);
          _lastAppliedVf = vfString;
        }
      } else {
        _scheduleVfUpdate(platform, vfString);
      }
    } catch (e) {
      debugPrint('[VideoEffectsService] Error applying video effects: $e');
    }
  }

  void _scheduleVfUpdate(dynamic platform, String vfString) {
    _cancelDebounce();
    _vfDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (_isDisposed) return;
      try {
        if (vfString != _lastAppliedVf) {
          platform.setProperty('vf', vfString);
          _lastAppliedVf = vfString;
        }
      } catch (e) {
        debugPrint('[VideoEffectsService] Error in debounced vf apply: $e');
      }
    });
  }

  void _cancelDebounce() {
    if (_vfDebounceTimer?.isActive ?? false) {
      _vfDebounceTimer!.cancel();
      _vfDebounceTimer = null;
    }
  }

  /// Reset all effects in player to flat neutral defaults
  void reset(Player player) {
    try {
      _cancelDebounce();
      final dynamic platform = player.platform;
      platform.setProperty('contrast', '0');
      platform.setProperty('brightness', '0');
      platform.setProperty('saturation', '0');
      platform.setProperty('gamma', '0');
      platform.setProperty('hue', '0');
      platform.setProperty('vf', '');
      _lastAppliedVf = '';
    } catch (e) {
      debugPrint('[VideoEffectsService] Error resetting player effects: $e');
    }
  }

  /// Persist current configuration to local storage
  Future<void> saveToPreferences(VideoEffectsConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(config.toJson());
      await prefs.setString(_prefsKey, jsonStr);
    } catch (e) {
      debugPrint('[VideoEffectsService] Error saving preferences: $e');
    }
  }

  /// Load persisted configuration from local storage, returning defaults if absent
  Future<VideoEffectsConfig> loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        return VideoEffectsConfig.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[VideoEffectsService] Error loading preferences: $e');
    }
    return VideoEffectsConfig();
  }

  /// Clean up timers and mark service disposed
  void dispose() {
    _isDisposed = true;
    _cancelDebounce();
  }
}
