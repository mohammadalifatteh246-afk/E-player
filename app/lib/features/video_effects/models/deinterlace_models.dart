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
}
