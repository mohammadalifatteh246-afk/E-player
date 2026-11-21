/// Audio device endpoint model (VLC audio-device parity).
class AudioDeviceEndpoint {
  final String id;
  final String name;
  final String description;
  final bool isDefault;
  final bool isBluetooth;
  final bool isUsb;

  const AudioDeviceEndpoint({
    required this.id,
    required this.name,
    required this.description,
    this.isDefault = false,
    this.isBluetooth = false,
    this.isUsb = false,
  });

  factory AudioDeviceEndpoint.auto() {
    return const AudioDeviceEndpoint(
      id: 'auto',
      name: 'Default System Device',
      description: 'Automatic OS audio device routing',
      isDefault: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'isDefault': isDefault,
        'isBluetooth': isBluetooth,
        'isUsb': isUsb,
      };

  factory AudioDeviceEndpoint.fromJson(Map<String, dynamic> json) {
    return AudioDeviceEndpoint(
      id: json['id'] as String? ?? 'auto',
      name: json['name'] as String? ?? 'Default Device',
      description: json['description'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
      isBluetooth: json['isBluetooth'] as bool? ?? false,
      isUsb: json['isUsb'] as bool? ?? false,
    );
  }
}

/// Dual Audio routing modes.
enum DualAudioRoutingMode {
  /// Mirror / duplicate the same audio stream to both devices with separate volume
  mirrorDuplicate('Mirror Duplicate', 'Stream identical audio to two soundcards / Bluetooth devices'),

  /// Route distinct audio tracks (e.g. Original Track to Speakers, Dubbed track to Headphones)
  dualTrackDubbing('Dual-Track Dubbing', 'Route Primary track to Device 1 and Secondary dubbed track to Device 2');

  final String label;
  final String description;

  const DualAudioRoutingMode(this.label, this.description);
}

/// Configuration for Dual Audio Output & Dubbing (VLC parity).
class DualAudioConfig {
  bool enabled;
  String primaryDeviceId;
  String? secondaryDeviceId;
  DualAudioRoutingMode routingMode;
  double primaryVolume; // 0.0 to 200.0 (default 100.0)
  double secondaryVolume; // 0.0 to 200.0 (default 100.0)
  double secondaryDelayMs; // -1000.0 to +1000.0 ms (Bluetooth sync)
  String? secondaryTrackId;
  bool isSecondaryMuted;

  DualAudioConfig({
    this.enabled = false,
    this.primaryDeviceId = 'auto',
    this.secondaryDeviceId,
    this.routingMode = DualAudioRoutingMode.mirrorDuplicate,
    this.primaryVolume = 100.0,
    this.secondaryVolume = 100.0,
    this.secondaryDelayMs = 0.0,
    this.secondaryTrackId,
    this.isSecondaryMuted = false,
  });

  DualAudioConfig copyWith({
    bool? enabled,
    String? primaryDeviceId,
    String? secondaryDeviceId,
    DualAudioRoutingMode? routingMode,
    double? primaryVolume,
    double? secondaryVolume,
    double? secondaryDelayMs,
    String? secondaryTrackId,
    bool? isSecondaryMuted,
  }) {
    return DualAudioConfig(
      enabled: enabled ?? this.enabled,
      primaryDeviceId: primaryDeviceId ?? this.primaryDeviceId,
      secondaryDeviceId: secondaryDeviceId ?? this.secondaryDeviceId,
      routingMode: routingMode ?? this.routingMode,
      primaryVolume: primaryVolume ?? this.primaryVolume,
      secondaryVolume: secondaryVolume ?? this.secondaryVolume,
      secondaryDelayMs: secondaryDelayMs ?? this.secondaryDelayMs,
      secondaryTrackId: secondaryTrackId ?? this.secondaryTrackId,
      isSecondaryMuted: isSecondaryMuted ?? this.isSecondaryMuted,
    );
  }

  void reset() {
    enabled = false;
    primaryDeviceId = 'auto';
    secondaryDeviceId = null;
    routingMode = DualAudioRoutingMode.mirrorDuplicate;
    primaryVolume = 100.0;
    secondaryVolume = 100.0;
    secondaryDelayMs = 0.0;
    secondaryTrackId = null;
    isSecondaryMuted = false;
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'primaryDeviceId': primaryDeviceId,
        'secondaryDeviceId': secondaryDeviceId,
        'routingMode': routingMode.name,
        'primaryVolume': primaryVolume,
        'secondaryVolume': secondaryVolume,
        'secondaryDelayMs': secondaryDelayMs,
        'secondaryTrackId': secondaryTrackId,
        'isSecondaryMuted': isSecondaryMuted,
      };

  factory DualAudioConfig.fromJson(Map<String, dynamic> json) {
    return DualAudioConfig(
      enabled: json['enabled'] as bool? ?? false,
      primaryDeviceId: json['primaryDeviceId'] as String? ?? 'auto',
      secondaryDeviceId: json['secondaryDeviceId'] as String?,
      routingMode: json['routingMode'] != null
          ? DualAudioRoutingMode.values.firstWhere(
              (e) => e.name == json['routingMode'],
              orElse: () => DualAudioRoutingMode.mirrorDuplicate,
            )
          : DualAudioRoutingMode.mirrorDuplicate,
      primaryVolume: (json['primaryVolume'] as num?)?.toDouble() ?? 100.0,
      secondaryVolume: (json['secondaryVolume'] as num?)?.toDouble() ?? 100.0,
      secondaryDelayMs: (json['secondaryDelayMs'] as num?)?.toDouble() ?? 0.0,
      secondaryTrackId: json['secondaryTrackId'] as String?,
      isSecondaryMuted: json['isSecondaryMuted'] as bool? ?? false,
    );
  }
}
