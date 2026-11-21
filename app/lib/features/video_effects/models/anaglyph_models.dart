/// 3D Stereoscopic input formats (FFmpeg stereo3d / VLC anaglyph.c parity).
enum AnaglyphSourceMode {
  /// Monoscopic 2D video rendered with synthetic chromatic parallax separation
  synthetic2D('2D Synthetic (Parallax)', '2D Monoscopic converted to 3D via spatial channel shift'),

  /// Side-by-Side Half (Half-SBS) - most common 3D movie format
  sideBySideHalf('Side-by-Side Half (Half-SBS)', 'Left & Right frames packed side-by-side at half width'),

  /// Side-by-Side Full (Full-SBS)
  sideBySideFull('Side-by-Side Full', 'Left & Right frames packed side-by-side at full width'),

  /// Top-and-Bottom Half (Over-Under Half)
  topAndBottomHalf('Top-and-Bottom Half (TaB)', 'Left & Right frames packed vertically at half height'),

  /// Top-and-Bottom Full (Over-Under Full)
  topAndBottomFull('Top-and-Bottom Full', 'Left & Right frames packed vertically at full height');

  final String label;
  final String description;

  const AnaglyphSourceMode(this.label, this.description);

  /// Returns corresponding FFmpeg stereo3d `in` parameter
  String getMpvIn(bool swapEyes) {
    switch (this) {
      case AnaglyphSourceMode.synthetic2D:
        return '';
      case AnaglyphSourceMode.sideBySideHalf:
        return swapEyes ? 'sbs2r' : 'sbs2l';
      case AnaglyphSourceMode.sideBySideFull:
        return swapEyes ? 'sbsr' : 'sbsl';
      case AnaglyphSourceMode.topAndBottomHalf:
        return swapEyes ? 'ab2r' : 'ab2l';
      case AnaglyphSourceMode.topAndBottomFull:
        return swapEyes ? 'abr' : 'abl';
    }
  }
}

/// Anaglyph color blending matrices for stereoscopic 3D glasses (VLC anaglyph.c parity).
enum AnaglyphColorMatrix {
  /// Dubois Red/Cyan - Least retinal rivalry, optimal spectral reproduction
  redCyanDubois('Red-Cyan (Dubois)', 'Optimized matrix minimizing eye-strain & ghosting', 'arrc'),

  /// Color Red/Cyan - High saturation red/cyan
  redCyanColor('Color Red-Cyan', 'Vibrant full-color stereoscopic red/cyan', 'arcc'),

  /// Half-Color Red/Cyan - Classic VLC default
  redCyanHalfColor('Half-Color Red-Cyan', 'Balanced classic red/cyan glasses', 'arch'),

  /// Green-Magenta Trioscopic 3D
  greenMagenta('Green-Magenta (Trioscopic)', 'For green & magenta 3D glasses', 'agmd'),

  /// Amber-Blue (Yellow-Blue / ColorCode 3D)
  amberBlue('Amber-Blue (ColorCode 3D)', 'For amber & blue ColorCode 3D glasses', 'aybd');

  final String label;
  final String description;
  final String mpvOut;

  const AnaglyphColorMatrix(this.label, this.description, this.mpvOut);
}
