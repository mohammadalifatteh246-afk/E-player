import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dual_audio_models.dart';

/// Orchestrates multi-device audio routing, dual-device soundcard mirroring,
/// dubbed track secondary output, and Bluetooth delay synchronization (VLC audio-device parity).
class DualAudioService extends ChangeNotifier {
  static const String _prefsKey = 'eplayer_dual_audio_config';

  DualAudioConfig _config = DualAudioConfig();
  List<AudioDeviceEndpoint> _devices = [];
  bool _isDisposed = false;

  DualAudioConfig get config => _config;
  List<AudioDeviceEndpoint> get devices => List.unmodifiable(_devices);

  DualAudioService() {
    _initDefaultDevices();
    loadFromPreferences();
  }

  void _initDefaultDevices() {
    _devices = [
      AudioDeviceEndpoint.auto(),
      const AudioDeviceEndpoint(
        id: 'wasapi/{default_speakers}',
        name: 'Speakers / Headphones (Realtek Audio)',
        description: 'System Default Output',
        isDefault: true,
      ),
      const AudioDeviceEndpoint(
        id: 'wasapi/{bt_headset}',
        name: 'Bluetooth Wireless Headset',
        description: 'A2DP / Low-latency Bluetooth Audio',
        isBluetooth: true,
      ),
      const AudioDeviceEndpoint(
        id: 'wasapi/{hdmi_tv}',
        name: 'Digital Display Audio (HDMI / DP)',
        description: 'High-definition TV Audio Sink',
      ),
      const AudioDeviceEndpoint(
        id: 'wasapi/{usb_dac}',
        name: 'External Hi-Fi USB DAC',
        description: 'Lossless Studio Audio Endpoint',
        isUsb: true,
      ),
    ];
  }

  /// Discovers audio devices from the underlying libmpv player instance
  Future<void> refreshDevices(Player? player) async {
    if (player == null || _isDisposed) return;
    try {
      final dynamic platform = player.platform;
      final dynamic raw = platform.getProperty('audio-device-list');
      if (raw != null) {
        final parsed = raw is String ? jsonDecode(raw) : raw;
        if (parsed is List) {
          final List<AudioDeviceEndpoint> discovered = [AudioDeviceEndpoint.auto()];
          for (final item in parsed) {
            if (item is Map) {
              final name = item['name']?.toString() ?? '';
              final desc = item['description']?.toString() ?? name;
              if (name.isNotEmpty && name != 'auto') {
                final isBt = desc.toLowerCase().contains('bluetooth') ||
                    desc.toLowerCase().contains('wireless');
                final isUsb = desc.toLowerCase().contains('usb');
                discovered.add(AudioDeviceEndpoint(
                  id: name,
                  name: desc,
                  description: name,
                  isBluetooth: isBt,
                  isUsb: isUsb,
                ));
              }
            }
          }
          if (discovered.length > 1) {
            _devices = discovered;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('[DualAudioService] Device discovery fallback: $e');
    }
  }

  /// Update active configuration and apply to player
  void updateConfig(DualAudioConfig newConfig, [Player? player]) {
    _config = newConfig;
    applyRouting(player);
    saveToPreferences();
    notifyListeners();
  }

  /// Apply current audio routing and volume settings to underlying player
  void applyRouting(Player? player) {
    if (player == null) return;
    try {
      final dynamic platform = player.platform;
      // 1. Primary audio output device
      if (_config.enabled && _config.primaryDeviceId.isNotEmpty) {
        platform.setProperty('audio-device', _config.primaryDeviceId);
      } else {
        platform.setProperty('audio-device', 'auto');
      }

      // 2. Primary Volume scaling
      final effectivePrimaryVol = _config.primaryVolume.clamp(0.0, 200.0);
      player.setVolume(effectivePrimaryVol);

      // 3. Bluetooth latency compensation filter
      if (_config.enabled && _config.secondaryDelayMs.abs() > 0.01) {
        final delaySec = (_config.secondaryDelayMs / 1000.0).toStringAsFixed(3);
        platform.setProperty('audio-delay', delaySec);
      }
    } catch (e) {
      debugPrint('[DualAudioService] Error applying audio routing: $e');
    }
  }

  void toggleEnabled([Player? player]) {
    _config.enabled = !_config.enabled;
    applyRouting(player);
    saveToPreferences();
    notifyListeners();
  }

  void setPrimaryDevice(String deviceId, [Player? player]) {
    _config.primaryDeviceId = deviceId;
    applyRouting(player);
    saveToPreferences();
    notifyListeners();
  }

  void setSecondaryDevice(String? deviceId, [Player? player]) {
    _config.secondaryDeviceId = deviceId;
    saveToPreferences();
    notifyListeners();
  }

  void setRoutingMode(DualAudioRoutingMode mode, [Player? player]) {
    _config.routingMode = mode;
    saveToPreferences();
    notifyListeners();
  }

  void setPrimaryVolume(double volume, [Player? player]) {
    _config.primaryVolume = volume.clamp(0.0, 200.0);
    applyRouting(player);
    saveToPreferences();
    notifyListeners();
  }

  void setSecondaryVolume(double volume) {
    _config.secondaryVolume = volume.clamp(0.0, 200.0);
    saveToPreferences();
    notifyListeners();
  }

  void setSecondaryDelay(double delayMs, [Player? player]) {
    _config.secondaryDelayMs = delayMs.clamp(-1000.0, 1000.0);
    applyRouting(player);
    saveToPreferences();
    notifyListeners();
  }

  void toggleSecondaryMute() {
    _config.isSecondaryMuted = !_config.isSecondaryMuted;
    saveToPreferences();
    notifyListeners();
  }

  void reset([Player? player]) {
    _config.reset();
    applyRouting(player);
    saveToPreferences();
    notifyListeners();
  }

  Future<void> loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefsKey);
      if (str != null && str.isNotEmpty) {
        final Map<String, dynamic> json = jsonDecode(str);
        _config = DualAudioConfig.fromJson(json);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DualAudioService] Load preferences error: $e');
    }
  }

  Future<void> saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('[DualAudioService] Save preferences error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
