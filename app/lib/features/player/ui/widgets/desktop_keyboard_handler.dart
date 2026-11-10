import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

/// Universal cross-platform desktop keyboard shortcut handler and
/// 4-tier precision seek physics engine for E-Player.
class DesktopKeyboardHandler extends StatefulWidget {
  final Player player;
  final Widget child;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onCycleAspectRatio;
  final VoidCallback onCycleAudioTrack;
  final VoidCallback onCycleSubtitleTrack;
  final Function(int offsetMs) onNudgeAudioDelay;
  final Function(int offsetMs) onNudgeSubtitleDelay;
  final Function(String message, IconData icon) onShowOsd;
  final VoidCallback onUserActivity;
  final VoidCallback? onBeforeSeek;
  final void Function(Duration target)? onSeek;
  final FocusNode? focusNode;
  final bool autofocus;

  const DesktopKeyboardHandler({
    super.key,
    required this.player,
    required this.child,
    required this.onToggleFullscreen,
    required this.onCycleAspectRatio,
    required this.onCycleAudioTrack,
    required this.onCycleSubtitleTrack,
    required this.onNudgeAudioDelay,
    required this.onNudgeSubtitleDelay,
    required this.onShowOsd,
    required this.onUserActivity,
    this.onBeforeSeek,
    this.onSeek,
    this.focusNode,
    this.autofocus = true,
  });

  @override
  State<DesktopKeyboardHandler> createState() => _DesktopKeyboardHandlerState();
}

class _DesktopKeyboardHandlerState extends State<DesktopKeyboardHandler> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  double _lastVolume = 100.0;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_effectiveFocusNode.hasFocus) {
          _effectiveFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // 1. Play / Pause Toggle (Space)
    if (event.logicalKey == LogicalKeyboardKey.space) {
      widget.onUserActivity();
      final willPlay = !widget.player.state.playing;
      widget.player.playOrPause();
      widget.onShowOsd(
        willPlay ? 'Play' : 'Pause',
        willPlay ? Icons.play_arrow_rounded : Icons.pause_rounded,
      );
      return KeyEventResult.handled;
    }

    // 2. Fullscreen Toggle (f / F11)
    if (event.logicalKey == LogicalKeyboardKey.keyF ||
        event.logicalKey == LogicalKeyboardKey.f11) {
      widget.onUserActivity();
      widget.onToggleFullscreen();
      return KeyEventResult.handled;
    }

    // 3. Mute Toggle (m)
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      widget.onUserActivity();
      final currentVol = widget.player.state.volume;
      if (currentVol > 0.0) {
        _lastVolume = currentVol;
        widget.player.setVolume(0.0);
        widget.onShowOsd('Mute', Icons.volume_off_rounded);
      } else {
        final restoreVol = _lastVolume > 0.0 ? _lastVolume : 100.0;
        widget.player.setVolume(restoreVol);
        widget.onShowOsd(
          'Volume: ${restoreVol.round()}%',
          Icons.volume_up_rounded,
        );
      }
      return KeyEventResult.handled;
    }

    // 4. Track Cycling (b = Audio, v = Subtitle)
    if (event.logicalKey == LogicalKeyboardKey.keyB) {
      widget.onUserActivity();
      widget.onCycleAudioTrack();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      widget.onUserActivity();
      widget.onCycleSubtitleTrack();
      return KeyEventResult.handled;
    }

    // 5. Aspect Ratio Cycling (a)
    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      widget.onUserActivity();
      widget.onCycleAspectRatio();
      return KeyEventResult.handled;
    }

    // 6. Subtitle Delay Nudge (h = +50ms, g = -50ms)
    if (event.logicalKey == LogicalKeyboardKey.keyH) {
      widget.onUserActivity();
      widget.onNudgeSubtitleDelay(50);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyG) {
      widget.onUserActivity();
      widget.onNudgeSubtitleDelay(-50);
      return KeyEventResult.handled;
    }

    // 7. Audio Delay Nudge (k = +50ms, j = -50ms)
    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      widget.onUserActivity();
      widget.onNudgeAudioDelay(50);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyJ) {
      widget.onUserActivity();
      widget.onNudgeAudioDelay(-50);
      return KeyEventResult.handled;
    }

    // 8. Playback Speed Controls
    // Speed Reset: '=' without Shift
    if (event.logicalKey == LogicalKeyboardKey.equal && !isShift) {
      widget.onUserActivity();
      widget.player.setRate(1.0);
      widget.onShowOsd('Speed: 1.0x (Normal)', Icons.speed_rounded);
      return KeyEventResult.handled;
    }

    // Coarse Speed Up (+0.25x): '+' or numpadAdd or '=' with Shift
    if (event.logicalKey == LogicalKeyboardKey.add ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd ||
        (event.logicalKey == LogicalKeyboardKey.equal && isShift)) {
      widget.onUserActivity();
      final targetRate =
          ((widget.player.state.rate + 0.25) * 100).round() / 100.0;
      final clampedRate = targetRate.clamp(0.25, 4.0);
      widget.player.setRate(clampedRate);
      widget.onShowOsd(
        'Speed: ${clampedRate.toStringAsFixed(2)}x',
        Icons.speed_rounded,
      );
      return KeyEventResult.handled;
    }

    // Coarse Speed Down (-0.25x): '-' or numpadSubtract
    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      widget.onUserActivity();
      final targetRate =
          ((widget.player.state.rate - 0.25) * 100).round() / 100.0;
      final clampedRate = targetRate.clamp(0.25, 4.0);
      widget.player.setRate(clampedRate);
      widget.onShowOsd(
        'Speed: ${clampedRate.toStringAsFixed(2)}x',
        Icons.speed_rounded,
      );
      return KeyEventResult.handled;
    }

    // Fine Speed Up (+0.1x): ']'
    if (event.logicalKey == LogicalKeyboardKey.bracketRight) {
      widget.onUserActivity();
      final targetRate =
          ((widget.player.state.rate + 0.1) * 100).round() / 100.0;
      final clampedRate = targetRate.clamp(0.25, 4.0);
      widget.player.setRate(clampedRate);
      widget.onShowOsd(
        'Speed: ${clampedRate.toStringAsFixed(2)}x',
        Icons.speed_rounded,
      );
      return KeyEventResult.handled;
    }

    // Fine Speed Down (-0.1x): '['
    if (event.logicalKey == LogicalKeyboardKey.bracketLeft) {
      widget.onUserActivity();
      final targetRate =
          ((widget.player.state.rate - 0.1) * 100).round() / 100.0;
      final clampedRate = targetRate.clamp(0.25, 4.0);
      widget.player.setRate(clampedRate);
      widget.onShowOsd(
        'Speed: ${clampedRate.toStringAsFixed(2)}x',
        Icons.speed_rounded,
      );
      return KeyEventResult.handled;
    }

    // 9. Volume Adjustments (Arrow Up / Arrow Down in 5% steps)
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onUserActivity();
      final vol = (widget.player.state.volume + 5.0).clamp(0.0, 150.0);
      widget.player.setVolume(vol);
      widget.onShowOsd(
        'Volume: ${vol.round()}%',
        vol > 100 ? Icons.volume_up_rounded : Icons.volume_down_rounded,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onUserActivity();
      final vol = (widget.player.state.volume - 5.0).clamp(0.0, 150.0);
      widget.player.setVolume(vol);
      widget.onShowOsd(
        vol == 0 ? 'Mute' : 'Volume: ${vol.round()}%',
        vol == 0 ? Icons.volume_off_rounded : Icons.volume_down_rounded,
      );
      return KeyEventResult.handled;
    }

    // 10. 4-Tier Precision Navigation Jumps (Arrow Left / Arrow Right)
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.onUserActivity();
      final isForward = event.logicalKey == LogicalKeyboardKey.arrowRight;
      final int jumpSeconds;
      final String tierName;

      if (isCtrl && isAlt) {
        jumpSeconds = 300;
        tierName = 'Long Jump (5m)';
      } else if (isCtrl) {
        jumpSeconds = 60;
        tierName = 'Medium Jump (1m)';
      } else if (isAlt) {
        jumpSeconds = 10;
        tierName = 'Short Jump (10s)';
      } else if (isShift) {
        jumpSeconds = 3;
        tierName = 'Dialogue Jump (3s)';
      } else {
        jumpSeconds = 10;
        tierName = 'Seek (10s)';
      }

      final delta = Duration(seconds: isForward ? jumpSeconds : -jumpSeconds);
      final currentPos = widget.player.state.position;
      final maxDuration = widget.player.state.duration;

      var target = currentPos + delta;
      if (target < Duration.zero) {
        target = Duration.zero;
      } else if (maxDuration > Duration.zero && target > maxDuration) {
        target = maxDuration;
      }

      if (widget.onSeek != null) {
        widget.onSeek!(target);
      } else {
        widget.onBeforeSeek?.call();
        widget.player.seek(target);
      }

      widget.onShowOsd(
        '${isForward ? '+' : '-'}${jumpSeconds}s ($tierName)',
        isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
