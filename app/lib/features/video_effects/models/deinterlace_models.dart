/// Deinterlacing operational mode (VLC deinterlace.c parity).
enum DeinterlaceMode {
  off('Off', 0, 'no'),
  auto('Automatic', -1, 'auto'),
  on('On', 1, 'yes');

  final String label;
  final int vlcValue;
  final String mpvValue;

  const DeinterlaceMode(this.label, this.vlcValue, this.mpvValue);

  /// Cycles mode according to VLC hotkey 'd' sequence:
  /// Off -> Automatic -> On -> Off
  DeinterlaceMode next() {
    switch (this) {
      case DeinterlaceMode.off:
        return DeinterlaceMode.auto;
      case DeinterlaceMode.auto:
        return DeinterlaceMode.on;
      case DeinterlaceMode.on:
        return DeinterlaceMode.off;
    }
  }
}

/// Field parity / dominance for interlaced video sources.
enum DeinterlaceFieldOrder {
  auto('Auto Detect', 'auto'),
  tff('Top Field First (TFF)', 'tff'),
  bff('Bottom Field First (BFF)', 'bff');

  final String label;
  final String mpvParity;

  const DeinterlaceFieldOrder(this.label, this.mpvParity);
}

/// Deinterlacing algorithms supported in VLC Media Player (deinterlace.c parity).
enum DeinterlaceAlgorithm {
  yadif(
    'YADIF',
    'Yet Another DeInterlacing Filter (temporal+spatial, single-rate)',
    'yadif=mode=send_frame:parity=auto:deint=all',
  ),
  yadif2x(
    'YADIF (2x)',
    'Field-doubler 50/60 FPS ultra-smooth playback (recommended for sports)',
    'yadif=mode=send_field:parity=auto:deint=all',
  ),
  bob(
    'Bob / BWDIF',
    'Bob Weaver Deinterlacing Filter (modern spatial interpolation)',
    'bwdif=mode=send_field:parity=auto:deint=all',
  ),
  blend(
    'Blend',
    'Blends odd and even fields together to suppress comb flicker',
    'pp=lb',
  ),
  linear(
    'Linear',
    'Linear line-doubling interpolation',
    'pp=li',
  ),
  ivtc(
    'IVTC (Film Pulldown)',
    'Inverse Telecine: restores native 24fps film from 30i broadcast',
    'pullup',
  );

  final String label;
  final String description;
  final String mpvFilterString;

  const DeinterlaceAlgorithm(this.label, this.description, this.mpvFilterString);

  /// Builds the mpv vf filter string taking [fieldOrder] parity into account.
  String buildFilterString([DeinterlaceFieldOrder fieldOrder = DeinterlaceFieldOrder.auto]) {
    switch (this) {
      case DeinterlaceAlgorithm.yadif:
        return 'yadif=mode=send_frame:parity=${fieldOrder.mpvParity}:deint=all';
      case DeinterlaceAlgorithm.yadif2x:
        return 'yadif=mode=send_field:parity=${fieldOrder.mpvParity}:deint=all';
      case DeinterlaceAlgorithm.bob:
        return 'bwdif=mode=send_field:parity=${fieldOrder.mpvParity}:deint=all';
      case DeinterlaceAlgorithm.blend:
      case DeinterlaceAlgorithm.linear:
      case DeinterlaceAlgorithm.ivtc:
        return mpvFilterString;
    }
  }
}

/// Ready-made presets for Frame-by-Frame Motion Blur (VLC motionblur.c parity).
enum MotionBlurPreset {
  subtle(
    'Subtle Anti-Judder',
    'Gentle 2-frame temporal blend for 24fps anime and film panning',
    2,
    '1 1',
  ),
  cinematic(
    'Cinematic 24p Shutter',
    'Simulates authentic 180-degree cinema rotary shutter (3 frames)',
    3,
    '1 2 1',
  ),
  sports(
    'Sports Action Smoothing',
    'High-speed motion smoothing for sports & fast racing (4 frames)',
    4,
    '1 2 2 1',
  ),
  dreamy(
    'Dreamy / Artistic Trail',
    'Deep cinematic light trails and stylized temporal motion (6 frames)',
    6,
    '1 2 3 3 2 1',
  ),
  custom(
    'Custom Frames',
    'Manually adjust temporal frame mixing span (2 to 7 frames)',
    3,
    '1 2 1',
  );

  final String label;
  final String description;
  final int defaultFrames;
  final String defaultWeights;

  const MotionBlurPreset(
    this.label,
    this.description,
    this.defaultFrames,
    this.defaultWeights,
  );
}

/// Generates normalized temporal weights for [frames] count between 2 and 7.
String computeMotionBlurWeights(int frames) {
  final count = frames.clamp(2, 7);
  switch (count) {
    case 2:
      return '1 1';
    case 3:
      return '1 2 1';
    case 4:
      return '1 2 2 1';
    case 5:
      return '1 2 3 2 1';
    case 6:
      return '1 2 3 3 2 1';
    case 7:
      return '1 2 3 4 3 2 1';
    default:
      return '1 2 1';
  }
}
