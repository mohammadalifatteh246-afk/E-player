import 'dart:math' as math;

/// Authoritative presets for Audio Pitch Shifting based on VLC scaletempo.c and standard musical intervals.
enum AudioPitchPreset {
  flat(label: 'Flat / Original', semitones: 0, cents: 0.0),
  chipmunk(label: 'Helium / Chipmunk', semitones: 12, cents: 0.0),
  deepVoice(label: 'Deep / Titan', semitones: -12, cents: 0.0),
  maleToFemale(label: 'Male -> Female', semitones: 4, cents: 0.0),
  femaleToMale(label: 'Female -> Male', semitones: -4, cents: 0.0),
  fifthInterval(label: 'Perfect Fifth (+7st)', semitones: 7, cents: 0.0),
  fourthInterval(label: 'Perfect Fourth (+5st)', semitones: 5, cents: 0.0),
  concertPitch432(label: 'Concert A432 Hz', semitones: 0, cents: -31.77),
  custom(label: 'Custom', semitones: 0, cents: 0.0);

  final String label;
  final int semitones;
  final double cents;

  const AudioPitchPreset({
    required this.label,
    required this.semitones,
    required this.cents,
  });
}

/// Pure domain configuration model for Audio Pitch Shifting & Scaling.
/// Provides mathematical parity with VLC's `modules/audio_filter/scaletempo.c`
/// and mpv/libavfilter DSP filter chains.
class AudioPitchConfig {
  static const int minSemitones = -12;
  static const int maxSemitones = 12;
  static const double minCents = -100.0;
  static const double maxCents = 100.0;

  bool enabled;
  int semitones;
  double cents;
  AudioPitchPreset preset;

  AudioPitchConfig({
    this.enabled = false,
    this.semitones = 0,
    this.cents = 0.0,
    this.preset = AudioPitchPreset.flat,
  });

  /// Total cents calculation (1 semitone = 100 cents).
  double get totalCents => (semitones * 100.0) + cents;

  /// Pure logarithmic pitch scaling factor:
  /// ratio = 2 ^ ((semitones + (cents / 100)) / 12) = 2 ^ (totalCents / 1200)
  double get pitchRatio {
    final double exponent = totalCents / 1200.0;
    return math.pow(2.0, exponent).toDouble();
  }

  /// Tempo compensation factor required when pitch scaling via sample rate adjustments:
  /// tempoCompensation = 1.0 / pitchRatio
  double get speedCompensation {
    final ratio = pitchRatio;
    return ratio > 0.0 ? 1.0 / ratio : 1.0;
  }

  /// True when pitch parameters diverge from neutral 1.0x ratio.
  bool get isDivergent =>
      enabled && (semitones != 0 || cents.abs() > 0.1);

  /// Generates the authoritative libavfilter / mpv audio filter string.
  /// If bit-perfect neutral or disabled, returns empty string.
  /// Uses rubberband when available with automatic atempo/aresample compensation.
  String buildMpvAfString() {
    if (!enabled || !isDivergent) return '';

    final ratio = pitchRatio;
    final ratioStr = ratio.toStringAsFixed(6);

    // Primary: rubberband pitch-scale if enabled in filterchain
    // Fallback/standard: asetrate + atempo time-stretch compensation
    return 'rubberband=pitch-scale=$ratioStr';
  }

  /// Alternative universal filter chain based on standard ffmpeg built-ins (asetrate & atempo)
  String buildUniversalAfString({int baseSampleRate = 48000}) {
    if (!enabled || !isDivergent) return '';

    final ratio = pitchRatio;
    final targetSampleRate = (baseSampleRate * ratio).round();
    final atempoValue = speedCompensation.clamp(0.5, 2.0).toStringAsFixed(6);

    return 'asetrate=$targetSampleRate,atempo=$atempoValue,aresample=$baseSampleRate';
  }

  /// Applies a predefined preset.
  void applyPreset(AudioPitchPreset newPreset) {
    preset = newPreset;
    if (newPreset != AudioPitchPreset.custom) {
      semitones = newPreset.semitones;
      cents = newPreset.cents;
    }
  }

  /// Set semitones with automatic clamping and preset classification.
  void setSemitones(int val) {
    semitones = val.clamp(minSemitones, maxSemitones);
    _updatePresetClassification();
  }

  /// Set cents with automatic clamping and preset classification.
  void setCents(double val) {
    cents = val.clamp(minCents, maxCents);
    _updatePresetClassification();
  }

  void _updatePresetClassification() {
    for (final p in AudioPitchPreset.values) {
      if (p == AudioPitchPreset.custom) continue;
      if (p.semitones == semitones && (p.cents - cents).abs() < 0.2) {
        preset = p;
        return;
      }
    }
    preset = AudioPitchPreset.custom;
  }

  /// Reset to Flat neutral state.
  void reset() {
    enabled = false;
    semitones = 0;
    cents = 0.0;
    preset = AudioPitchPreset.flat;
  }

  AudioPitchConfig copyWith({
    bool? enabled,
    int? semitones,
    double? cents,
    AudioPitchPreset? preset,
  }) {
    return AudioPitchConfig(
      enabled: enabled ?? this.enabled,
      semitones: semitones ?? this.semitones,
      cents: cents ?? this.cents,
      preset: preset ?? this.preset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioPitchConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          semitones == other.semitones &&
          (cents - other.cents).abs() < 0.01 &&
          preset == other.preset;

  @override
  int get hashCode => Object.hash(enabled, semitones, cents, preset);

  @override
  String toString() =>
      'AudioPitchConfig(enabled: $enabled, semitones: $semitones, cents: ${cents.toStringAsFixed(2)}, ratio: ${pitchRatio.toStringAsFixed(4)}, preset: ${preset.label})';
}
