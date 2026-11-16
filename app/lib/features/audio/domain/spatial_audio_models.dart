/// Audiophile crossfeed presets modeled after classic analog binaural circuits.
/// Eliminates headphone fatigue and simulates natural acoustic loudspeaker crosstalk.
enum CrossfeedPreset {
  off,
  bauerDefault, // 700 Hz cutoff, 4.5 dB crossfeed (Bauer standard)
  chuMoy,       // 700 Hz cutoff, 6.0 dB crossfeed (Popular DIY Headphone Amp)
  janMeier,     // 650 Hz cutoff, 9.5 dB crossfeed (Jan Meier Enhanced Natural)
  custom,       // User-specified cutoff and crossfeed level
}

/// Configuration model managing Spatial Audio, Binaural Crossfeed, and Room Acoustic Virtualization.
/// Parity with VLC's `libheadphone_channel_mixer_plugin.dll` and `libspatializer_plugin.dll`.
class SpatialAudioConfig {
  bool enabled;
  CrossfeedPreset crossfeedMode;
  double crossfeedCutoff; // 300 to 1200 Hz
  double crossfeedFeed;   // 1.0 to 15.0 dB
  double roomSize;        // 0.0 to 1.0
  double stereoWidth;     // 0.5 to 2.5
  bool virtualSurround;
  double spatialDamping;   // 0.0 to 1.0

  SpatialAudioConfig({
    this.enabled = false,
    this.crossfeedMode = CrossfeedPreset.bauerDefault,
    this.crossfeedCutoff = 700.0,
    this.crossfeedFeed = 4.5,
    this.roomSize = 0.5,
    this.stereoWidth = 1.0,
    this.virtualSurround = false,
    this.spatialDamping = 0.5,
  });

  /// Builds the ffmpeg `af` filter chain string for libmpv.
  String buildAfFilterString() {
    if (!enabled) return '';

    final List<String> filters = [];

    // 1. Binaural Headphone Crossfeed (VLC headphone.c & Bauer bs2b parity)
    switch (crossfeedMode) {
      case CrossfeedPreset.off:
        break;
      case CrossfeedPreset.bauerDefault:
        filters.add('crossfeed=f=700:d=4.5');
        break;
      case CrossfeedPreset.chuMoy:
        filters.add('crossfeed=f=700:d=6.0');
        break;
      case CrossfeedPreset.janMeier:
        filters.add('crossfeed=f=650:d=9.5');
        break;
      case CrossfeedPreset.custom:
        filters.add(
          'crossfeed=f=${crossfeedCutoff.round()}:d=${crossfeedFeed.toStringAsFixed(1)}',
        );
        break;
    }

    // 2. Spatial Room Acoustics & Width (VLC spatializer.cpp parity)
    if (roomSize > 0.05) {
      filters.add('stereowiden=level=${roomSize.toStringAsFixed(1)}');
    }

    if ((stereoWidth - 1.0).abs() > 0.05) {
      filters.add('extrastereo=m=${stereoWidth.toStringAsFixed(1)}');
    }

    // 3. Virtual Multichannel Surround Downmixer
    if (virtualSurround) {
      filters.add('surround=chl_out=stereo');
    }

    return filters.join(',');
  }

  void reset() {
    enabled = false;
    crossfeedMode = CrossfeedPreset.bauerDefault;
    crossfeedCutoff = 700.0;
    crossfeedFeed = 4.5;
    roomSize = 0.5;
    stereoWidth = 1.0;
    virtualSurround = false;
    spatialDamping = 0.5;
  }
}
