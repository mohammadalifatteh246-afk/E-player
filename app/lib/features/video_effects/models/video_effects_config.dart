import 'dart:math' as math;
import 'puzzle_wall_models.dart';
import 'video_overlay_models.dart';
import 'deinterlace_models.dart';
import 'anaglyph_models.dart';

export 'puzzle_wall_models.dart';
export 'video_overlay_models.dart';
export 'deinterlace_models.dart';
export 'anaglyph_models.dart';

/// Video Effects Configuration for E-Player.
/// Reverse engineered from VLC media player's `adjust.c`, `sharpen.c`,
/// `transform.c`, `rotate.c`, `sepia.c`, `gradfun.c`, `colorthres.c`,
/// `logo.c`, `marq.c`, and `extended_panels.cpp`.
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
  bool colorThreshold; // VLC colorthres.c (selective color isolation / Sin City)
  int colorThresholdColor; // Target hex color (default 0xFF0000 - Red)
  double colorThresholdSimilarity; // Similarity tolerance 0.01 to 1.0 (default 0.30)
  double colorThresholdSaturation; // Saturation threshold 0.0 to 1.0 (default 0.20)

  // --- Geometry / Transform (VLC Geometry tab parity) ---
  bool flipHorizontal;
  bool flipVertical;
  double rotationAngle; // 0 to 360 degrees

  // --- Interactive Puzzle Game (VLC puzzle.c parity) ---
  bool puzzleEnabled;
  int puzzleRows; // 2 to 8 (default 3)
  int puzzleCols; // 2 to 8 (default 3)
  PuzzleGameMode puzzleMode; // swap or sliding
  double puzzleBorder; // 0.0 to 10.0 (default 2.0)
  bool puzzleShowPreview; // Floating mini original video preview (default false)
  bool puzzleAllowRotation; // Tile rotation difficulty (default false)

  // --- Video Wall Display Array (VLC wall.c parity) ---
  bool wallEnabled;
  int wallRows; // 1 to 6 (default 3)
  int wallCols; // 1 to 6 (default 3)
  double wallBezel; // 0.0 to 20.0 px (default 4.0)

  // --- Logo / Watermark Overlay (VLC logo.c parity) ---
  bool logoEnabled;
  String? logoPath;
  String? logoText;
  VideoOverlayPosition logoPosition;
  double logoOpacity; // 0.0 to 1.0 (VLC 0-255 mapped)
  double logoScale; // 0.2 to 2.0 (default 1.0)
  int logoOffsetX; // Pixel offset X
  int logoOffsetY; // Pixel offset Y

  // --- Marquee / Text OSD Overlay (VLC marq.c parity) ---
  bool marqueeEnabled;
  String marqueeText; // e.g. "E-Player • %t • %p / %l"
  VideoOverlayPosition marqueePosition;
  double marqueeOpacity; // 0.0 to 1.0
  double marqueeFontSize; // 10.0 to 48.0 (default 16.0)
  int marqueeColor; // RGB Hex (default 0xFFFFFF)
  int marqueeOffsetX; // Pixel offset X
  int marqueeOffsetY; // Pixel offset Y
  bool marqueeShowBackground; // Semi-transparent badge background

  // --- Deinterlacing Filter (VLC deinterlace.c parity) ---
  DeinterlaceMode deinterlaceMode;
  DeinterlaceAlgorithm deinterlaceAlgorithm;
  DeinterlaceFieldOrder deinterlaceFieldOrder;

  // --- Frame-by-Frame Motion Blur (VLC motionblur.c parity via libavfilter tmix) ---
  bool motionBlurEnabled;
  MotionBlurPreset motionBlurPreset;
  int motionBlurFrames; // 2 to 7 (default 3)

  // --- 3D Anaglyph Stereoscopic Filter (VLC anaglyph.c & FFmpeg stereo3d parity) ---
  bool anaglyphEnabled;
  AnaglyphSourceMode anaglyphSource; // Synthetic 2D, SBS, or Top-Bottom
  AnaglyphColorMatrix anaglyphMatrix; // Red-Cyan Dubois, Color, Green-Magenta, Amber-Blue
  double anaglyphParallax; // Horizontal disparity / convergence offset (-30.0 to +30.0 px, default 8.0)
  bool anaglyphSwapEyes; // Swap Left/Right eye view

  VideoEffectsConfig({
    this.masterEnabled = true,
    this.deinterlaceMode = DeinterlaceMode.off,
    this.deinterlaceAlgorithm = DeinterlaceAlgorithm.yadif,
    this.deinterlaceFieldOrder = DeinterlaceFieldOrder.auto,
    this.motionBlurEnabled = false,
    this.motionBlurPreset = MotionBlurPreset.cinematic,
    this.motionBlurFrames = 3,
    this.anaglyphEnabled = false,
    this.anaglyphSource = AnaglyphSourceMode.synthetic2D,
    this.anaglyphMatrix = AnaglyphColorMatrix.redCyanDubois,
    this.anaglyphParallax = 8.0,
    this.anaglyphSwapEyes = false,
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
    this.colorThreshold = false,
    this.colorThresholdColor = 0xFF0000,
    this.colorThresholdSimilarity = 0.30,
    this.colorThresholdSaturation = 0.20,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.rotationAngle = 0.0,
    this.puzzleEnabled = false,
    this.puzzleRows = 3,
    this.puzzleCols = 3,
    this.puzzleMode = PuzzleGameMode.swap,
    this.puzzleBorder = 2.0,
    this.puzzleShowPreview = false,
    this.puzzleAllowRotation = false,
    this.wallEnabled = false,
    this.wallRows = 3,
    this.wallCols = 3,
    this.wallBezel = 4.0,
    this.logoEnabled = false,
    this.logoPath,
    this.logoText,
    this.logoPosition = VideoOverlayPosition.topRight,
    this.logoOpacity = 0.85,
    this.logoScale = 1.0,
    this.logoOffsetX = 16,
    this.logoOffsetY = 16,
    this.marqueeEnabled = false,
    this.marqueeText = 'E-Player • %t • %p / %l',
    this.marqueePosition = VideoOverlayPosition.topLeft,
    this.marqueeOpacity = 0.90,
    this.marqueeFontSize = 16.0,
    this.marqueeColor = 0xFFFFFF,
    this.marqueeOffsetX = 16,
    this.marqueeOffsetY = 16,
    this.marqueeShowBackground = true,
  });

  /// Deep copy of configuration
  VideoEffectsConfig copyWith({
    bool? masterEnabled,
    DeinterlaceMode? deinterlaceMode,
    DeinterlaceAlgorithm? deinterlaceAlgorithm,
    DeinterlaceFieldOrder? deinterlaceFieldOrder,
    bool? motionBlurEnabled,
    MotionBlurPreset? motionBlurPreset,
    int? motionBlurFrames,
    bool? anaglyphEnabled,
    AnaglyphSourceMode? anaglyphSource,
    AnaglyphColorMatrix? anaglyphMatrix,
    double? anaglyphParallax,
    bool? anaglyphSwapEyes,
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
    bool? colorThreshold,
    int? colorThresholdColor,
    double? colorThresholdSimilarity,
    double? colorThresholdSaturation,
    bool? flipHorizontal,
    bool? flipVertical,
    double? rotationAngle,
    bool? puzzleEnabled,
    int? puzzleRows,
    int? puzzleCols,
    PuzzleGameMode? puzzleMode,
    double? puzzleBorder,
    bool? puzzleShowPreview,
    bool? puzzleAllowRotation,
    bool? wallEnabled,
    int? wallRows,
    int? wallCols,
    double? wallBezel,
    bool? logoEnabled,
    String? logoPath,
    String? logoText,
    VideoOverlayPosition? logoPosition,
    double? logoOpacity,
    double? logoScale,
    int? logoOffsetX,
    int? logoOffsetY,
    bool? marqueeEnabled,
    String? marqueeText,
    VideoOverlayPosition? marqueePosition,
    double? marqueeOpacity,
    double? marqueeFontSize,
    int? marqueeColor,
    int? marqueeOffsetX,
    int? marqueeOffsetY,
    bool? marqueeShowBackground,
  }) {
    return VideoEffectsConfig(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      deinterlaceMode: deinterlaceMode ?? this.deinterlaceMode,
      deinterlaceAlgorithm: deinterlaceAlgorithm ?? this.deinterlaceAlgorithm,
      deinterlaceFieldOrder: deinterlaceFieldOrder ?? this.deinterlaceFieldOrder,
      motionBlurEnabled: motionBlurEnabled ?? this.motionBlurEnabled,
      motionBlurPreset: motionBlurPreset ?? this.motionBlurPreset,
      motionBlurFrames: motionBlurFrames ?? this.motionBlurFrames,
      anaglyphEnabled: anaglyphEnabled ?? this.anaglyphEnabled,
      anaglyphSource: anaglyphSource ?? this.anaglyphSource,
      anaglyphMatrix: anaglyphMatrix ?? this.anaglyphMatrix,
      anaglyphParallax: anaglyphParallax ?? this.anaglyphParallax,
      anaglyphSwapEyes: anaglyphSwapEyes ?? this.anaglyphSwapEyes,
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
      colorThreshold: colorThreshold ?? this.colorThreshold,
      colorThresholdColor: colorThresholdColor ?? this.colorThresholdColor,
      colorThresholdSimilarity: colorThresholdSimilarity ?? this.colorThresholdSimilarity,
      colorThresholdSaturation: colorThresholdSaturation ?? this.colorThresholdSaturation,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      puzzleEnabled: puzzleEnabled ?? this.puzzleEnabled,
      puzzleRows: puzzleRows ?? this.puzzleRows,
      puzzleCols: puzzleCols ?? this.puzzleCols,
      puzzleMode: puzzleMode ?? this.puzzleMode,
      puzzleBorder: puzzleBorder ?? this.puzzleBorder,
      puzzleShowPreview: puzzleShowPreview ?? this.puzzleShowPreview,
      puzzleAllowRotation: puzzleAllowRotation ?? this.puzzleAllowRotation,
      wallEnabled: wallEnabled ?? this.wallEnabled,
      wallRows: wallRows ?? this.wallRows,
      wallCols: wallCols ?? this.wallCols,
      wallBezel: wallBezel ?? this.wallBezel,
      logoEnabled: logoEnabled ?? this.logoEnabled,
      logoPath: logoPath ?? this.logoPath,
      logoText: logoText ?? this.logoText,
      logoPosition: logoPosition ?? this.logoPosition,
      logoOpacity: logoOpacity ?? this.logoOpacity,
      logoScale: logoScale ?? this.logoScale,
      logoOffsetX: logoOffsetX ?? this.logoOffsetX,
      logoOffsetY: logoOffsetY ?? this.logoOffsetY,
      marqueeEnabled: marqueeEnabled ?? this.marqueeEnabled,
      marqueeText: marqueeText ?? this.marqueeText,
      marqueePosition: marqueePosition ?? this.marqueePosition,
      marqueeOpacity: marqueeOpacity ?? this.marqueeOpacity,
      marqueeFontSize: marqueeFontSize ?? this.marqueeFontSize,
      marqueeColor: marqueeColor ?? this.marqueeColor,
      marqueeOffsetX: marqueeOffsetX ?? this.marqueeOffsetX,
      marqueeOffsetY: marqueeOffsetY ?? this.marqueeOffsetY,
      marqueeShowBackground: marqueeShowBackground ?? this.marqueeShowBackground,
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
        !colorThreshold &&
        !flipHorizontal &&
        !flipVertical &&
        rotationAngle == 0.0 &&
        !puzzleEnabled &&
        !wallEnabled &&
        !logoEnabled &&
        !marqueeEnabled &&
        !anaglyphEnabled &&
        !motionBlurEnabled &&
        deinterlaceMode == DeinterlaceMode.off;
  }

  /// Reset all effects to defaults
  void resetAll() {
    masterEnabled = true;
    deinterlaceMode = DeinterlaceMode.off;
    deinterlaceAlgorithm = DeinterlaceAlgorithm.yadif;
    deinterlaceFieldOrder = DeinterlaceFieldOrder.auto;
    motionBlurEnabled = false;
    motionBlurPreset = MotionBlurPreset.cinematic;
    motionBlurFrames = 3;
    anaglyphEnabled = false;
    anaglyphSource = AnaglyphSourceMode.synthetic2D;
    anaglyphMatrix = AnaglyphColorMatrix.redCyanDubois;
    anaglyphParallax = 8.0;
    anaglyphSwapEyes = false;
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
    colorThreshold = false;
    colorThresholdColor = 0xFF0000;
    colorThresholdSimilarity = 0.30;
    colorThresholdSaturation = 0.20;
    flipHorizontal = false;
    flipVertical = false;
    rotationAngle = 0.0;
    puzzleEnabled = false;
    puzzleRows = 3;
    puzzleCols = 3;
    puzzleMode = PuzzleGameMode.swap;
    puzzleBorder = 2.0;
    puzzleShowPreview = false;
    puzzleAllowRotation = false;
    wallEnabled = false;
    wallRows = 3;
    wallCols = 3;
    wallBezel = 4.0;
    logoEnabled = false;
    logoPath = null;
    logoText = null;
    logoPosition = VideoOverlayPosition.topRight;
    logoOpacity = 0.85;
    logoScale = 1.0;
    logoOffsetX = 16;
    logoOffsetY = 16;
    marqueeEnabled = false;
    marqueeText = 'E-Player • %t • %p / %l';
    marqueePosition = VideoOverlayPosition.topLeft;
    marqueeOpacity = 0.90;
    marqueeFontSize = 16.0;
    marqueeColor = 0xFFFFFF;
    marqueeOffsetX = 16;
    marqueeOffsetY = 16;
    marqueeShowBackground = true;
  }

  /// Reset only 3D anaglyph stereoscopic filter settings (VLC anaglyph.c parity)
  void resetAnaglyph() {
    anaglyphEnabled = false;
    anaglyphSource = AnaglyphSourceMode.synthetic2D;
    anaglyphMatrix = AnaglyphColorMatrix.redCyanDubois;
    anaglyphParallax = 8.0;
    anaglyphSwapEyes = false;
  }

  /// Reset only deinterlace and motion blur settings (VLC deinterlace.c & motionblur.c parity)
  void resetDeinterlaceAndMotionBlur() {
    deinterlaceMode = DeinterlaceMode.off;
    deinterlaceAlgorithm = DeinterlaceAlgorithm.yadif;
    deinterlaceFieldOrder = DeinterlaceFieldOrder.auto;
    motionBlurEnabled = false;
    motionBlurPreset = MotionBlurPreset.cinematic;
    motionBlurFrames = 3;
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
    colorThreshold = false;
    colorThresholdColor = 0xFF0000;
    colorThresholdSimilarity = 0.30;
    colorThresholdSaturation = 0.20;
  }

  /// Reset only geometry
  void resetGeometry() {
    flipHorizontal = false;
    flipVertical = false;
    rotationAngle = 0.0;
    puzzleEnabled = false;
    puzzleRows = 3;
    puzzleCols = 3;
    puzzleMode = PuzzleGameMode.swap;
    puzzleBorder = 2.0;
    puzzleShowPreview = false;
    puzzleAllowRotation = false;
    wallEnabled = false;
    wallRows = 3;
    wallCols = 3;
    wallBezel = 4.0;
  }

  /// Reset only puzzle game settings (VLC puzzle.c parity)
  void resetPuzzle() {
    puzzleEnabled = false;
    puzzleRows = 3;
    puzzleCols = 3;
    puzzleMode = PuzzleGameMode.swap;
    puzzleBorder = 2.0;
    puzzleShowPreview = false;
    puzzleAllowRotation = false;
  }

  /// Reset only video wall settings (VLC wall.c parity)
  void resetWall() {
    wallEnabled = false;
    wallRows = 3;
    wallCols = 3;
    wallBezel = 4.0;
  }

  /// Reset only logo and marquee overlays (VLC logo.c & marq.c parity)
  void resetOverlay() {
    logoEnabled = false;
    logoPath = null;
    logoText = null;
    logoPosition = VideoOverlayPosition.topRight;
    logoOpacity = 0.85;
    logoScale = 1.0;
    logoOffsetX = 16;
    logoOffsetY = 16;
    marqueeEnabled = false;
    marqueeText = 'E-Player • %t • %p / %l';
    marqueePosition = VideoOverlayPosition.topLeft;
    marqueeOpacity = 0.90;
    marqueeFontSize = 16.0;
    marqueeColor = 0xFFFFFF;
    marqueeOffsetX = 16;
    marqueeOffsetY = 16;
    marqueeShowBackground = true;
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

    // Color Threshold filter (VLC colorthres.c parity via libavfilter colorhold)
    if (colorThreshold) {
      final hex = colorThresholdColor.toRadixString(16).padLeft(6, '0').toUpperCase();
      final sim = colorThresholdSimilarity.clamp(0.01, 1.0);
      final blend = (colorThresholdSaturation * 0.25).clamp(0.0, 0.5);
      filters.add('colorhold=color=0x$hex:similarity=${sim.toStringAsFixed(2)}:blend=${blend.toStringAsFixed(2)}');
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

    // Deinterlacing filter (VLC deinterlace.c parity)
    if (deinterlaceMode != DeinterlaceMode.off) {
      filters.add(deinterlaceAlgorithm.buildFilterString(deinterlaceFieldOrder));
    }

    // Frame-by-Frame Motion Blur (VLC motionblur.c parity via libavfilter tmix)
    if (motionBlurEnabled) {
      final frames = motionBlurFrames.clamp(2, 7);
      final weights = computeMotionBlurWeights(frames);
      filters.add('tmix=frames=$frames:weights="$weights"');
    }

    // 3D Anaglyph filter (VLC anaglyph.c parity & FFmpeg stereo3d/rgbashift)
    if (anaglyphEnabled) {
      if (anaglyphSource == AnaglyphSourceMode.synthetic2D) {
        // Monoscopic 2D with horizontal parallax channel shift
        int shift = anaglyphParallax.round();
        if (anaglyphSwapEyes) shift = -shift;
        switch (anaglyphMatrix) {
          case AnaglyphColorMatrix.redCyanDubois:
          case AnaglyphColorMatrix.redCyanColor:
          case AnaglyphColorMatrix.redCyanHalfColor:
            filters.add('rgbashift=rh=$shift:gh=${-shift}:bh=${-shift}');
            break;
          case AnaglyphColorMatrix.greenMagenta:
            filters.add('rgbashift=gh=$shift:rh=${-shift}:bh=${-shift}');
            break;
          case AnaglyphColorMatrix.amberBlue:
            filters.add('rgbashift=rh=$shift:gh=$shift:bh=${-shift}');
            break;
        }
      } else {
        // Stereoscopic 3D source (SBS / TaB) via FFmpeg stereo3d
        final inFmt = anaglyphSource.getMpvIn(anaglyphSwapEyes);
        final outFmt = anaglyphMatrix.mpvOut;
        filters.add('stereo3d=in=$inFmt:out=$outFmt');
      }
    }

    return filters.join(',');
  }

  /// Alias for buildMpvVfString
  String toMpvFilterString() => buildMpvVfString();

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

    // 6. Color Threshold preview approximation (selective color emphasis in UI preview)
    if (colorThreshold) {
      final rTarget = ((colorThresholdColor >> 16) & 0xFF) / 255.0;
      final gTarget = ((colorThresholdColor >> 8) & 0xFF) / 255.0;
      final bTarget = (colorThresholdColor & 0xFF) / 255.0;
      final sim = colorThresholdSimilarity.clamp(0.05, 1.0);
      final desat = (1.0 - sim * 0.6).clamp(0.0, 1.0);

      final thresholdMatrix = <double>[
        (1 - desat) + desat * rTarget, desat * gTarget, desat * bTarget, 0, 0,
        desat * rTarget, (1 - desat) + desat * gTarget, desat * bTarget, 0, 0,
        desat * rTarget, desat * gTarget, (1 - desat) + desat * bTarget, 0, 0,
        0, 0, 0, 1, 0,
      ];
      matrix = _multiplyColorMatrices(matrix, thresholdMatrix);
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
        'deinterlaceMode': deinterlaceMode.name,
        'deinterlaceAlgorithm': deinterlaceAlgorithm.name,
        'deinterlaceFieldOrder': deinterlaceFieldOrder.name,
        'motionBlurEnabled': motionBlurEnabled,
        'motionBlurPreset': motionBlurPreset.name,
        'motionBlurFrames': motionBlurFrames,
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
        'colorThreshold': colorThreshold,
        'colorThresholdColor': colorThresholdColor,
        'colorThresholdSimilarity': colorThresholdSimilarity,
        'colorThresholdSaturation': colorThresholdSaturation,
        'flipHorizontal': flipHorizontal,
        'flipVertical': flipVertical,
        'rotationAngle': rotationAngle,
        'puzzleEnabled': puzzleEnabled,
        'puzzleRows': puzzleRows,
        'puzzleCols': puzzleCols,
        'puzzleMode': puzzleMode.name,
        'puzzleBorder': puzzleBorder,
        'puzzleShowPreview': puzzleShowPreview,
        'puzzleAllowRotation': puzzleAllowRotation,
        'wallEnabled': wallEnabled,
        'wallRows': wallRows,
        'wallCols': wallCols,
        'wallBezel': wallBezel,
        'logoEnabled': logoEnabled,
        'logoPath': logoPath,
        'logoText': logoText,
        'logoPosition': logoPosition.name,
        'logoOpacity': logoOpacity,
        'logoScale': logoScale,
        'logoOffsetX': logoOffsetX,
        'logoOffsetY': logoOffsetY,
        'marqueeEnabled': marqueeEnabled,
        'marqueeText': marqueeText,
        'marqueePosition': marqueePosition.name,
        'marqueeOpacity': marqueeOpacity,
        'marqueeFontSize': marqueeFontSize,
        'marqueeColor': marqueeColor,
        'marqueeOffsetX': marqueeOffsetX,
        'marqueeOffsetY': marqueeOffsetY,
        'marqueeShowBackground': marqueeShowBackground,
        'anaglyphEnabled': anaglyphEnabled,
        'anaglyphSource': anaglyphSource.name,
        'anaglyphMatrix': anaglyphMatrix.name,
        'anaglyphParallax': anaglyphParallax,
        'anaglyphSwapEyes': anaglyphSwapEyes,
      };

  factory VideoEffectsConfig.fromJson(Map<String, dynamic> json) {
    return VideoEffectsConfig(
      masterEnabled: json['masterEnabled'] as bool? ?? true,
      deinterlaceMode: DeinterlaceMode.values.firstWhere(
        (e) => e.name == json['deinterlaceMode'],
        orElse: () => DeinterlaceMode.off,
      ),
      deinterlaceAlgorithm: DeinterlaceAlgorithm.values.firstWhere(
        (e) => e.name == json['deinterlaceAlgorithm'],
        orElse: () => DeinterlaceAlgorithm.yadif,
      ),
      deinterlaceFieldOrder: DeinterlaceFieldOrder.values.firstWhere(
        (e) => e.name == json['deinterlaceFieldOrder'],
        orElse: () => DeinterlaceFieldOrder.auto,
      ),
      motionBlurEnabled: json['motionBlurEnabled'] as bool? ?? false,
      motionBlurPreset: MotionBlurPreset.values.firstWhere(
        (e) => e.name == json['motionBlurPreset'],
        orElse: () => MotionBlurPreset.cinematic,
      ),
      motionBlurFrames: (json['motionBlurFrames'] as num?)?.toInt() ?? 3,
      anaglyphEnabled: json['anaglyphEnabled'] as bool? ?? false,
      anaglyphSource: AnaglyphSourceMode.values.firstWhere(
        (e) => e.name == json['anaglyphSource'],
        orElse: () => AnaglyphSourceMode.synthetic2D,
      ),
      anaglyphMatrix: AnaglyphColorMatrix.values.firstWhere(
        (e) => e.name == json['anaglyphMatrix'],
        orElse: () => AnaglyphColorMatrix.redCyanDubois,
      ),
      anaglyphParallax: (json['anaglyphParallax'] as num?)?.toDouble() ?? 8.0,
      anaglyphSwapEyes: json['anaglyphSwapEyes'] as bool? ?? false,
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
      colorThreshold: json['colorThreshold'] as bool? ?? false,
      colorThresholdColor: (json['colorThresholdColor'] as num?)?.toInt() ?? 0xFF0000,
      colorThresholdSimilarity: (json['colorThresholdSimilarity'] as num?)?.toDouble() ?? 0.30,
      colorThresholdSaturation: (json['colorThresholdSaturation'] as num?)?.toDouble() ?? 0.20,
      flipHorizontal: json['flipHorizontal'] as bool? ?? false,
      flipVertical: json['flipVertical'] as bool? ?? false,
      rotationAngle: (json['rotationAngle'] as num?)?.toDouble() ?? 0.0,
      puzzleEnabled: json['puzzleEnabled'] as bool? ?? false,
      puzzleRows: (json['puzzleRows'] as num?)?.toInt() ?? 3,
      puzzleCols: (json['puzzleCols'] as num?)?.toInt() ?? 3,
      puzzleMode: json['puzzleMode'] != null
          ? (json['puzzleMode'] == 'sliding' ? PuzzleGameMode.sliding : PuzzleGameMode.swap)
          : PuzzleGameMode.swap,
      puzzleBorder: (json['puzzleBorder'] as num?)?.toDouble() ?? 2.0,
      puzzleShowPreview: json['puzzleShowPreview'] as bool? ?? false,
      puzzleAllowRotation: json['puzzleAllowRotation'] as bool? ?? false,
      wallEnabled: json['wallEnabled'] as bool? ?? false,
      wallRows: (json['wallRows'] as num?)?.toInt() ?? 3,
      wallCols: (json['wallCols'] as num?)?.toInt() ?? 3,
      wallBezel: (json['wallBezel'] as num?)?.toDouble() ?? 4.0,
      logoEnabled: json['logoEnabled'] as bool? ?? false,
      logoPath: json['logoPath'] as String?,
      logoText: json['logoText'] as String?,
      logoPosition: json['logoPosition'] != null
          ? VideoOverlayPosition.fromString(json['logoPosition'] as String)
          : VideoOverlayPosition.topRight,
      logoOpacity: (json['logoOpacity'] as num?)?.toDouble() ?? 0.85,
      logoScale: (json['logoScale'] as num?)?.toDouble() ?? 1.0,
      logoOffsetX: (json['logoOffsetX'] as num?)?.toInt() ?? 16,
      logoOffsetY: (json['logoOffsetY'] as num?)?.toInt() ?? 16,
      marqueeEnabled: json['marqueeEnabled'] as bool? ?? false,
      marqueeText: json['marqueeText'] as String? ?? 'E-Player • %t • %p / %l',
      marqueePosition: json['marqueePosition'] != null
          ? VideoOverlayPosition.fromString(json['marqueePosition'] as String)
          : VideoOverlayPosition.topLeft,
      marqueeOpacity: (json['marqueeOpacity'] as num?)?.toDouble() ?? 0.90,
      marqueeFontSize: (json['marqueeFontSize'] as num?)?.toDouble() ?? 16.0,
      marqueeColor: (json['marqueeColor'] as num?)?.toInt() ?? 0xFFFFFF,
      marqueeOffsetX: (json['marqueeOffsetX'] as num?)?.toInt() ?? 16,
      marqueeOffsetY: (json['marqueeOffsetY'] as num?)?.toInt() ?? 16,
      marqueeShowBackground: json['marqueeShowBackground'] as bool? ?? true,
    );
  }
}
