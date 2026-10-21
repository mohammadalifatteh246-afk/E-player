import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../../../../core/engine_orchestrator.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../../widgets/e_player_components.dart';
import '../../casting/ui/casting_screen.dart';
import '../../enhancement/ui/enhancement_studio_sheet.dart';
import '../../library/domain/library_provider.dart';
import '../../video_effects/models/video_effects_config.dart';
import '../../video_effects/domain/video_effects_service.dart';
import '../../video_effects/ui/video_effects_sheet.dart';
import 'subtitle_settings_sheet.dart';
import 'audio_studio_sheet.dart';
import '../domain/video_rotation_service.dart';

class PlayerScreen extends StatefulWidget {
  final String mediaPath;

  const PlayerScreen({super.key, required this.mediaPath});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  late final NativeEngineOrchestrator _aiEngine;

  bool _isPlaying = true;
  bool _isLocked = false;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  final EnhancementConfig _enhancementConfig = EnhancementConfig();
  final SubtitleConfig _subtitleConfig = SubtitleConfig();
  final AudioConfig _audioConfig = AudioConfig();
  late final VideoEffectsService _videoEffectsService;
  VideoEffectsConfig _videoEffectsConfig = VideoEffectsConfig();
  VideoEffectsConfig? _userSavedEffectsConfig;

  String _decoderMode = 'Auto';
  String _aspectRatio = 'Fit';
  bool _pitchCorrection = true;
  bool _showTelemetry = false;

  // VLC Auto-Rotation & Orientation States
  ScreenOrientationMode _orientationMode = ScreenOrientationMode.matchVideo;
  int _videoRotationQuarterTurns = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  bool _autoOrientOnStart = true;

  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack _selectedSubtitleTrack = SubtitleTrack.no();

  // --- Phase 3: Gesture Engine States ---
  bool _gesturesEnabled = true;
  double _brightness = 0.5;
  double _volume = 100.0;

  bool _isSwiping = false;
  double _swipeStartY = 0.0;
  double _swipeStartX = 0.0;
  String _swipeAction = '';
  Duration _seekStartPos = Duration.zero;

  // Visual feedback overlay
  String _feedbackText = '';
  IconData? _feedbackIcon;
  bool _showFeedback = false;
  Timer? _feedbackTimer;

  // Zoom/Pan
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _baseOffset = Offset.zero;

  // --- Auto-Hiding Controls Engine (VLC & YouTube Parity) ---
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  static const Duration _controlsTimeout = Duration(milliseconds: 2800);

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (!_isPlaying || _isSwiping) return;
    _controlsTimer = Timer(_controlsTimeout, () {
      if (mounted && _isPlaying && !_isSwiping) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _startControlsTimer();
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(libass: true),
    );
    _controller = VideoController(_player);
    _aiEngine = NativeEngineOrchestrator();
    try {
      _aiEngine.initialize();
    } catch (e) {
      debugPrint("AI load err: $e");
    }

    _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
        if (playing) {
          _startControlsTimer();
        } else {
          _controlsTimer?.cancel();
          setState(() => _controlsVisible = true);
        }
      }
      if (!playing) _persistProgress();
    });
    _player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _player.stream.rate.listen((rate) {
      if (mounted) setState(() => _playbackSpeed = rate);
    });
    _player.stream.tracks.listen((tracks) {
      if (mounted) setState(() => _subtitleTracks = tracks.subtitle);
    });
    _player.stream.track.listen((track) {
      if (mounted) setState(() => _selectedSubtitleTrack = track.subtitle);
    });
    _player.stream.volume.listen((vol) {
      if (mounted && !_isSwiping) _volume = vol;
    });

    // Auto-orient listener (VLC parity: detects video aspect ratio upon header load)
    _player.stream.width.listen((w) {
      if (mounted) _checkAutoOrient();
    });
    _player.stream.height.listen((h) {
      if (mounted) _checkAutoOrient();
    });

    _videoEffectsService = VideoEffectsService();
    _videoEffectsService.loadFromPreferences().then((cfg) {
      if (mounted) {
        setState(() => _videoEffectsConfig = cfg);
        _videoEffectsService.apply(_player, cfg);
      }
    });

    try {
      _player.open(Media(widget.mediaPath));
    } catch (e) {
      debugPrint("Media open err: $e");
    }
    _startControlsTimer();
  }

  void _persistProgress() {
    if (!mounted) return;
    try {
      context.read<LibraryProvider>().updateWatchProgress(
            widget.mediaPath,
            _position.inMilliseconds,
            _duration.inMilliseconds,
          );
    } catch (_) {}
  }

  @override
  void dispose() {
    _persistProgress();
    _controlsTimer?.cancel();
    _feedbackTimer?.cancel();
    VideoRotationService.resetOrientation();
    _videoEffectsService.dispose();
    _aiEngine.shutdown();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
  }

  void _showFeedbackMessage(String msg, IconData icon) {
    setState(() {
      _feedbackText = msg;
      _feedbackIcon = icon;
      _showFeedback = true;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showFeedback = false);
    });
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (!_gesturesEnabled || _isLocked) return;
    _showControls();
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;
    if (dx < screenWidth * 0.33) {
      final newPos = _position - const Duration(seconds: 10);
      _aiEngine.invalidateQueue();
      _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
      _showFeedbackMessage("-10s", Icons.fast_rewind);
    } else if (dx > screenWidth * 0.66) {
      final newPos = _position + const Duration(seconds: 10);
      _aiEngine.invalidateQueue();
      _player.seek(newPos > _duration ? _duration : newPos);
      _showFeedbackMessage("+10s", Icons.fast_forward);
    } else {
      if (_isPlaying) {
        _player.pause();
        _showFeedbackMessage("Paused", Icons.pause);
      } else {
        _player.play();
        _showFeedbackMessage("Play", Icons.play_arrow);
      }
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!_gesturesEnabled || _isLocked) return;
    _controlsTimer?.cancel();
    _isSwiping = true;
    _swipeStartX = details.localFocalPoint.dx;
    _swipeStartY = details.localFocalPoint.dy;
    _seekStartPos = _position;

    if (details.pointerCount == 1) {
      final screenWidth = MediaQuery.of(context).size.width;
      if (_swipeStartX < screenWidth * 0.3) {
        _swipeAction = 'brightness';
      } else if (_swipeStartX > screenWidth * 0.7) {
        _swipeAction = 'volume';
      } else {
        _swipeAction = 'seek';
      }
    } else {
      _baseScale = _scale;
      _baseOffset = _offset;
      _swipeAction = 'zoom_or_speed';
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_gesturesEnabled || _isLocked || !_isSwiping) return;

    if (details.pointerCount >= 2) {
      if ((details.scale - 1.0).abs() > 0.05 || _scale != 1.0) {
        setState(() {
          _scale = (_baseScale * details.scale).clamp(1.0, 4.0);
          if (_scale > 1.0) {
            _offset = _baseOffset + details.focalPointDelta;
          } else {
            _offset = Offset.zero;
          }
        });
      } else {
        final dy = details.localFocalPoint.dy - _swipeStartY;
        if (dy.abs() > 30) {
          final delta = dy > 0 ? -0.25 : 0.25;
          double newRate = (_playbackSpeed + delta).clamp(0.25, 8.0);
          if (newRate != _playbackSpeed) {
            _player.setRate(newRate);
            _swipeStartY = details.localFocalPoint.dy;
            _showFeedbackMessage("${newRate.toStringAsFixed(2)}x", Icons.speed);
          }
        }
      }
      return;
    }

    if (details.pointerCount == 1) {
      final dx = details.localFocalPoint.dx - _swipeStartX;
      final dy = details.localFocalPoint.dy - _swipeStartY;

      if (_swipeAction == 'volume') {
        _volume = (_volume - (dy * 0.5)).clamp(0.0, 100.0);
        _player.setVolume(_volume);
        _swipeStartY = details.localFocalPoint.dy;
        _showFeedbackMessage("Vol: ${_volume.toInt()}%", Icons.volume_up);
      } else if (_swipeAction == 'brightness') {
        _brightness = (_brightness - (dy * 0.005)).clamp(0.0, 1.0);
        _swipeStartY = details.localFocalPoint.dy;
        _showFeedbackMessage("Br: ${(_brightness * 100).toInt()}%", Icons.brightness_6);
      } else if (_swipeAction == 'seek') {
        final seekSeconds = (dx * 0.5).toInt();
        var newPos = _seekStartPos + Duration(seconds: seekSeconds);
        if (newPos < Duration.zero) newPos = Duration.zero;
        if (newPos > _duration) newPos = _duration;
        _aiEngine.invalidateQueue();
        _player.seek(newPos);
        _showFeedbackMessage(_formatDuration(newPos), Icons.schedule);
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _isSwiping = false;
    _swipeAction = '';
    _startControlsTimer();
  }

  void _applyEnhancements() {
    try {
      if (_enhancementConfig.masterToggle) {
        // Save current user video effects before applying AI enhancement profile
        _userSavedEffectsConfig ??= _videoEffectsConfig.copyWith();

        // Convert Enhancement profile into full VLC-grade Video Effects pipeline
        final targetConfig = _enhancementConfig.toVideoEffectsConfig();

        // Preserve any active geometric transforms from video effects
        targetConfig.flipHorizontal = _videoEffectsConfig.flipHorizontal;
        targetConfig.flipVertical = _videoEffectsConfig.flipVertical;
        targetConfig.rotationAngle = _videoEffectsConfig.rotationAngle;

        _videoEffectsConfig = targetConfig;
        _videoEffectsService.apply(_player, targetConfig, immediateVf: true);

        // Audio enhancement & Night mode handling
        if (_enhancementConfig.audioEnhance) {
          _player.setVolume(150.0);
        } else if (_enhancementConfig.nightMode) {
          _player.setVolume(75.0);
        } else {
          _player.setVolume(100.0);
        }
      } else {
        // Restore user manual video effects (from in-memory backup or storage)
        if (_userSavedEffectsConfig != null) {
          final restored = _userSavedEffectsConfig!;
          _userSavedEffectsConfig = null;
          setState(() => _videoEffectsConfig = restored);
          _videoEffectsService.apply(_player, restored, immediateVf: true);
        } else {
          _videoEffectsService.loadFromPreferences().then((cfg) {
            if (mounted) {
              setState(() => _videoEffectsConfig = cfg);
              _videoEffectsService.apply(_player, cfg, immediateVf: true);
            }
          });
        }
        _player.setVolume(100.0);
      }
    } catch (e) {
      debugPrint("[Enhancement] Error applying enhancements: $e");
    }
  }

  void _setDecoderMode(String mode) async {
    setState(() => _decoderMode = mode);
    final dynamic platform = _player.platform;
    try {
      String hwdecValue = 'auto';
      if (mode == 'HW') {
        hwdecValue = 'yes';
      } else if (mode == 'HW+') {
        hwdecValue = 'auto-copy';
      } else if (mode == 'SW') {
        hwdecValue = 'no';
      }
      await platform.setProperty('hwdec', hwdecValue);
    } catch (e) {
      debugPrint("hwdec err: $e");
    }
  }

  void _showDecoderMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.surface,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Decoder Mode', style: EDesign.h3),
            ),
            for (final mode in ['Auto', 'HW', 'HW+', 'SW'])
              ListTile(
                title: Text(mode, style: EDesign.body),
                trailing: _decoderMode == mode
                    ? const Icon(Icons.check, color: EDesign.primary)
                    : null,
                onTap: () {
                  _setDecoderMode(mode);
                  Navigator.pop(context);
                },
              ),
          ],
        );
      },
    );
  }

  void _setAspectRatio(String ratio) {
    setState(() {
      _aspectRatio = ratio;
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  void _cyclePlaybackSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    int currentIndex = speeds.indexOf(_playbackSpeed);
    int nextIndex = (currentIndex + 1) % speeds.length;
    final nextSpeed = speeds[nextIndex];
    setState(() => _playbackSpeed = nextSpeed);
    _player.setRate(nextSpeed);
    _showFeedbackMessage('Speed: ${nextSpeed}x', Icons.speed);
    _showControls();
  }

  void _showAspectRatioMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final ratios = [
          {'id': 'Original', 'title': 'Auto', 'subtitle': 'Original', 'icon': Icons.crop_original},
          {'id': '16:9', 'title': '16:9', 'subtitle': 'Widescreen', 'icon': Icons.tv},
          {'id': '4:3', 'title': '4:3', 'subtitle': 'Standard', 'icon': Icons.aspect_ratio},
          {'id': 'Fill', 'title': 'Fill', 'subtitle': 'Stretch', 'icon': Icons.fullscreen},
          {'id': 'Fit', 'title': 'Fit', 'subtitle': 'Best fit', 'icon': Icons.fit_screen},
          {'id': 'Crop', 'title': 'Crop', 'subtitle': 'Zoom fill', 'icon': Icons.crop},
        ];

        return Container(
          decoration: BoxDecoration(
            color: EDesign.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: EDesign.border),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Aspect Ratio',
                style: TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                itemCount: ratios.length,
                itemBuilder: (context, i) {
                  final r = ratios[i];
                  final isSelected = _aspectRatio == r['id'];
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      _setAspectRatio(r['id'] as String);
                      Navigator.pop(context);
                      _showFeedbackMessage('Aspect: ${r['title']}', r['icon'] as IconData);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? EDesign.primary.withValues(alpha: 0.18) : EDesign.elevatedSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? EDesign.primary : EDesign.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            r['icon'] as IconData,
                            color: isSelected ? EDesign.primary : Colors.white70,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r['title'] as String,
                            style: TextStyle(
                              color: isSelected ? EDesign.primary : EDesign.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            r['subtitle'] as String,
                            style: TextStyle(
                              color: isSelected ? EDesign.primary.withValues(alpha: 0.8) : EDesign.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.surface,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0).copyWith(bottom: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Playback Speed', style: EDesign.h3),
                  const SizedBox(height: 16),
                  Text(
                    '${_playbackSpeed.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      color: EDesign.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: _playbackSpeed,
                    min: 0.25,
                    max: 8.0,
                    divisions: 31,
                    onChanged: (v) {
                      setModalState(() => _playbackSpeed = v);
                      setState(() => _playbackSpeed = v);
                      _player.setRate(v);
                    },
                    activeColor: EDesign.primary,
                  ),
                  SwitchListTile(
                    title: const Text('Pitch Correction', style: EDesign.body),
                    value: _pitchCorrection,
                    activeThumbColor: EDesign.primary,
                    onChanged: (v) {
                      setModalState(() => _pitchCorrection = v);
                      setState(() => _pitchCorrection = v);
                      _player.setPitch(_pitchCorrection ? 1.0 : _playbackSpeed);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [0.5, 1.0, 1.25, 1.5, 2.0]
                        .map(
                          (s) => TextButton(
                            onPressed: () {
                              setModalState(() => _playbackSpeed = s);
                              setState(() => _playbackSpeed = s);
                              _player.setRate(s);
                            },
                            child: Text('${s}x', style: EDesign.body),
                          ),
                        )
                        .toList(),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSubtitleMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.surface,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Subtitles', style: EDesign.h3),
            ),
            if (_subtitleTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No subtitle tracks found', style: EDesign.secondaryStyle),
              ),
            for (final track in _subtitleTracks)
              ListTile(
                title: Text(track.title ?? track.language ?? track.id, style: EDesign.body),
                trailing: _selectedSubtitleTrack == track
                    ? const Icon(Icons.check, color: EDesign.primary)
                    : null,
                onTap: () {
                  _player.setSubtitleTrack(track);
                  Navigator.pop(context);
                },
              ),
            const Divider(color: EDesign.border),
            ListTile(
              leading: const Icon(Icons.tune, color: EDesign.textPrimary),
              title: const Text('Styles & Delay...', style: EDesign.body),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => SubtitleSettingsSheet(
                    player: _player,
                    config: _subtitleConfig,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_open, color: EDesign.textPrimary),
              title: const Text('Load external subtitle...', style: EDesign.body),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.pickFile(
                  type: FileType.custom,
                  allowedExtensions: ['srt', 'ass', 'vtt'],
                );
                if (result != null && result.path != null) {
                  _player.setSubtitleTrack(
                    SubtitleTrack.uri(File(result.path!).uri.toString()),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  BoxFit _getFit() {
    switch (_aspectRatio) {
      case 'Fill':
        return BoxFit.fill;
      case 'Crop':
        return BoxFit.cover;
      case 'Stretch':
        return BoxFit.fill;
      case 'Pan & Scan':
        return BoxFit.cover;
      case 'Original':
        return BoxFit.none;
      default:
        return BoxFit.contain;
    }
  }

  double? _getAspectRatio() {
    switch (_aspectRatio) {
      case '16:9':
        return 16 / 9;
      case '4:3':
        return 4 / 3;
      case '21:9':
        return 21 / 9;
      default:
        return null;
    }
  }

  // --- VLC Auto-Rotation & Orientation Helpers ---

  IconData _getOrientationIcon() {
    switch (_orientationMode) {
      case ScreenOrientationMode.sensor:
        return Icons.screen_rotation;
      case ScreenOrientationMode.landscape:
        return Icons.screen_lock_landscape;
      case ScreenOrientationMode.portrait:
        return Icons.screen_lock_portrait;
      case ScreenOrientationMode.matchVideo:
        return Icons.auto_mode;
    }
  }

  void _cycleOrientationMode() {
    final nextMode = VideoRotationService.getNextMode(_orientationMode);
    setState(() => _orientationMode = nextMode);
    VideoRotationService.applyOrientation(
      nextMode,
      videoWidth: _player.state.width,
      videoHeight: _player.state.height,
    );
    _showFeedbackMessage(
      "Screen: ${VideoRotationService.getModeLabel(nextMode)}",
      _getOrientationIcon(),
    );
  }

  void _cycleVideoRotation() {
    setState(() {
      _videoRotationQuarterTurns = (_videoRotationQuarterTurns + 1) % 4;
    });
    _showFeedbackMessage(
      "Video: ${_videoRotationQuarterTurns * 90}°",
      Icons.rotate_90_degrees_cw,
    );
  }

  void _checkAutoOrient() {
    if (!_autoOrientOnStart || _orientationMode != ScreenOrientationMode.matchVideo) return;
    final w = _player.state.width;
    final h = _player.state.height;
    if (w != null && h != null && w > 0 && h > 0) {
      VideoRotationService.applyOrientation(
        ScreenOrientationMode.matchVideo,
        videoWidth: w,
        videoHeight: h,
      );
    }
  }

  void _showOrientationMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Screen Orientation', style: EDesign.h3),
              const SizedBox(height: 12),
              ...ScreenOrientationMode.values.map((mode) {
                final isSelected = _orientationMode == mode;
                return ListTile(
                  title: Text(VideoRotationService.getModeLabel(mode), style: EDesign.body),
                  leading: Icon(
                    mode == ScreenOrientationMode.sensor
                        ? Icons.screen_rotation
                        : (mode == ScreenOrientationMode.landscape
                            ? Icons.screen_lock_landscape
                            : (mode == ScreenOrientationMode.portrait
                                ? Icons.screen_lock_portrait
                                : Icons.auto_mode)),
                    color: isSelected ? EDesign.primary : Colors.white70,
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: EDesign.primary) : null,
                  onTap: () {
                    setState(() => _orientationMode = mode);
                    VideoRotationService.applyOrientation(
                      mode,
                      videoWidth: _player.state.width,
                      videoHeight: _player.state.height,
                    );
                    Navigator.pop(context);
                    _showFeedbackMessage(
                      "Screen: ${VideoRotationService.getModeLabel(mode)}",
                      _getOrientationIcon(),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showVideoRotationMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Video Stream Rotation (VLC Transform)', style: EDesign.h3),
              const SizedBox(height: 12),
              ...[0, 1, 2, 3].map((turns) {
                final degrees = turns * 90;
                final isSelected = _videoRotationQuarterTurns == turns;
                return ListTile(
                  title: Text('$degrees° ${turns == 0 ? "(Default)" : ""}', style: EDesign.body),
                  leading: Icon(Icons.rotate_right, color: isSelected ? EDesign.primary : Colors.white70),
                  trailing: isSelected ? const Icon(Icons.check, color: EDesign.primary) : null,
                  onTap: () {
                    setState(() => _videoRotationQuarterTurns = turns);
                    Navigator.pop(context);
                    _showFeedbackMessage("Video: $degrees°", Icons.rotate_right);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showVideoEffectsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.70,
          child: VideoEffectsSheet(
            player: _player,
            config: _videoEffectsConfig,
            service: _videoEffectsService,
            onConfigChanged: () {
              setState(() {});
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetRatio = _getAspectRatio();
    Widget videoWidget = Video(
      controller: _controller,
      fit: _getFit(),
      controls: NoVideoControls,
    );
    if (targetRatio != null) {
      videoWidget = AspectRatio(
        aspectRatio: targetRatio,
        child: videoWidget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: Drawer(
        backgroundColor: EDesign.appBackground,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: EDesign.surface),
              child: Text('Player Settings', style: EDesign.h2),
            ),
            SwitchListTile(
              title: const Text('Gesture Controls', style: EDesign.body),
              value: _gesturesEnabled,
              activeThumbColor: EDesign.primary,
              onChanged: (v) => setState(() => _gesturesEnabled = v),
            ),
            SwitchListTile(
              title: const Text('Auto-Orient on Play', style: EDesign.body),
              subtitle: const Text('Matches screen to video aspect ratio', style: EDesign.caption),
              value: _autoOrientOnStart,
              activeThumbColor: EDesign.primary,
              onChanged: (v) => setState(() => _autoOrientOnStart = v),
            ),
            ListTile(
              leading: const Icon(Icons.screen_rotation, color: EDesign.primary),
              title: const Text('Screen Orientation', style: EDesign.body),
              subtitle: Text(VideoRotationService.getModeLabel(_orientationMode), style: EDesign.caption),
              trailing: IconButton(
                icon: const Icon(Icons.sync, color: EDesign.textSecondary, size: 20),
                tooltip: 'Cycle Mode',
                onPressed: _cycleOrientationMode,
              ),
              onTap: () {
                Navigator.pop(context);
                _showOrientationMenu();
              },
            ),
            ListTile(
              leading: const Icon(Icons.rotate_90_degrees_cw, color: EDesign.primary),
              title: const Text('Video Stream Rotation', style: EDesign.body),
              subtitle: Text('${_videoRotationQuarterTurns * 90}°', style: EDesign.caption),
              trailing: IconButton(
                icon: const Icon(Icons.rotate_right, color: EDesign.textSecondary, size: 20),
                tooltip: 'Rotate 90°',
                onPressed: _cycleVideoRotation,
              ),
              onTap: () {
                Navigator.pop(context);
                _showVideoRotationMenu();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune, color: EDesign.primaryCyan),
              title: const Text('Video Effects Studio', style: EDesign.body),
              subtitle: const Text('Essential, Colors, Geometry & Presets', style: EDesign.caption),
              onTap: () {
                Navigator.pop(context);
                _showVideoEffectsSheet();
              },
            ),
            SwitchListTile(
              title: const Text('Telemetry HUD', style: EDesign.body),
              subtitle: const Text('Real-time bitrate, decoder and resolution overlay', style: EDesign.caption),
              value: _showTelemetry,
              activeThumbColor: EDesign.primary,
              onChanged: (v) => setState(() => _showTelemetry = v),
            ),
          ],
        ),
      ),
      body: MouseRegion(
        cursor: _controlsVisible ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onHover: (_) => _showControls(),
        onEnter: (_) => _showControls(),
        child: GestureDetector(
          onTap: _toggleControls,
          onDoubleTapDown: _onDoubleTapDown,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Video Layer with Hardware-Accelerated RotatedBox (VLC libtransform parity) and ColorFilter / Transforms
              Center(
                child: Transform.translate(
                  offset: _offset,
                  child: Transform.scale(
                    scale: _scale,
                    child: Transform.rotate(
                      angle: _videoEffectsConfig.rotationAngle * (3.141592653589793 / 180.0),
                      child: RotatedBox(
                        quarterTurns: _videoRotationQuarterTurns,
                        child: videoWidget,
                      ),
                    ),
                  ),
                ),
              ),

              // Top Gradient Overlay (Cinematic Auto-Hide)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top Bar Controls (Floating Glassmorphic V3 Overlay - Auto-Hiding)
              Positioned(
                top: 24,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Container(
                      decoration: BoxDecoration(
                        color: EDesign.surface.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(EDesign.r18),
                        border: Border.all(color: EDesign.border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                            tooltip: 'Back',
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.mediaPath.isNotEmpty
                                      ? p.basename(widget.mediaPath)
                                      : 'The Last Horizon.mkv',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: EDesign.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: EDesign.primary.withValues(alpha: 0.7), width: 0.8),
                                      ),
                                      child: Text(
                                        _player.state.width != null && _player.state.width! >= 3840
                                            ? '4K'
                                            : (_player.state.width != null && _player.state.width! >= 1920 ? '1080P' : '4K'),
                                        style: const TextStyle(
                                          color: EDesign.primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: _showDecoderMenu,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.white24, width: 0.8),
                                        ),
                                        child: Text(
                                          _decoderMode,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const EVectorIcon(name: 'cast', size: 19, color: Colors.white),
                            tooltip: 'Cast Media',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CastingScreen()),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.auto_awesome,
                              size: 20,
                              color: _enhancementConfig.masterToggle ? EDesign.aiAccent : Colors.white70,
                            ),
                            tooltip: 'AI Enhancement Studio',
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) {
                                  return SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.70,
                                    child: EnhancementStudioSheet(
                                      aiEngine: _aiEngine,
                                      mediaPath: widget.mediaPath,
                                      config: _enhancementConfig,
                                      onConfigChanged: () {
                                        setState(() {});
                                        _applyEnhancements();
                                      },
                                    ),
                                  );
                                },
                              ).then((_) {
                                setState(() {});
                                _applyEnhancements();
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.subtitles_outlined, color: Colors.white70, size: 20),
                            tooltip: 'Subtitles',
                            onPressed: _showSubtitleMenu,
                          ),
                          Builder(
                            builder: (ctx) => IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                              tooltip: 'Settings',
                              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Gradient Overlay (Cinematic Auto-Hide)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 160,
                child: AnimatedOpacity(
                  opacity: _controlsVisible && !_isLocked ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Visual Feedback Overlay
            if (_showFeedback)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: EDesign.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: EDesign.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_feedbackIcon != null)
                        Icon(_feedbackIcon, color: EDesign.primary, size: 48),
                      if (_feedbackIcon != null) const SizedBox(height: 8),
                      Text(
                        _feedbackText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Controls (Glassmorphic V3 container - Auto-Hiding)
            if (!_isLocked)
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Container(
                      decoration: BoxDecoration(
                        color: EDesign.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(EDesign.r24),
                        border: Border.all(color: EDesign.border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Scrubber and Timestamps (Reference Screen 3)
                          Row(
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: const TextStyle(
                                  color: EDesign.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: EDesign.primary,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: EDesign.primary,
                                    overlayColor: EDesign.primary.withValues(alpha: 0.25),
                                    trackHeight: 4.0,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                                  ),
                                  child: Slider(
                                    value: _position.inMilliseconds.toDouble().clamp(
                                      0.0,
                                      _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                    ),
                                    min: 0.0,
                                    max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                    onChangeStart: (_) {
                                      _controlsTimer?.cancel();
                                    },
                                    onChangeEnd: (_) {
                                      _startControlsTimer();
                                    },
                                    onChanged: (v) {
                                      _aiEngine.invalidateQueue();
                                      _player.seek(Duration(milliseconds: v.toInt()));
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: const TextStyle(
                                  color: EDesign.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Controls Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left: Screen Lock & Speed Pill
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.lock_open_outlined, color: EDesign.textSecondary, size: 20),
                                    tooltip: 'Lock Controls',
                                    onPressed: () {
                                      setState(() => _isLocked = true);
                                      _showFeedbackMessage('Controls Locked', Icons.lock);
                                      _showControls();
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _cyclePlaybackSpeed,
                                    onLongPress: _showSpeedMenu,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: EDesign.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: EDesign.primary.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        '${_playbackSpeed.toStringAsFixed(1)}x',
                                        style: const TextStyle(
                                          color: EDesign.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Center: Replay, Glowing Play/Pause, Forward
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 24),
                                    tooltip: '-10s',
                                    onPressed: () {
                                      final newPos = _position - const Duration(seconds: 10);
                                      _aiEngine.invalidateQueue();
                                      _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
                                      _showControls();
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: EDesign.primary,
                                      boxShadow: [
                                        BoxShadow(
                                          color: EDesign.primary.withValues(alpha: 0.65),
                                          blurRadius: 16,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.black,
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        _showControls();
                                        _isPlaying ? _player.pause() : _player.play();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 24),
                                    tooltip: '+10s',
                                    onPressed: () {
                                      final newPos = _position + const Duration(seconds: 10);
                                      _aiEngine.invalidateQueue();
                                      _player.seek(newPos > _duration ? _duration : newPos);
                                      _showControls();
                                    },
                                  ),
                                ],
                              ),
                              // Right: Audio EQ, Aspect Ratio & Decoder
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.equalizer, color: Colors.white70, size: 20),
                                    tooltip: 'Audio Equalizer',
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        isScrollControlled: true,
                                        builder: (context) => AudioStudioSheet(
                                          player: _player,
                                          config: _audioConfig,
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white70, size: 20),
                                    tooltip: 'Aspect Ratio ($_aspectRatio)',
                                    onPressed: _showAspectRatioMenu,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Floating Unlock Button when locked
            if (_isLocked)
              Positioned(
                left: 20,
                bottom: 30,
                child: FloatingActionButton.small(
                  backgroundColor: EDesign.surface.withValues(alpha: 0.9),
                  foregroundColor: EDesign.warning,
                  onPressed: () {
                    setState(() => _isLocked = false);
                    _showFeedbackMessage('Unlocked', Icons.lock_open);
                    _showControls();
                  },
                  child: const Icon(Icons.lock),
                ),
              ),

            // Telemetry Overlay (Fixed unescaped string interpolation)
            if (_showTelemetry)
              Positioned(
                top: 80,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EDesign.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EDesign.border),
                  ),
                  child: Text(
                    'Decoder: $_decoderMode\n'
                    'Aspect: $_aspectRatio (Zoom: ${_scale.toStringAsFixed(1)}x)\n'
                    'Resolution: ${_player.state.width ?? 0}x${_player.state.height ?? 0}\n'
                    'Video Track: ${_player.state.track.video.title ?? _player.state.track.video.id}\n'
                    'Audio Track: ${_player.state.track.audio.title ?? _player.state.track.audio.id}\n'
                    'Audio Bitrate: ${_player.state.audioBitrate ?? "Unknown"}',
                    style: const TextStyle(
                      color: EDesign.primary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  }
}
