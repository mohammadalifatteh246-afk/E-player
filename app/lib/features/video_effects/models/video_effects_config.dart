import 'dart:math' as math;

/// Video Effects Configuration for E-Player.
/// Reverse engineered from VLC media player's `adjust.c`, `sharpen.c`,
/// `transform.c`, `rotate.c`, `sepia.c`, `gradfun.c`, and `extended_panels.cpp`.
class VideoEffectsConfig {
  bool masterEnabled;

  // --- Essential Color Adjustments (VLC adjust.c parity) ---
  // Range: -100.0 to 100.0 (0.0 = neutral/1.0x)
  double brightness;
  double contrast;
  double saturation;
  double gamma;
  // Range: -180.0 to 180.0 degrees (0.0 = neutral)
  double hue;

  // --- Detail & Banding (VLC sharpen.c & gradfun.c parity) ---
  bool sharpen;
  double sharpenSigma; // 0.0 to 2.0 (default 0.5)
  bool bandingRemoval;
  int bandingRadius; // 4 to 32 (default 16)

  // --- Color Effects (VLC Colors tab parity) ---
  bool invert; // Negate colors
  bool sepia;
  double sepiaIntensity; // 0.0 to 1.0 (default 0.8)

  // --- Geometry / Transform (VLC Geometry tab parity) ---
  bool flipHorizontal;
  bool flipVertical;
  double rotationAngle; // 0 to 360 degrees

  VideoEffectsConfig({
    this.masterEnabled = true,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.gamma = 0.0,
    this.hue = 0.0,
    this.sharpen = false,
    this.sharpenSigma = 0.5,
    this.bandingRemoval = false,
    this.bandingRadius = 16,
    this.invert = false,
    this.sepia = false,
    this.sepiaIntensity = 0.8,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.rotationAngle = 0.0,
  });

  /// Deep copy of configuration
  VideoEffectsConfig copyWith({
    bool? masterEnabled,
    double? brightness,
    double? contrast,
    double? saturation,
    double? gamma,
    double? hue,
    bool? sharpen,
    double? sharpenSigma,
    bool? bandingRemoval,
    int? bandingRadius,
    bool? invert,
    bool? sepia,
    double? sepiaIntensity,
    bool? flipHorizontal,
    bool? flipVertical,
    double? rotationAngle,
  }) {
    return VideoEffectsConfig(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      gamma: gamma ?? this.gamma,
      hue: hue ?? this.hue,
      sharpen: sharpen ?? this.sharpen,
      sharpenSigma: sharpenSigma ?? this.sharpenSigma,
      bandingRemoval: bandingRemoval ?? this.bandingRemoval,
      bandingRadius: bandingRadius ?? this.bandingRadius,
      invert: invert ?? this.invert,
      sepia: sepia ?? this.sepia,
      sepiaIntensity: sepiaIntensity ?? this.sepiaIntensity,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      rotationAngle: rotationAngle ?? this.rotationAngle,
    );
  }

  /// Accurate conversion of VLC degrees (-180..180) to libmpv integer range (-100..100)
  int get mpvHue => ((hue / 180.0) * 100.0).clamp(-100.0, 100.0).round();

  /// Whether current values reflect neutral playback (no active distortion)
  bool get isNeutral {
    return brightness == 0.0 &&
        contrast == 0.0 &&
        saturation == 0.0 &&
        gamma == 0.0 &&
        hue == 0.0 &&
        !sharpen &&
        !bandingRemoval &&
        !invert &&
        !sepia &&
        !flipHorizontal &&
        !flipVertical &&
        rotationAngle == 0.0;
  }

  /// Reset all effects to defaults
  void resetAll() {
    masterEnabled = true;
    brightness = 0.0;
    contrast = 0.0;
    saturation = 0.0;
    gamma = 0.0;
    hue = 0.0;
    sharpen = false;
    sharpenSigma = 0.5;
    bandingRemoval = false;
    bandingRadius = 16;
    invert = false;
    sepia = false;
    sepiaIntensity = 0.8;
    flipHorizontal = false;
    flipVertical = false;
    rotationAngle = 0.0;
  }

  /// Reset only essential adjustments
  void resetEssential() {
    brightness = 0.0;
    contrast = 0.0;
    saturation = 0.0;
    gamma = 0.0;
    hue = 0.0;
    sharpen = false;
    sharpenSigma = 0.5;
    bandingRemoval = false;
    bandingRadius = 16;
  }

  /// Reset only color filters
  void resetColors() {
    invert = false;
    sepia = false;
    sepiaIntensity = 0.8;
  }

  /// Reset only geometry
  void resetGeometry() {
    flipHorizontal = false;
    flipVertical = false;
    rotationAngle = 0.0;
  }

  // --- Presets (VLC & Cinema Grading Parity) ---
  static VideoEffectsConfig presetNormal() => VideoEffectsConfig();

  static VideoEffectsConfig presetVibrant() => VideoEffectsConfig(
        contrast: 18.0,
        saturation: 28.0,
        brightness: 2.0,
        gamma: -4.0,
      );

  static VideoEffectsConfig presetCinemaWarm() => VideoEffectsConfig(
        contrast: 12.0,
        brightness: -3.0,
        saturation: 10.0,
        gamma: -6.0,
        sepia: true,
        sepiaIntensity: 0.15,
      );

  static VideoEffectsConfig presetMonochromeNoir() => VideoEffectsConfig(
        saturation: -100.0,
        contrast: 25.0,
        gamma: 10.0,
        brightness: -5.0,
      );

  static VideoEffectsConfig presetNightComfort() => VideoEffectsConfig(
        brightness: -15.0,
        contrast: -6.0,
        gamma: 14.0,
        saturation: -10.0,
      );

  static VideoEffectsConfig presetCrispDetail() => VideoEffectsConfig(
        sharpen: true,
        sharpenSigma: 0.85,
        contrast: 8.0,
        brightness: 0.0,
      );

  /// Builds the ffmpeg `vf` (video filter) chain for libmpv.
  /// Used for complex convolution and geometry filters that cannot be
  /// mapped to basic mpv integer hardware properties.
  String buildMpvVfString() {
    if (!masterEnabled) return '';

    final List<String> filters = [];

    // Sharpen (unsharp mask filter in ffmpeg/mpv)
    if (sharpen && sharpenSigma > 0.0) {
      final amount = sharpenSigma.clamp(0.1, 2.0);
      filters.add('unsharp=lx=5:ly=5:la=${amount.toStringAsFixed(2)}:cx=5:cy=5:ca=${(amount * 0.5).toStringAsFixed(2)}');
    }

    // Banding removal (gradfun filter, exact VLC parity)
    if (bandingRemoval) {
      final r = bandingRadius.clamp(4, 32);
      filters.add('gradfun=radius=$r');
    }

    // Geometry transforms
    if (flipHorizontal) {
      filters.add('hflip');
    }
    if (flipVertical) {
      filters.add('vflip');
    }

    // Negate / Invert colors
    if (invert) {
      filters.add('negate');
    }

    // Sepia Tone via colorchannelmixer (when software filter path is selected)
    if (sepia) {
      final k = sepiaIntensity.clamp(0.0, 1.0);
      final rR = 1.0 - k + (0.393 * k);
      final rG = 0.769 * k;
      final rB = 0.189 * k;
      final gR = 0.349 * k;
      final gG = 1.0 - k + (0.686 * k);
      final gB = 0.168 * k;
      final bR = 0.272 * k;
      final bG = 0.534 * k;
      final bB = 1.0 - k + (0.131 * k);
      filters.add(
        'colorchannelmixer='
        'rr=${rR.toStringAsFixed(3)}:rg=${rG.toStringAsFixed(3)}:rb=${rB.toStringAsFixed(3)}:'
        'gr=${gR.toStringAsFixed(3)}:gg=${gG.toStringAsFixed(3)}:gb=${gB.toStringAsFixed(3)}:'
        'br=${bR.toStringAsFixed(3)}:bg=${bG.toStringAsFixed(3)}:bb=${bB.toStringAsFixed(3)}',
      );
    }

    return filters.join(',');
  }

  /// Calculates a 4x5 ColorFilter matrix for instant 60/120fps GPU preview
  /// in the Flutter UI layer while dragging sliders.
  List<double> toColorFilterMatrix() {
    if (!masterEnabled || isNeutral) {
      return _identityMatrix;
    }

    // Start with identity matrix
    List<double> matrix = List<double>.from(_identityMatrix);

    // 1. Contrast & Brightness
    // c: -100..100 -> factor ~ 0.0 .. 2.0 (0 -> 1.0)
    final cFactor = ((contrast + 100.0) / 100.0).clamp(0.0, 3.0);
    // b: -100..100 -> offset in 0..255 space
    final bOffset = (brightness * 1.28).clamp(-128.0, 128.0);
    // Contrast pivot around 128 (0.5 normalized)
    final cOffset = 128.0 * (1.0 - cFactor) + bOffset;

    final contrastMatrix = <double>[
      cFactor, 0, 0, 0, cOffset,
      0, cFactor, 0, 0, cOffset,
      0, 0, cFactor, 0, cOffset,
      0, 0, 0, 1, 0,
    ];
    matrix = _multiplyColorMatrices(matrix, contrastMatrix);

    // 2. Saturation
    // s: -100..100 -> factor 0.0 .. 2.0 (0 -> 1.0)
    final sFactor = ((saturation + 100.0) / 100.0).clamp(0.0, 3.0);
    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;
    final invS = 1.0 - sFactor;
    final rR = invS * lumR + sFactor;
    final rG = invS * lumG;
    final rB = invS * lumB;
    final gR = invS * lumR;
    final gG = invS * lumG + sFactor;
    final gB = invS * lumB;
    final bR = invS * lumR;
    final bG = invS * lumG;
    final bB = invS * lumB + sFactor;

    final satMatrix = <double>[
      rR, rG, rB, 0, 0,
      gR, gG, gB, 0, 0,
      bR, bG, bB, 0, 0,
      0, 0, 0, 1, 0,
    ];
    matrix = _multiplyColorMatrices(matrix, satMatrix);

    // 3. Hue rotation
    if (hue != 0.0) {
      final rad = hue * math.pi / 180.0;
      final cosVal = math.cos(rad);
      final sinVal = math.sin(rad);

      final hueRR = lumR + cosVal * (1.0 - lumR) + sinVal * (-lumR);
      final hueRG = lumG + cosVal * (-lumG) + sinVal * (-lumG);
      final hueRB = lumB + cosVal * (-lumB) + sinVal * (1.0 - lumB);

      final hueGR = lumR + cosVal * (-lumR) + sinVal * (0.143);
      final hueGG = lumG + cosVal * (1.0 - lumG) + sinVal * (0.140);
      final hueGB = lumB + cosVal * (-lumB) + sinVal * (-0.283);

      final hueBR = lumR + cosVal * (-lumR) + sinVal * (-(1.0 - lumR));
      final hueBG = lumG + cosVal * (-lumG) + sinVal * (lumG);
      final hueBB = lumB + cosVal * (1.0 - lumB) + sinVal * (lumB);

      final hueMatrix = <double>[
        hueRR, hueRG, hueRB, 0, 0,
        hueGR, hueGG, hueGB, 0, 0,
        hueBR, hueBG, hueBB, 0, 0,
        0, 0, 0, 1, 0,
      ];
      matrix = _multiplyColorMatrices(matrix, hueMatrix);
    }

    // 4. Sepia tone
    if (sepia) {
      final k = sepiaIntensity.clamp(0.0, 1.0);
      final sepRR = 1.0 - k + (0.393 * k);
      final sepRG = 0.769 * k;
      final sepRB = 0.189 * k;
      final sepGR = 0.349 * k;
      final sepGG = 1.0 - k + (0.686 * k);
      final sepGB = 0.168 * k;
      final sepBR = 0.272 * k;
      final sepBG = 0.534 * k;
      final sepBB = 1.0 - k + (0.131 * k);

      final sepiaMatrix = <double>[
        sepRR, sepRG, sepRB, 0, 0,
        sepGR, sepGG, sepGB, 0, 0,
        sepBR, sepBG, sepBB, 0, 0,
        0, 0, 0, 1, 0,
      ];
      matrix = _multiplyColorMatrices(matrix, sepiaMatrix);
    }

    // 5. Invert / Negate
    if (invert) {
      final invertMatrix = <double>[
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ];
      matrix = _multiplyColorMatrices(matrix, invertMatrix);
    }

    return matrix;
  }

  // --- Color Matrix Math Helpers ---
  static const List<double> _identityMatrix = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static List<double> _multiplyColorMatrices(List<double> a, List<double> b) {
    final List<double> result = List<double>.filled(20, 0.0);
    for (int y = 0; y < 4; y++) {
      for (int x = 0; x < 5; x++) {
        double sum = 0.0;
        for (int i = 0; i < 4; i++) {
          sum += a[y * 5 + i] * b[i * 5 + x];
        }
        if (x == 4) {
          sum += a[y * 5 + 4]; // Add offset
        }
        result[y * 5 + x] = sum;
      }
    }
    return result;
  }

  // --- Serialization ---
  Map<String, dynamic> toJson() => {
        'masterEnabled': masterEnabled,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'gamma': gamma,
        'hue': hue,
        'sharpen': sharpen,
        'sharpenSigma': sharpenSigma,
        'bandingRemoval': bandingRemoval,
        'bandingRadius': bandingRadius,
        'invert': invert,
        'sepia': sepia,
        'sepiaIntensity': sepiaIntensity,
        'flipHorizontal': flipHorizontal,
        'flipVertical': flipVertical,
        'rotationAngle': rotationAngle,
      };

  factory VideoEffectsConfig.fromJson(Map<String, dynamic> json) {
    return VideoEffectsConfig(
      masterEnabled: json['masterEnabled'] as bool? ?? true,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 0.0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 0.0,
      gamma: (json['gamma'] as num?)?.toDouble() ?? 0.0,
      hue: (json['hue'] as num?)?.toDouble() ?? 0.0,
      sharpen: json['sharpen'] as bool? ?? false,
      sharpenSigma: (json['sharpenSigma'] as num?)?.toDouble() ?? 0.5,
      bandingRemoval: json['bandingRemoval'] as bool? ?? false,
      bandingRadius: (json['bandingRadius'] as num?)?.toInt() ?? 16,
      invert: json['invert'] as bool? ?? false,
      sepia: json['sepia'] as bool? ?? false,
      sepiaIntensity: (json['sepiaIntensity'] as num?)?.toDouble() ?? 0.8,
      flipHorizontal: json['flipHorizontal'] as bool? ?? false,
      flipVertical: json['flipVertical'] as bool? ?? false,
      rotationAngle: (json['rotationAngle'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
