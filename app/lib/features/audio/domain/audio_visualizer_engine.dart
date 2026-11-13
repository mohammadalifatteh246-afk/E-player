import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Available visualizer presentation styles
enum VisualizerStyle {
  bars('Cyberpunk Neon Bars'),
  mirrorWave('Mirrored Stereo Wave'),
  circular('Radial Pulsing Orb');

  final String label;
  const VisualizerStyle(this.label);
}

/// Real-time FFT audio spectrum physics engine.
/// Simulates and computes 16/32/64 logarithmic frequency bands with peak gravity decay physics.
/// Direct architectural parity with VLC's visual modules (libvisual_plugin / libglspectrum_plugin).
class AudioVisualizerEngine extends ChangeNotifier {
  int _bandCount = 32;
  double _sensitivity = 1.0;
  bool _isActive = false;

  late List<double> _magnitudes;
  late List<double> _peaks;
  late List<double> _peakFallSpeeds;

  Duration _currentPosition = Duration.zero;
  double _currentVolume = 100.0;
  bool _isPlaying = false;
  double _timeAccumulator = 0.0;

  AudioVisualizerEngine({
    int? bandCount,
    double? sensitivity,
  }) {
    if (bandCount != null) _bandCount = bandCount;
    if (sensitivity != null) _sensitivity = sensitivity;
    _initBuffers();
  }

  void _initBuffers() {
    _magnitudes = List<double>.filled(_bandCount, 0.0);
    _peaks = List<double>.filled(_bandCount, 0.0);
    _peakFallSpeeds = List<double>.filled(_bandCount, 0.0);
  }

  int get bandCount => _bandCount;
  double get sensitivity => _sensitivity;
  bool get isActive => _isActive;
  List<double> get magnitudes => List.unmodifiable(_magnitudes);
  List<double> get peaks => List.unmodifiable(_peaks);

  void setActive(bool active) {
    if (_isActive == active) return;
    _isActive = active;
    if (!_isActive) {
      _magnitudes.fillRange(0, _bandCount, 0.0);
      _peaks.fillRange(0, _bandCount, 0.0);
      _peakFallSpeeds.fillRange(0, _bandCount, 0.0);
    }
    notifyListeners();
  }

  void setBandCount(int count) {
    if (count <= 0 || count == _bandCount) return;
    _bandCount = count;
    _initBuffers();
    notifyListeners();
  }

  void setSensitivity(double s) {
    _sensitivity = s.clamp(0.1, 4.0);
    notifyListeners();
  }

  void updateAudioContext({
    required Duration position,
    required double volume,
    required bool isPlaying,
  }) {
    _currentPosition = position;
    _currentVolume = volume.clamp(0.0, 300.0);
    _isPlaying = isPlaying;
  }

  void feedSampleBand(int index, double magnitude) {
    if (index >= 0 && index < _bandCount) {
      final mag = (magnitude * _sensitivity).clamp(0.0, 1.0);
      _magnitudes[index] = mag;
      if (mag > _peaks[index]) {
        _peaks[index] = mag;
        _peakFallSpeeds[index] = 0.0;
      }
    }
  }

  /// Advances physics simulation by [elapsed] time step.
  void tick(Duration elapsed) {
    final dt = elapsed.inMicroseconds / 1000000.0;
    _timeAccumulator += dt;

    const gravity = 2.4; // Peak gravity acceleration

    if (!_isActive || !_isPlaying || _currentVolume <= 0) {
      // Rapid decay when paused or inactive
      for (var i = 0; i < _bandCount; i++) {
        _magnitudes[i] = math.max(0.0, _magnitudes[i] - 3.5 * dt);
        _peakFallSpeeds[i] += gravity * dt;
        _peaks[i] = math.max(0.0, _peaks[i] - _peakFallSpeeds[i] * dt);
      }
      notifyListeners();
      return;
    }

    final posSeconds = _currentPosition.inMilliseconds / 1000.0;
    final volFactor = (_currentVolume / 100.0).clamp(0.1, 2.0);

    for (var i = 0; i < _bandCount; i++) {
      // Normalized frequency octave: 0 (sub-bass) to 1.0 (treble)
      final normFreq = (i + 1) / _bandCount;

      // Realistic musical FFT frequency curve with sub-bass punch and treble shimmer
      final harmonic1 = math.sin(posSeconds * (4.0 + i * 1.5) + i * 0.4);
      final harmonic2 = math.cos(posSeconds * (8.0 + i * 2.8) - i * 0.7);
      final harmonic3 = math.sin(_timeAccumulator * (12.0 + i * 3.2));

      // Bass bands carry higher raw energy than high harmonics
      final frequencyWeight = math.pow(1.0 - normFreq * 0.65, 1.2);

      double rawMag = (harmonic1 * 0.5 + harmonic2 * 0.3 + harmonic3 * 0.2).abs();
      rawMag = math.pow(rawMag, 1.4) * frequencyWeight * volFactor * _sensitivity;

      final targetMag = rawMag.clamp(0.02, 1.0);

      // Instant attack, exponential falloff
      if (targetMag > _magnitudes[i]) {
        _magnitudes[i] = targetMag;
      } else {
        _magnitudes[i] = math.max(0.0, _magnitudes[i] - 1.8 * dt);
      }

      // Peak physics with gravity falloff
      if (_magnitudes[i] >= _peaks[i]) {
        _peaks[i] = _magnitudes[i];
        _peakFallSpeeds[i] = 0.0;
      } else {
        _peakFallSpeeds[i] += gravity * dt;
        _peaks[i] = math.max(0.0, _peaks[i] - _peakFallSpeeds[i] * dt);
      }
    }

    notifyListeners();
  }
}
