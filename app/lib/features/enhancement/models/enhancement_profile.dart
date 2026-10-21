import '../../video_effects/models/video_effects_config.dart';

/// Content-adaptive enhancement modes for real-time perceptual quality boosting.
enum EnhancementMode {
  superClarity,   // High acutance unsharp filter for 1080p/4K crispness
  animeRemaster,  // Line-art contour acutance + heavy deband + vibrant cel-shade colors
  cinemaHdr,      // Perceptual dynamic range expansion, deep contrast, specular pop
  nightSight,     // Shadow lift, midtone gamma expansion, low noise
  sportsVivid,    // High contrast, vivid chroma, crisp motion edges
  custom,         // Fully user-tunable DSP pipeline
}

/// Rich configuration model for Live AI & DSP Video Enhancement.
/// Connects high-level user enhancement goals directly into the underlying
/// hardware-accelerated video effects engine (VLC adjust/sharpen/gradfun parity).
class EnhancementConfig {
  bool masterToggle;
  EnhancementMode mode;
  double strength; // 0.2 to 1.5 global multiplier (default 1.0)

  // Legacy/Offline AI engine properties
  String resolution;
  String aiModel;
  int fpsTarget;
  bool audioEnhance;
  double audioEnhanceStrength;
  bool nightMode;
  bool stereo3D;

  // Custom fine-tuning parameters (used in Custom mode or as overrides)
  double customSharpenSigma; // 0.0 to 2.0
  int customDebandRadius;    // 0 to 32
  double customContrast;     // -50.0 to 50.0
  double customSaturation;   // -50.0 to 50.0
  double customGamma;        // -50.0 to 50.0
  double customBrightness;   // -50.0 to 50.0

  EnhancementConfig({
    this.masterToggle = false,
    this.mode = EnhancementMode.superClarity,
    this.strength = 1.0,
    this.resolution = '1080p',
    this.aiModel = 'General (realesr-general-x4v3)',
    this.fpsTarget = 30,
    this.audioEnhance = false,
    this.audioEnhanceStrength = 1.0,
    this.nightMode = false,
    this.stereo3D = false,
    this.customSharpenSigma = 0.85,
    this.customDebandRadius = 16,
    this.customContrast = 12.0,
    this.customSaturation = 15.0,
    this.customGamma = -4.0,
    this.customBrightness = 0.0,
  });

  /// Translates the high-level enhancement configuration into concrete
  /// hardware-accelerated video effects and ffmpeg/libmpv filter graphs.
  VideoEffectsConfig toVideoEffectsConfig() {
    if (!masterToggle) {
      return VideoEffectsConfig(masterEnabled: false);
    }

    final s = strength.clamp(0.2, 1.5);

    switch (mode) {
      case EnhancementMode.superClarity:
        return VideoEffectsConfig(
          masterEnabled: true,
          sharpen: true,
          sharpenSigma: (0.85 * s).clamp(0.1, 2.0),
          bandingRemoval: true,
          bandingRadius: (16 * s).round().clamp(4, 32),
          contrast: (10.0 * s).clamp(-50.0, 50.0),
          brightness: 0.0,
          saturation: (8.0 * s).clamp(-50.0, 50.0),
          gamma: (-4.0 * s).clamp(-50.0, 50.0),
        );

      case EnhancementMode.animeRemaster:
        return VideoEffectsConfig(
          masterEnabled: true,
          sharpen: true,
          sharpenSigma: (1.15 * s).clamp(0.1, 2.0), // Strong line acutance
          bandingRemoval: true,
          bandingRadius: (24 * s).round().clamp(4, 32), // High debanding for flat fills
          contrast: (14.0 * s).clamp(-50.0, 50.0),
          brightness: (2.0 * s).clamp(-50.0, 50.0),
          saturation: (24.0 * s).clamp(-50.0, 60.0), // Vibrant anime palette
          gamma: (4.0 * s).clamp(-50.0, 50.0),
        );

      case EnhancementMode.cinemaHdr:
        return VideoEffectsConfig(
          masterEnabled: true,
          sharpen: true,
          sharpenSigma: (0.65 * s).clamp(0.1, 2.0), // Filmic edge definition
          bandingRemoval: true,
          bandingRadius: (18 * s).round().clamp(4, 32),
          contrast: (18.0 * s).clamp(-50.0, 50.0), // Deep contrast S-curve
          brightness: (-2.0 * s).clamp(-50.0, 50.0), // Inky blacks
          saturation: (12.0 * s).clamp(-50.0, 50.0),
          gamma: (-6.0 * s).clamp(-50.0, 50.0),
          sepia: true,
          sepiaIntensity: (0.08 * s).clamp(0.0, 0.3), // Warm 3200K filmic tone
        );

      case EnhancementMode.nightSight:
        return VideoEffectsConfig(
          masterEnabled: true,
          sharpen: true,
          sharpenSigma: (0.50 * s).clamp(0.1, 2.0),
          bandingRemoval: true,
          bandingRadius: (28 * s).round().clamp(4, 32), // Clean shadow noise
          contrast: (-6.0 * s).clamp(-50.0, 50.0),
          brightness: (8.0 * s).clamp(-50.0, 50.0), // Lift low-light visibility
          saturation: (-4.0 * s).clamp(-50.0, 50.0),
          gamma: (24.0 * s).clamp(-50.0, 50.0), // Perceptual shadow expansion
        );

      case EnhancementMode.sportsVivid:
        return VideoEffectsConfig(
          masterEnabled: true,
          sharpen: true,
          sharpenSigma: (1.05 * s).clamp(0.1, 2.0), // Sharp motion contours
          bandingRemoval: false,
          contrast: (16.0 * s).clamp(-50.0, 50.0),
          brightness: (4.0 * s).clamp(-50.0, 50.0),
          saturation: (26.0 * s).clamp(-50.0, 60.0), // Vivid pitch & jerseys
          gamma: 0.0,
        );

      case EnhancementMode.custom:
        return VideoEffectsConfig(
          masterEnabled: true,
          sharpen: customSharpenSigma > 0.05,
          sharpenSigma: (customSharpenSigma * s).clamp(0.1, 2.0),
          bandingRemoval: customDebandRadius > 0,
          bandingRadius: (customDebandRadius * s).round().clamp(4, 32),
          contrast: (customContrast * s).clamp(-100.0, 100.0),
          brightness: (customBrightness * s).clamp(-100.0, 100.0),
          saturation: (customSaturation * s).clamp(-100.0, 100.0),
          gamma: (customGamma * s).clamp(-100.0, 100.0),
        );
    }
  }

  /// Metadata descriptor for UI chips & selectors
  static String getModeTitle(EnhancementMode mode) {
    switch (mode) {
      case EnhancementMode.superClarity:
        return 'Super Clarity HD';
      case EnhancementMode.animeRemaster:
        return 'Anime 4K Remaster';
      case EnhancementMode.cinemaHdr:
        return 'Cinema Dynamic HDR';
      case EnhancementMode.nightSight:
        return 'Night Sight (Shadow Lift)';
      case EnhancementMode.sportsVivid:
        return 'Sports & Action Vivid';
      case EnhancementMode.custom:
        return 'Custom Studio DSP';
    }
  }

  static String getModeSubtitle(EnhancementMode mode) {
    switch (mode) {
      case EnhancementMode.superClarity:
        return 'Unsharp acutance mask + anti-posterization deband';
      case EnhancementMode.animeRemaster:
        return 'Clean line contours + high deband + rich chromatic gamut';
      case EnhancementMode.cinemaHdr:
        return 'Expanded dynamic range + inky blacks + filmic warmth';
      case EnhancementMode.nightSight:
        return 'Perceptual shadow gamma lift without lifting true black';
      case EnhancementMode.sportsVivid:
        return 'High-speed edge definition + saturated grass & jersey tones';
      case EnhancementMode.custom:
        return 'User-defined spatial convolution & tone curve';
    }
  }

  EnhancementConfig copyWith({
    bool? masterToggle,
    EnhancementMode? mode,
    double? strength,
    String? resolution,
    String? aiModel,
    int? fpsTarget,
    bool? audioEnhance,
    double? audioEnhanceStrength,
    bool? nightMode,
    bool? stereo3D,
    double? customSharpenSigma,
    int? customDebandRadius,
    double? customContrast,
    double? customSaturation,
    double? customGamma,
    double? customBrightness,
  }) {
    return EnhancementConfig(
      masterToggle: masterToggle ?? this.masterToggle,
      mode: mode ?? this.mode,
      strength: strength ?? this.strength,
      resolution: resolution ?? this.resolution,
      aiModel: aiModel ?? this.aiModel,
      fpsTarget: fpsTarget ?? this.fpsTarget,
      audioEnhance: audioEnhance ?? this.audioEnhance,
      audioEnhanceStrength: audioEnhanceStrength ?? this.audioEnhanceStrength,
      nightMode: nightMode ?? this.nightMode,
      stereo3D: stereo3D ?? this.stereo3D,
      customSharpenSigma: customSharpenSigma ?? this.customSharpenSigma,
      customDebandRadius: customDebandRadius ?? this.customDebandRadius,
      customContrast: customContrast ?? this.customContrast,
      customSaturation: customSaturation ?? this.customSaturation,
      customGamma: customGamma ?? this.customGamma,
      customBrightness: customBrightness ?? this.customBrightness,
    );
  }

  Map<String, dynamic> toJson() => {
        'masterToggle': masterToggle,
        'mode': mode.index,
        'strength': strength,
        'resolution': resolution,
        'aiModel': aiModel,
        'fpsTarget': fpsTarget,
        'audioEnhance': audioEnhance,
        'audioEnhanceStrength': audioEnhanceStrength,
        'nightMode': nightMode,
        'stereo3D': stereo3D,
        'customSharpenSigma': customSharpenSigma,
        'customDebandRadius': customDebandRadius,
        'customContrast': customContrast,
        'customSaturation': customSaturation,
        'customGamma': customGamma,
        'customBrightness': customBrightness,
      };

  factory EnhancementConfig.fromJson(Map<String, dynamic> json) {
    return EnhancementConfig(
      masterToggle: json['masterToggle'] as bool? ?? false,
      mode: EnhancementMode.values[(json['mode'] as int?) ?? 0],
      strength: (json['strength'] as num?)?.toDouble() ?? 1.0,
      resolution: json['resolution'] as String? ?? '1080p',
      aiModel: json['aiModel'] as String? ?? 'General (realesr-general-x4v3)',
      fpsTarget: json['fpsTarget'] as int? ?? 30,
      audioEnhance: json['audioEnhance'] as bool? ?? false,
      audioEnhanceStrength: (json['audioEnhanceStrength'] as num?)?.toDouble() ?? 1.0,
      nightMode: json['nightMode'] as bool? ?? false,
      stereo3D: json['stereo3D'] as bool? ?? false,
      customSharpenSigma: (json['customSharpenSigma'] as num?)?.toDouble() ?? 0.85,
      customDebandRadius: json['customDebandRadius'] as int? ?? 16,
      customContrast: (json['customContrast'] as num?)?.toDouble() ?? 12.0,
      customSaturation: (json['customSaturation'] as num?)?.toDouble() ?? 15.0,
      customGamma: (json['customGamma'] as num?)?.toDouble() ?? -4.0,
      customBrightness: (json['customBrightness'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
