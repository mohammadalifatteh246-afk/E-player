/// Presets for Audio Dynamic Range Compression based on VLC compressor.c and audio engineering standards.
enum AudioCompressorPreset {
  balancedDefault(
    label: 'Balanced (VLC Default)',
    threshold: -11.0,
    ratio: 4.0,
    knee: 2.5,
    attack: 25.0,
    release: 100.0,
    makeupGain: 7.0,
    rmsDetection: true,
  ),
  nightCinema(
    label: 'Night Cinema (Tame Action / Clear Dialog)',
    threshold: -20.0,
    ratio: 6.0,
    knee: 4.0,
    attack: 15.0,
    release: 200.0,
    makeupGain: 9.0,
    rmsDetection: true,
  ),
  speechBroadcast(
    label: 'Speech / Podcast Clarity',
    threshold: -16.0,
    ratio: 3.5,
    knee: 3.0,
    attack: 20.0,
    release: 150.0,
    makeupGain: 6.0,
    rmsDetection: true,
  ),
  hardLimiter(
    label: 'Peak Clipper Guard (Hard Limiter)',
    threshold: -3.0,
    ratio: 16.0,
    knee: 1.0,
    attack: 2.0,
    release: 50.0,
    makeupGain: 0.0,
    rmsDetection: false,
  ),
  subtleAcoustic(
    label: 'Subtle / Acoustic Glue',
    threshold: -8.0,
    ratio: 2.0,
    knee: 5.0,
    attack: 50.0,
    release: 300.0,
    makeupGain: 2.0,
    rmsDetection: true,
  ),
  heavySqueeze(
    label: 'Heavy Squeeze (Max Loudness)',
    threshold: -24.0,
    ratio: 8.0,
    knee: 6.0,
    attack: 10.0,
    release: 120.0,
    makeupGain: 12.0,
    rmsDetection: true,
  ),
  custom(
    label: 'Custom',
    threshold: -11.0,
    ratio: 4.0,
    knee: 2.5,
    attack: 25.0,
    release: 100.0,
    makeupGain: 7.0,
    rmsDetection: true,
  );

  final String label;
  final double threshold;
  final double ratio;
  final double knee;
  final double attack;
  final double release;
  final double makeupGain;
  final bool rmsDetection;

  const AudioCompressorPreset({
    required this.label,
    required this.threshold,
    required this.ratio,
    required this.knee,
    required this.attack,
    required this.release,
    required this.makeupGain,
    required this.rmsDetection,
  });
}

/// Pure domain configuration model for Audio Dynamic Range Compression (DRC).
/// Provides mathematical parity with VLC's `modules/audio_filter/compressor.c`
/// and libavfilter's `acompressor`.
class AudioCompressorConfig {
  static const double minThreshold = -30.0;
  static const double maxThreshold = 0.0;
  static const double minRatio = 1.0;
  static const double maxRatio = 20.0;
  static const double minKnee = 1.0;
  static const double maxKnee = 10.0;
  static const double minAttack = 1.5;
  static const double maxAttack = 400.0;
  static const double minRelease = 2.0;
  static const double maxRelease = 800.0;
  static const double minMakeupGain = 0.0;
  static const double maxMakeupGain = 24.0;

  bool enabled;
  double threshold;
  double ratio;
  double knee;
  double attack;
  double release;
  double makeupGain;
  bool rmsDetection;
  AudioCompressorPreset preset;

  AudioCompressorConfig({
    this.enabled = false,
    this.threshold = -11.0,
    this.ratio = 4.0,
    this.knee = 2.5,
    this.attack = 25.0,
    this.release = 100.0,
    this.makeupGain = 7.0,
    this.rmsDetection = true,
    this.preset = AudioCompressorPreset.balancedDefault,
  });

  /// Build libavfilter / mpv filter string.
  /// Generates acompressor string when enabled; empty string when disabled.
  String buildMpvAfString() {
    if (!enabled) return '';

    final tStr = threshold.toStringAsFixed(1);
    final rStr = ratio.toStringAsFixed(1);
    final kStr = knee.toStringAsFixed(1);
    final aStr = attack.toStringAsFixed(1);
    final relStr = release.toStringAsFixed(1);
    final mStr = makeupGain.toStringAsFixed(1);
    final dStr = rmsDetection ? 'rms' : 'peak';

    return 'acompressor=threshold=${tStr}dB:ratio=$rStr:knee=${kStr}dB:attack=$aStr:release=$relStr:makeup=${mStr}dB:detection=$dStr';
  }

  void applyPreset(AudioCompressorPreset newPreset) {
    preset = newPreset;
    if (newPreset != AudioCompressorPreset.custom) {
      threshold = newPreset.threshold;
      ratio = newPreset.ratio;
      knee = newPreset.knee;
      attack = newPreset.attack;
      release = newPreset.release;
      makeupGain = newPreset.makeupGain;
      rmsDetection = newPreset.rmsDetection;
    }
  }

  void setThreshold(double val) {
    threshold = val.clamp(minThreshold, maxThreshold);
    _updatePresetClassification();
  }

  void setRatio(double val) {
    ratio = val.clamp(minRatio, maxRatio);
    _updatePresetClassification();
  }

  void setKnee(double val) {
    knee = val.clamp(minKnee, maxKnee);
    _updatePresetClassification();
  }

  void setAttack(double val) {
    attack = val.clamp(minAttack, maxAttack);
    _updatePresetClassification();
  }

  void setRelease(double val) {
    release = val.clamp(minRelease, maxRelease);
    _updatePresetClassification();
  }

  void setMakeupGain(double val) {
    makeupGain = val.clamp(minMakeupGain, maxMakeupGain);
    _updatePresetClassification();
  }

  void setRmsDetection(bool val) {
    rmsDetection = val;
    _updatePresetClassification();
  }

  void _updatePresetClassification() {
    for (final p in AudioCompressorPreset.values) {
      if (p == AudioCompressorPreset.custom) continue;
      if ((p.threshold - threshold).abs() < 0.2 &&
          (p.ratio - ratio).abs() < 0.2 &&
          (p.knee - knee).abs() < 0.2 &&
          (p.attack - attack).abs() < 0.5 &&
          (p.release - release).abs() < 0.5 &&
          (p.makeupGain - makeupGain).abs() < 0.2 &&
          p.rmsDetection == rmsDetection) {
        preset = p;
        return;
      }
    }
    preset = AudioCompressorPreset.custom;
  }

  void reset() {
    enabled = false;
    threshold = -11.0;
    ratio = 4.0;
    knee = 2.5;
    attack = 25.0;
    release = 100.0;
    makeupGain = 7.0;
    rmsDetection = true;
    preset = AudioCompressorPreset.balancedDefault;
  }

  AudioCompressorConfig copyWith({
    bool? enabled,
    double? threshold,
    double? ratio,
    double? knee,
    double? attack,
    double? release,
    double? makeupGain,
    bool? rmsDetection,
    AudioCompressorPreset? preset,
  }) {
    return AudioCompressorConfig(
      enabled: enabled ?? this.enabled,
      threshold: threshold ?? this.threshold,
      ratio: ratio ?? this.ratio,
      knee: knee ?? this.knee,
      attack: attack ?? this.attack,
      release: release ?? this.release,
      makeupGain: makeupGain ?? this.makeupGain,
      rmsDetection: rmsDetection ?? this.rmsDetection,
      preset: preset ?? this.preset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioCompressorConfig &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          (threshold - other.threshold).abs() < 0.01 &&
          (ratio - other.ratio).abs() < 0.01 &&
          (knee - other.knee).abs() < 0.01 &&
          (attack - other.attack).abs() < 0.01 &&
          (release - other.release).abs() < 0.01 &&
          (makeupGain - other.makeupGain).abs() < 0.01 &&
          rmsDetection == other.rmsDetection &&
          preset == other.preset;

  @override
  int get hashCode => Object.hash(
        enabled,
        threshold,
        ratio,
        knee,
        attack,
        release,
        makeupGain,
        rmsDetection,
        preset,
      );

  @override
  String toString() =>
      'AudioCompressorConfig(enabled: $enabled, threshold: ${threshold}dB, ratio: $ratio:1, makeup: ${makeupGain}dB, preset: ${preset.label})';
}
