import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 4-state A-B Repeat Loop Controller conforming to Phase 2 R3 specification.
/// - State 0: Off (No active loop)
/// - State 1: Point A set (Waiting for Point B)
/// - State 2: Point B set (Actively looping from Point A to Point B)
/// - State 3: Clear / Reset (Returns to normal playback)
enum ABRepeatState {
  off,
  pointA,
  looping,
  clear,
}

class ABRepeatController {
  ABRepeatState _state = ABRepeatState.off;
  Duration? _pointA;
  Duration? _pointB;
  bool _isLoopSeeking = false;
  DateTime? _lastLoopSeekTime;
  int _seekCount = 0;

  ABRepeatState get state => _state;
  Duration? get pointA => _pointA;
  Duration? get pointB => _pointB;
  bool get isLoopSeeking => _isLoopSeeking;
  int get seekCount => _seekCount;

  /// Cycle loop states:
  /// State 0 (Off) -> State 1 (Point A) -> State 2 (Point B & Loop) -> State 3 (Clear -> Off)
  bool cycle(
    Duration currentPosition, {
    VoidCallback? onUpdate,
    void Function(String message)? onMessage,
  }) {
    switch (_state) {
      case ABRepeatState.off:
        _pointA = currentPosition;
        _pointB = null;
        _state = ABRepeatState.pointA;
        onMessage?.call('A-B Loop: Point A set (${_formatDuration(_pointA!)})');
        onUpdate?.call();
        return true;

      case ABRepeatState.pointA:
        // Validation: Point B must be strictly after Point A (at least 500ms)
        if (currentPosition <= _pointA!) {
          onMessage?.call('Point B cannot be earlier than or equal to Point A');
          return false;
        }
        if (currentPosition - _pointA! < const Duration(milliseconds: 500)) {
          // Auto-pad to guarantee minimum 500ms window
          _pointB = _pointA! + const Duration(milliseconds: 500);
        } else {
          _pointB = currentPosition;
        }
        _state = ABRepeatState.looping;
        onMessage?.call('A-B Loop: Active (${_formatDuration(_pointA!)} -> ${_formatDuration(_pointB!)})');
        onUpdate?.call();
        return true;

      case ABRepeatState.looping:
      case ABRepeatState.clear:
        reset();
        onMessage?.call('A-B Loop: Cleared');
        onUpdate?.call();
        return true;
    }
  }

  /// Real-time position check with anti-thrashing concurrency debounce guard.
  Future<void> checkPosition(
    Duration currentPosition, {
    required Future<void> Function(Duration target) onSeek,
  }) async {
    if (_state != ABRepeatState.looping || _pointA == null || _pointB == null) {
      return;
    }

    // Boundary trigger: position reaches or exceeds Point B
    if (currentPosition >= _pointB! && !_isLoopSeeking) {
      _isLoopSeeking = true;
      _lastLoopSeekTime = DateTime.now();
      _seekCount++;
      await onSeek(_pointA!);
    } else if (_isLoopSeeking) {
      // Safe reset of seek guard once position rewinds before Point B or timeout elapsed
      final elapsed = _lastLoopSeekTime != null
          ? DateTime.now().difference(_lastLoopSeekTime!).inMilliseconds
          : 1000;
      if (currentPosition < _pointB! || elapsed > 750) {
        _isLoopSeeking = false;
      }
    }
  }

  void reset() {
    _state = ABRepeatState.off;
    _pointA = null;
    _pointB = null;
    _isLoopSeeking = false;
    _lastLoopSeekTime = null;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Aspect ratio crop presets conforming to Phase 2 R4 specification.
enum CropPreset {
  ratio16_9('16:9', 'crop=ih*16/9:ih'),
  ratio16_10('16:10', 'crop=ih*16/10:ih'),
  ratio4_3('4:3', 'crop=ih*4/3:ih'),
  ratio1_85_1('1.85:1', 'crop=ih*1.85:ih'),
  ratio2_35_1('2.35:1', 'crop=ih*2.35:ih'),
  reset('Reset', '');

  final String label;
  final String filterString;
  const CropPreset(this.label, this.filterString);
}

class AspectCropController {
  final Player player;
  int _currentIndex = 5; // Starts at Reset

  AspectCropController(this.player);

  List<CropPreset> get presets => CropPreset.values;
  CropPreset get current => presets[_currentIndex];
  int get currentIndex => _currentIndex;

  Future<void> cycleNext({void Function(CropPreset preset)? onCropChanged}) async {
    _currentIndex = (_currentIndex + 1) % presets.length;
    final selected = presets[_currentIndex];
    final dynamic platform = player.platform;
    await platform.setProperty('vf', selected.filterString);
    onCropChanged?.call(selected);
  }

  Future<void> setPreset(CropPreset preset, {void Function(CropPreset preset)? onCropChanged}) async {
    _currentIndex = presets.indexOf(preset);
    if (_currentIndex == -1) _currentIndex = 5;
    final dynamic platform = player.platform;
    await platform.setProperty('vf', preset.filterString);
    onCropChanged?.call(preset);
  }
}

/// Network and disk buffer caching settings controller conforming to Phase 2 R5 specification.
class BufferCachingSettingsController {
  int _networkCachingMs = 1000; // 500ms to 10000ms, default 1000ms
  int _demuxerCacheMb = 32;     // 16, 32, 64, 128 MB, default 32MB

  int get networkCachingMs => _networkCachingMs;
  int get demuxerCacheMb => _demuxerCacheMb;

  Future<void> loadFromPrefs(SharedPreferences prefs) async {
    _networkCachingMs = prefs.getInt('networkCachingMs') ?? 1000;
    _demuxerCacheMb = prefs.getInt('demuxerCacheMb') ?? 32;
  }

  Future<void> setNetworkCachingMs(int ms, SharedPreferences prefs, {Player? player}) async {
    final clamped = ms.clamp(500, 10000);
    _networkCachingMs = clamped;
    await prefs.setInt('networkCachingMs', clamped);
    if (player != null) {
      final dynamic platform = player.platform;
      final cacheSecs = (clamped / 1000.0).toStringAsFixed(2);
      await platform.setProperty('cache-secs', cacheSecs);
    }
  }

  Future<void> setDemuxerCacheMb(int mb, SharedPreferences prefs, {Player? player}) async {
    const valid = [16, 32, 64, 128];
    final resolved = valid.contains(mb) ? mb : 32;
    _demuxerCacheMb = resolved;
    await prefs.setInt('demuxerCacheMb', resolved);
    if (player != null) {
      final dynamic platform = player.platform;
      final bytes = resolved * 1024 * 1024;
      await platform.setProperty('demuxer-max-bytes', bytes.toString());
      await platform.setProperty('demuxer-max-back-bytes', bytes.toString());
    }
  }

  Future<void> applyToPlayer(Player player) async {
    final dynamic platform = player.platform;
    final cacheSecs = (_networkCachingMs / 1000.0).toStringAsFixed(2);
    final bytes = _demuxerCacheMb * 1024 * 1024;
    await platform.setProperty('cache-secs', cacheSecs);
    await platform.setProperty('demuxer-max-bytes', bytes.toString());
    await platform.setProperty('demuxer-max-back-bytes', bytes.toString());
  }
}
