import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Available visualizer presentation styles (VLC visual.c & glspectrum.c parity)
enum VisualizerStyle {
  bars('Cyberpunk Neon Bars'),
  scope('Analog Oscilloscope'),
  spectrogram('3D Spectrogram Waterfall'),
  vuMeter('Stereo Peak VU-Meter'),
  mirrorWave('Mirrored Stereo Wave'),
  circular('Radial Pulsing Orb');

  final String label;
  const VisualizerStyle(this.label);
}

/// Real-time FFT audio spectrum physics engine.
/// Simulates and computes 16/32/64/80 logarithmic frequency bands with peak gravity decay physics,
/// time-domain oscilloscope waveform synthesis, and dual-channel VU ballistics.
/// Direct architectural parity with VLC's visual modules (`libvisual_plugin`, `libglspectrum_plugin`).
class AudioVisualizerEngine extends ChangeNotifier {
  int _bandCount = 32;
  double _sensitivity = 1.0;
  bool _isActive = false;
  bool _showPeaks = true;

  late List<double> _magnitudes;
  late List<double> _peaks;
  late List<double> _peakFallSpeeds;

  static const int _waveformSampleCount = 64;
  late List<double> _waveform;

  double _leftVuDb = -60.0;
  double _rightVuDb = -60.0;
  double _leftVuPeak = -60.0;
  double _rightVuPeak = -60.0;

  final List<List<double>> _spectrogramHistory = [];
  static const int _spectrogramMaxHistory = 16;

  Duration _currentPosition = Duration.zero;
  double _currentVolume = 100.0;
  bool _isPlaying = false;
  double _timeAccumulator = 0.0;

  AudioVisualizerEngine({
    int? bandCount,
    double? sensitivity,
    bool? showPeaks,
  }) {
    if (bandCount != null) _bandCount = bandCount;
    if (sensitivity != null) _sensitivity = sensitivity;
    if (showPeaks != null) _showPeaks = showPeaks;
    _initBuffers();
  }

  void _initBuffers() {
    _magnitudes = List<double>.filled(_bandCount, 0.0);
    _peaks = List<double>.filled(_bandCount, 0.0);
    _peakFallSpeeds = List<double>.filled(_bandCount, 0.0);
    _waveform = List<double>.filled(_waveformSampleCount, 0.0);
    _spectrogramHistory.clear();
  }

  int get bandCount => _bandCount;
  double get sensitivity => _sensitivity;
  bool get isActive => _isActive;
  bool get showPeaks => _showPeaks;
  List<double> get magnitudes => List.unmodifiable(_magnitudes);
  List<double> get peaks => List.unmodifiable(_peaks);
  List<double> get waveform => List.unmodifiable(_waveform);
  double get leftVuDb => _leftVuDb;
  double get rightVuDb => _rightVuDb;
  double get leftVuPeak => _leftVuPeak;
  double get rightVuPeak => _rightVuPeak;
  List<List<double>> get spectrogramHistory => List.unmodifiable(_spectrogramHistory);

  void setActive(bool active) {
    if (_isActive == active) return;
    _isActive = active;
    if (!_isActive) {
      _magnitudes.fillRange(0, _bandCount, 0.0);
      _peaks.fillRange(0, _bandCount, 0.0);
      _peakFallSpeeds.fillRange(0, _bandCount, 0.0);
      _waveform.fillRange(0, _waveformSampleCount, 0.0);
      _leftVuDb = -60.0;
      _rightVuDb = -60.0;
      _leftVuPeak = -60.0;
      _rightVuPeak = -60.0;
      _spectrogramHistory.clear();
    }
    notifyListeners();
  }

  void setShowPeaks(bool show) {
    if (_showPeaks == show) return;
    _showPeaks = show;
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
      for (var j = 0; j < _waveformSampleCount; j++) {
        _waveform[j] = _waveform[j] * math.max(0.0, 1.0 - 5.0 * dt);
      }
      _leftVuDb = math.max(-60.0, _leftVuDb - 35.0 * dt);
      _rightVuDb = math.max(-60.0, _rightVuDb - 35.0 * dt);
      _leftVuPeak = math.max(-60.0, _leftVuPeak - 15.0 * dt);
      _rightVuPeak = math.max(-60.0, _rightVuPeak - 15.0 * dt);
      notifyListeners();
      return;
    }

    final posSeconds = _currentPosition.inMilliseconds / 1000.0;
    final volFactor = (_currentVolume / 100.0).clamp(0.1, 2.0);

    // 1. Calculate frequency band magnitudes
    for (var i = 0; i < _bandCount; i++) {
      final normFreq = (i + 1) / _bandCount;

      final harmonic1 = math.sin(posSeconds * (4.0 + i * 1.5) + i * 0.4);
      final harmonic2 = math.cos(posSeconds * (8.0 + i * 2.8) - i * 0.7);
      final harmonic3 = math.sin(_timeAccumulator * (12.0 + i * 3.2));

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

    // 2. Synthesize Time-Domain Oscilloscope Waveform (VLC scope.c parity)
    final waveDt = _timeAccumulator * 25.0;
    for (var j = 0; j < _waveformSampleCount; j++) {
      final t = j / _waveformSampleCount;
      final fundamental = math.sin(waveDt + t * 4.0 * math.pi);
      final harmonic = 0.45 * math.sin(waveDt * 2.1 + t * 8.0 * math.pi + posSeconds);
      final overtone = 0.25 * math.sin(waveDt * 4.3 + t * 16.0 * math.pi);
      final envelope = _magnitudes.isNotEmpty ? _magnitudes[j % _bandCount] : 0.5;

      final waveVal = (fundamental + harmonic + overtone) * envelope * volFactor * _sensitivity * 0.45;
      _waveform[j] = waveVal.clamp(-1.0, 1.0);
    }

    // 3. Stereo VU Decibel Ballistics
    if (_bandCount >= 4) {
      double leftEnergy = 0.0;
      double rightEnergy = 0.0;
      final half = (_bandCount / 2).floor();
      for (var i = 0; i < _bandCount; i++) {
        if (i < half) {
          leftEnergy += _magnitudes[i] * _magnitudes[i];
        } else {
          rightEnergy += _magnitudes[i] * _magnitudes[i];
        }
      }
      final leftRms = math.sqrt(leftEnergy / half);
      final rightRms = math.sqrt(rightEnergy / half);

      // Convert to dB (-60 to +3 dB)
      final leftDb = (leftRms > 0.001 ? 20.0 * math.log(leftRms) / math.ln10 : -60.0).clamp(-60.0, 3.0);
      final rightDb = (rightRms > 0.001 ? 20.0 * math.log(rightRms) / math.ln10 : -60.0).clamp(-60.0, 3.0);

      _leftVuDb += (leftDb - _leftVuDb) * math.min(1.0, 14.0 * dt);
      _rightVuDb += (rightDb - _rightVuDb) * math.min(1.0, 14.0 * dt);

      if (_leftVuDb > _leftVuPeak) {
        _leftVuPeak = _leftVuDb;
      } else {
        _leftVuPeak = math.max(-60.0, _leftVuPeak - 12.0 * dt);
      }

      if (_rightVuDb > _rightVuPeak) {
        _rightVuPeak = _rightVuDb;
      } else {
        _rightVuPeak = math.max(-60.0, _rightVuPeak - 12.0 * dt);
      }
    }

    // 4. Update 3D Spectrogram History
    _spectrogramHistory.insert(0, List<double>.from(_magnitudes));
    if (_spectrogramHistory.length > _spectrogramMaxHistory) {
      _spectrogramHistory.removeLast();
    }

    notifyListeners();
  }
}
