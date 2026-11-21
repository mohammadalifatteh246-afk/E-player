import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../../../../core/engine_orchestrator.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../../widgets/e_player_components.dart';
import '../../casting/ui/cast_sheet.dart';
import '../../casting/domain/cast_service.dart';
import '../../media_info/ui/media_info_sheet.dart';
import '../../enhancement/ui/enhancement_studio_sheet.dart';
import '../../library/domain/library_provider.dart';
import '../../video_effects/models/video_effects_config.dart';
import '../../video_effects/domain/video_effects_service.dart';
import '../../video_effects/ui/video_effects_sheet.dart';
import '../../video_effects/ui/video_overlay_widget.dart';
import '../../video_effects/ui/watermark_studio_sheet.dart';
import '../../video_effects/ui/anaglyph_studio_sheet.dart';
import '../../audio/domain/dual_audio_service.dart';
import '../../audio/ui/dual_audio_sheet.dart';
import '../../export/domain/media_converter_service.dart';
import '../../export/ui/media_converter_sheet.dart';
import '../../network_stream/data/dlna_service.dart';
import '../../network_stream/ui/dlna_server_browser_sheet.dart';
import '../../network_stream/data/online_stream_service.dart';
import '../../network_stream/ui/online_stream_sheet.dart';
import 'subtitle_settings_sheet.dart';
import '../../subtitles/domain/dual_subtitle_controller.dart';
import '../../subtitles/ui/dual_subtitle_sheet.dart';
import '../../subtitles/ui/online_subtitles_sheet.dart';
import 'audio_studio_sheet.dart';
import '../domain/video_rotation_service.dart';
import '../domain/decoder_models.dart';
import '../domain/decoder_pipeline_service.dart';
import 'gesture_models.dart';
import 'cinematic_gesture_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../pip/domain/pip_models.dart';
import '../../pip/domain/pip_service.dart';
import 'widgets/desktop_keyboard_handler.dart';
import 'playback_enhancements.dart';
import '../../bookmarks/data/bookmark_service.dart';
import '../../bookmarks/ui/bookmarks_sheet.dart';
import '../services/video_snapshot_service.dart';
import '../services/desktop_tray_audio_service.dart';
import '../services/interactive_zoom_controller.dart';
import 'widgets/interactive_zoom_viewfinder.dart';
import '../../video_effects/domain/puzzle_wall_controller.dart';
import '../../video_effects/ui/puzzle_wall_surface_widget.dart';
import '../../subtitles/data/teletext_closed_caption_controller.dart';
import '../../subtitles/ui/teletext_osd_overlay_widget.dart';
import '../../subtitles/ui/teletext_closed_captions_sheet.dart';
import '../../stream_recorder/data/stream_recorder_controller.dart';
import '../../stream_recorder/ui/stream_recorder_badge_widget.dart';
import '../../stream_recorder/ui/stream_recorder_sheet.dart';
import '../services/desktop_drag_drop_service.dart';
import '../../../core/db/database_helper.dart';
import '../../../core/models/media_item.dart';
import 'widgets/resume_playback_banner_widget.dart';
import '../services/playlist_controller.dart';
import '../services/playlist_serializer.dart';
import 'widgets/undocked_playlist_panel_widget.dart';
import '../../web_remote/data/web_remote_service.dart';
import '../../web_remote/ui/web_remote_sheet.dart';
import '../../archive/services/archive_media_service.dart';

export 'gesture_models.dart' show VolumeSafetyColors;
export 'playback_enhancements.dart' show ABRepeatState, ABRepeatController, CropPreset, AspectCropController, BufferCachingSettingsController;

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
  late final ABRepeatController _abRepeatController;
  late final AspectCropController _cropController;
  late final BufferCachingSettingsController _bufferCachingController;
  late final InteractiveZoomController _interactiveZoomController;
  late final PuzzleWallController _puzzleWallController;
  late final TeletextClosedCaptionController _teletextCcController;
  late final StreamRecorderController _streamRecorderController;
  late final WebRemoteService _webRemoteService;
  late final DualAudioService _dualAudioService;
  late final MediaConverterService _mediaConverterService;
  late final DlnaService _dlnaService;
  late final OnlineStreamService _onlineStreamService;
  bool _showZoomViewfinder = false;
  StreamSubscription<Duration>? _abRepeatPositionSubscription;
  StreamSubscription<TrayPlaybackCommand>? _trayCommandSubscription;
  StreamSubscription<bool>? _trayPlayingSubscription;
  StreamSubscription<Duration>? _trayPositionSubscription;
  StreamSubscription<Duration>? _trayDurationSubscription;
  StreamSubscription<double>? _trayVolumeSubscription;
  StreamSubscription<DroppedMediaEvent>? _dragDropSubscription;
  String? _currentMediaPath;
  bool _showResumePrompt = false;
  Duration? _savedResumePosition;
  bool _showRemainingTime = true;
  late final PlaylistController _playlistController;

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
  late final DecoderPipelineService _decoderPipelineService;
  StreamSubscription<DecoderTelemetry>? _decoderTelemetrySubscription;
  DecoderTelemetry? _latestDecoderTelemetry;
  String _aspectRatio = 'Fit';
  bool _pitchCorrection = true;
  bool _showTelemetry = false;

  // VLC Auto-Rotation & Orientation States
  ScreenOrientationMode _orientationMode = ScreenOrientationMode.matchVideo;
  int _videoRotationQuarterTurns = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  bool _autoOrientOnStart = true;

  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack _selectedSubtitleTrack = SubtitleTrack.no();
  late final DualSubtitleController _dualSubtitleController;

  final FocusNode _keyboardFocusNode = FocusNode();
  List<AudioTrack> _audioTracks = [];
  AudioTrack _selectedAudioTrack = AudioTrack.no();
  double _audioDelayMs = 0.0;
  bool _isFullscreen = false;

  // --- Phase 3: Gesture Engine States ---
  bool _gesturesEnabled = true;
  double _brightness = 0.5;
  double _volume = 100.0;
  late final CinematicGestureEngine _gestureEngine;
  StreamSubscription<GestureFeedbackEvent>? _gestureFeedbackSubscription;
  StreamSubscription<SeekCommitEvent>? _seekCommitSubscription;
  StreamSubscription<bool>? _controlsInhibitedSubscription;

  // HUD Feedback Card states
  GestureFeedbackEvent? _activeFeedbackEvent;
  bool _showFeedbackOverlay = false;
  Timer? _feedbackOverlayTimer;

  // Wing ripple indicators
  bool _leftWingRipple = false;
  bool _rightWingRipple = false;
  Timer? _wingRippleTimer;

  bool get _isSwiping => _gestureEngine.currentMode != GestureMode.idle;

  // Video Snapshot Preview Overlay (VLC Frame Capture Parity)
  SnapshotResult? _lastSnapshotResult;
  Timer? _snapshotPreviewTimer;

  // Visual feedback overlay
  String _feedbackText = '';
  IconData? _feedbackIcon;
  Color? _feedbackColor;
  bool _showFeedback = false;
  Timer? _feedbackTimer;

  // Zoom/Pan
  double _scale = 1.0;
  Offset _offset = Offset.zero;

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

  // --- Phase 6: Picture-in-Picture Coordinator ---
  late final PipService _pipService;
  StreamSubscription<PipAction>? _pipActionSubscription;

  void _onPipServiceChanged() {
    if (!mounted) return;
    if (_pipService.isInPip) {
      if (ModalRoute.of(context)?.isCurrent == false) {
        Navigator.of(context).pop();
      }
      setState(() {
        _controlsVisible = false;
        _showFeedbackOverlay = false;
        _activeFeedbackEvent = null;
        _showFeedback = false;
        _scale = 1.0;
        _offset = Offset.zero;
      });
      _controlsTimer?.cancel();
      _feedbackTimer?.cancel();
      _feedbackOverlayTimer?.cancel();
      _wingRippleTimer?.cancel();
    } else {
      setState(() {
        _controlsVisible = true;
      });
      _startControlsTimer();
    }
  }

  void _handlePipAction(PipAction action) {
    if (!mounted) return;
    switch (action) {
      case PipAction.play:
        _player.play();
        break;
      case PipAction.pause:
        _player.pause();
        break;
      case PipAction.seekForward10:
        final target = _position + const Duration(seconds: 10);
        final clamped = target > _duration ? _duration : target;
        _player.seek(clamped);
        break;
      case PipAction.seekRewind10:
        final target = _position - const Duration(seconds: 10);
        final clamped = target < Duration.zero ? Duration.zero : target;
        _player.seek(clamped);
        break;
      case PipAction.unknown:
        break;
    }
  }

  Future<void> _triggerPip() async {
    final width = _player.state.width ?? 1920;
    final height = _player.state.height ?? 1080;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final size = PipMath.calculateOverlaySize(width, height);
      await _pipService.toggleDesktopOverlay(
        enable: !_pipService.isDesktopOverlay,
        initialSize: size,
      );
    } else {
      await _pipService.enterPip(
        videoWidth: width,
        videoHeight: height,
        isPlaying: _isPlaying,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(libass: true),
    );
    try {
      (_player.platform as dynamic).setProperty('volume-max', '300.0');
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to set volume-max: $e');
    }
    _controller = VideoController(_player);
    _abRepeatController = ABRepeatController();
    _cropController = AspectCropController(_player);
    _dualSubtitleController = DualSubtitleController();
    _dualSubtitleController.attachPlayer(_player);
    _dualSubtitleController.addListener(() {
      if (mounted) setState(() {});
    });
    _bufferCachingController = BufferCachingSettingsController();
    _interactiveZoomController = InteractiveZoomController(player: _player);
    _interactiveZoomController.addListener(() {
      if (mounted) setState(() {});
    });
    BookmarkService.instance.addListener(_onBookmarksChanged);
    _checkResumePosition();
    SharedPreferences.getInstance().then((prefs) {
      if (prefs.containsKey('player_show_remaining_time')) {
        if (mounted) {
          setState(() {
            _showRemainingTime = prefs.getBool('player_show_remaining_time') ?? true;
          });
        }
      }
      _bufferCachingController.loadFromPrefs(prefs).then((_) {
        _bufferCachingController.applyToPlayer(_player);
      });
    }).catchError((e) {
      debugPrint('[PlayerScreen] Failed to load buffer caching settings: $e');
    });
    _aiEngine = NativeEngineOrchestrator();
    try {
      _aiEngine.initialize();
    } catch (e) {
      debugPrint("AI load err: $e");
    }

    _decoderPipelineService = DecoderPipelineService();
    _decoderPipelineService.initialize(_player);
    _decoderTelemetrySubscription =
        _decoderPipelineService.telemetryStream.listen((telemetry) {
      if (mounted) {
        setState(() {
          _latestDecoderTelemetry = telemetry;
          _decoderMode = telemetry.requestedMode.label;
        });
      }
    });

    _pipService = PipService();
    _pipService.isPipSupported();
    _pipService.addListener(_onPipServiceChanged);
    _pipActionSubscription = _pipService.actionStream.listen(_handlePipAction);

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
      _pipService.updatePlaybackState(
        isPlaying: playing,
        videoWidth: _player.state.width,
        videoHeight: _player.state.height,
      );
      if (!playing) _persistProgress();
    });
    _abRepeatPositionSubscription = _player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
      _abRepeatController.checkPosition(pos, onSeek: (target) async {
        await _player.seek(target);
      });
    });
    _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _player.stream.rate.listen((rate) {
      if (mounted) setState(() => _playbackSpeed = rate);
    });
    _player.stream.tracks.listen((tracks) {
      if (mounted) {
        setState(() {
          _subtitleTracks = tracks.subtitle;
          _audioTracks = tracks.audio;
        });
      }
    });
    _player.stream.track.listen((track) {
      if (mounted) {
        setState(() {
          _selectedSubtitleTrack = track.subtitle;
          _selectedAudioTrack = track.audio;
          _dualSubtitleController.setPrimaryTrack(track.subtitle);
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_keyboardFocusNode.hasFocus) {
        _keyboardFocusNode.requestFocus();
      }
    });
    _player.stream.volume.listen((vol) {
      if (mounted && !_isSwiping) _volume = vol;
    });

    // VLC Parity: Background Audio Daemon & Desktop System Tray Sync
    _trayPlayingSubscription = _player.stream.playing.listen((playing) {
      DesktopTrayAudioService.instance.updatePlaybackState(
        isPlaying: playing,
        mediaTitle: p.basename(widget.mediaPath),
      );
    });
    _trayPositionSubscription = _player.stream.position.listen((pos) {
      DesktopTrayAudioService.instance.updatePlaybackState(position: pos);
    });
    _trayDurationSubscription = _player.stream.duration.listen((dur) {
      DesktopTrayAudioService.instance.updatePlaybackState(duration: dur);
    });
    _trayVolumeSubscription = _player.stream.volume.listen((vol) {
      DesktopTrayAudioService.instance.updatePlaybackState(volume: vol);
    });
    _trayCommandSubscription =
        DesktopTrayAudioService.instance.commandStream.listen((cmd) {
      if (!mounted) return;
      switch (cmd) {
        case TrayPlaybackCommand.playPause:
          _player.playOrPause();
          break;
        case TrayPlaybackCommand.volumeUp:
          final currentVol = _player.state.volume;
          final targetVol = (currentVol + 5.0).clamp(0.0, 300.0);
          _player.setVolume(targetVol);
          break;
        case TrayPlaybackCommand.volumeDown:
          final currentVol = _player.state.volume;
          final targetVol = (currentVol - 5.0).clamp(0.0, 300.0);
          _player.setVolume(targetVol);
          break;
        case TrayPlaybackCommand.stop:
          _player.stop();
          break;
        case TrayPlaybackCommand.next:
        case TrayPlaybackCommand.previous:
        case TrayPlaybackCommand.toggleWindow:
          break;
      }
    });

    DesktopDragDropService.instance.initialize();
    _dragDropSubscription =
        DesktopDragDropService.instance.stream.listen(_handleDroppedMedia);

    // Auto-orient listener (VLC parity: detects video aspect ratio upon header load)
    _player.stream.width.listen((w) {
      if (mounted) {
        _checkAutoOrient();
        _pipService.updatePlaybackState(
          isPlaying: _isPlaying,
          videoWidth: w,
          videoHeight: _player.state.height,
        );
      }
    });
    _player.stream.height.listen((h) {
      if (mounted) {
        _checkAutoOrient();
        _pipService.updatePlaybackState(
          isPlaying: _isPlaying,
          videoWidth: _player.state.width,
          videoHeight: h,
        );
      }
    });

    _videoEffectsService = VideoEffectsService();
    _puzzleWallController = PuzzleWallController(
      puzzleRows: _videoEffectsConfig.puzzleRows,
      puzzleCols: _videoEffectsConfig.puzzleCols,
      puzzleMode: _videoEffectsConfig.puzzleMode,
      puzzleAllowRotation: _videoEffectsConfig.puzzleAllowRotation,
      wallRows: _videoEffectsConfig.wallRows,
      wallCols: _videoEffectsConfig.wallCols,
      wallBezel: _videoEffectsConfig.wallBezel,
    );
    _puzzleWallController.addListener(() {
      if (mounted) setState(() {});
    });
    _teletextCcController = TeletextClosedCaptionController(player: _player);
    _teletextCcController.addListener(() {
      if (mounted) setState(() {});
    });
    _streamRecorderController = StreamRecorderController(player: _player);
    _streamRecorderController.addListener(() {
      if (mounted) setState(() {});
    });
    _playlistController = PlaylistController();
    _playlistController.addListener(() {
      if (mounted) setState(() {});
    });
    _webRemoteService = WebRemoteService();
    _webRemoteService.statusProvider = () {
      final activePath = _currentMediaPath ?? widget.mediaPath;
      return WebRemoteStatus(
        isPlaying: _player.state.playing,
        title: p.basename(activePath),
        positionMs: _player.state.position.inMilliseconds,
        durationMs: _player.state.duration.inMilliseconds,
        volume: _player.state.volume,
        aspectRatio: _cropController.current.label,
        isMuted: _player.state.volume <= 0.0,
        currentAudioTrack: _player.state.track.audio.id,
        currentSubtitleTrack: _player.state.track.subtitle.id,
        abRepeatState: _abRepeatController.state.name,
      );
    };
    _webRemoteService.onPlayPause = () => _player.playOrPause();
    _webRemoteService.onSeek = (posMs) => _player.seek(Duration(milliseconds: posMs));
    _webRemoteService.onSetVolume = (vol) => _player.setVolume(vol);
    _webRemoteService.onCycleAspectRatio = () {
      _cycleCropRatio();
    };
    _webRemoteService.onStepFrame = () => _stepFrame();
    _webRemoteService.onCycleABRepeat = () {
      _cycleABRepeat();
    };
    _webRemoteService.onNext = () {
      final nextTrack = _playlistController.getNextTrack();
      if (nextTrack != null) _playMediaItem(nextTrack);
    };
    _webRemoteService.onPrevious = () {
      final prevTrack = _playlistController.getPreviousTrack();
      if (prevTrack != null) _playMediaItem(prevTrack);
    };
    _webRemoteService.onToggleFullscreen = () => _toggleFullscreen();
    _webRemoteService.onCycleSubtitle = () => _cycleSubtitleTrack();
    _webRemoteService.onCycleAudio = () => _cycleAudioTrack();
    _webRemoteService.addListener(() {
      if (mounted) setState(() {});
    });
    _dualAudioService = DualAudioService();
    _dualAudioService.addListener(() {
      if (mounted) setState(() {});
    });
    _mediaConverterService = MediaConverterService();
    _mediaConverterService.addListener(() {
      if (mounted) setState(() {});
    });
    _dlnaService = DlnaService();
    _dlnaService.addListener(() {
      if (mounted) setState(() {});
    });
    _onlineStreamService = OnlineStreamService();
    _onlineStreamService.addListener(() {
      if (mounted) setState(() {});
    });
    _initOnlineStreamService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final lib = context.read<LibraryProvider>();
        final all = lib.allFiles;
        final currentPath = _currentMediaPath ?? widget.mediaPath;
        if (all.isNotEmpty) {
          _playlistController.setItems(all, activePath: currentPath);
        } else if (currentPath.isNotEmpty) {
          _playlistController.setItems([
            MediaItem(
              path: currentPath,
              name: p.basename(currentPath),
              parentFolder: p.dirname(currentPath),
              lastPlayed: DateTime.now(),
            )
          ], activePath: currentPath);
        }
      } catch (_) {
        final currentPath = _currentMediaPath ?? widget.mediaPath;
        if (currentPath.isNotEmpty) {
          _playlistController.setItems([
            MediaItem(
              path: currentPath,
              name: p.basename(currentPath),
              parentFolder: p.dirname(currentPath),
              lastPlayed: DateTime.now(),
            )
          ], activePath: currentPath);
        }
      }
    });
    _videoEffectsService.loadFromPreferences().then((cfg) {
      if (mounted) {
        setState(() => _videoEffectsConfig = cfg);
        _videoEffectsService.apply(_player, cfg);
        _puzzleWallController.syncWithConfig(cfg);
      }
    });

    _gestureEngine = CinematicGestureEngine(
      initialBrightness: _brightness,
      initialVolume: _volume,
      onBrightnessChanged: (b) {
        if (mounted) setState(() => _brightness = b);
      },
      onVolumeChanged: (v) {
        _player.setVolume(v);
        if (mounted) setState(() => _volume = v);
      },
      onTogglePlayPause: () {
        if (_isPlaying) {
          _player.pause();
          _showFeedbackMessage("Paused", Icons.pause);
        } else {
          _player.play();
          _showFeedbackMessage("Play", Icons.play_arrow);
        }
      },
    );

    _gestureFeedbackSubscription = _gestureEngine.feedbackEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        _activeFeedbackEvent = event;
        _showFeedbackOverlay = true;
        _scale = _gestureEngine.scale;
        _offset = _gestureEngine.panOffset;

        if (event.type == GestureFeedbackType.wingJump) {
          if (event.value < 0) {
            _leftWingRipple = true;
            _rightWingRipple = false;
          } else {
            _rightWingRipple = true;
            _leftWingRipple = false;
          }
          _wingRippleTimer?.cancel();
          _wingRippleTimer = Timer(const Duration(milliseconds: 650), () {
            if (mounted) {
              setState(() {
                _leftWingRipple = false;
                _rightWingRipple = false;
              });
            }
          });
        }
      });

      _feedbackOverlayTimer?.cancel();
      _feedbackOverlayTimer =
          Timer(CinematicGestureConfig.feedbackLingeringDuration, () {
        if (mounted) {
          setState(() => _showFeedbackOverlay = false);
        }
      });
    });

    _seekCommitSubscription = _gestureEngine.seekCommitEvents.listen((event) {
      _aiEngine.invalidateQueue();
      _player.seek(event.target);
    });

    _controlsInhibitedSubscription =
        _gestureEngine.controlsInhibited.listen((inhibited) {
      if (inhibited) {
        _controlsTimer?.cancel();
      } else {
        _startControlsTimer();
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
    _abRepeatPositionSubscription?.cancel();
    _gestureFeedbackSubscription?.cancel();
    _seekCommitSubscription?.cancel();
    _controlsInhibitedSubscription?.cancel();
    _feedbackOverlayTimer?.cancel();
    _wingRippleTimer?.cancel();
    _gestureEngine.dispose();
    _decoderTelemetrySubscription?.cancel();
    _decoderPipelineService.dispose();
    _pipActionSubscription?.cancel();
    _pipService.removeListener(_onPipServiceChanged);
    _pipService.dispose();
    BookmarkService.instance.removeListener(_onBookmarksChanged);
    _snapshotPreviewTimer?.cancel();
    _trayPlayingSubscription?.cancel();
    _trayPositionSubscription?.cancel();
    _trayDurationSubscription?.cancel();
    _trayVolumeSubscription?.cancel();
    _trayCommandSubscription?.cancel();
    _dragDropSubscription?.cancel();
    DesktopTrayAudioService.instance.updatePlaybackState(isPlaying: false);
    _persistProgress();
    _controlsTimer?.cancel();
    _feedbackTimer?.cancel();
    _keyboardFocusNode.dispose();
    _dualSubtitleController.dispose();
    VideoRotationService.resetOrientation();
    _interactiveZoomController.dispose();
    _puzzleWallController.dispose();
    _teletextCcController.dispose();
    _streamRecorderController.dispose();
    _webRemoteService.dispose();
    _dualAudioService.dispose();
    _mediaConverterService.dispose();
    _dlnaService.dispose();
    _onlineStreamService.dispose();
    _playlistController.dispose();
    _videoEffectsService.dispose();
    _aiEngine.shutdown();
    _player.dispose();
    super.dispose();
  }

  void _handleDroppedMedia(DroppedMediaEvent event) {
    if (!mounted) return;

    // 1. If subtitles dropped: attach subtitle track dynamically (VLC parity)
    if (event.hasSubtitle) {
      for (final subItem in event.subtitleItems) {
        try {
          _player.setSubtitleTrack(SubtitleTrack.uri(subItem.path));
          _showFeedbackMessage(
            'Subtitle attached: ${subItem.name}',
            Icons.subtitles_rounded,
            EDesign.primaryCyan,
          );
        } catch (e) {
          debugPrint('[PlayerScreen] Failed to attach dropped subtitle: $e');
        }
      }
      return;
    }

    // 2. If playlist dropped: load & play first track (VLC parity)
    if (event.hasPlaylist) {
      final playlistFile = event.playlistItems.first;
      _playlistController.importPlaylist(playlistFile.path).then((count) {
        if (!mounted) return;
        if (count > 0 && _playlistController.items.isNotEmpty) {
          _playMediaItem(_playlistController.items.first);
          _showFeedbackMessage(
            'Playlist loaded: ${playlistFile.name} ($count tracks)',
            Icons.playlist_play_rounded,
            EDesign.primaryCyan,
          );
        } else {
          _showFeedbackMessage(
            'Playlist empty: ${playlistFile.name}',
            Icons.playlist_remove_rounded,
            EDesign.warning,
          );
        }
      }).catchError((e) {
        debugPrint('[PlayerScreen] Failed to import dropped playlist: $e');
        if (mounted) {
          _showFeedbackMessage(
            'Failed to load playlist',
            Icons.error_outline_rounded,
            EDesign.danger,
          );
        }
      });
      return;
    }

    // 3. If archive (.zip, .tar) dropped: stream directly from archive (VLC parity)
    if (event.hasArchive) {
      final archiveFile = event.archiveItems.first;
      ArchiveMediaService.listMediaInArchive(archiveFile.path).then((entries) async {
        if (!mounted) return;
        if (entries.isEmpty) {
          _showFeedbackMessage(
            'No playable media in ${archiveFile.name}',
            Icons.folder_zip_rounded,
            EDesign.warning,
          );
          return;
        }

        if (entries.length == 1) {
          final extractedPath = await ArchiveMediaService.extractMedia(
            archiveFile.path,
            entries.first.pathInArchive,
          );
          if (extractedPath != null && mounted) {
            final mediaItem = MediaItem(
              path: extractedPath,
              name: '${archiveFile.name} ➔ ${entries.first.name}',
              parentFolder: p.dirname(archiveFile.path),
              lastPlayed: DateTime.now(),
            );
            _playMediaItem(mediaItem);
            _showFeedbackMessage(
              'Playing from archive: ${entries.first.name}',
              Icons.folder_zip_rounded,
              EDesign.primaryCyan,
            );
          }
        } else {
          final playlistItems = <MediaItem>[];
          for (final entry in entries) {
            final extractedPath = await ArchiveMediaService.extractMedia(
              archiveFile.path,
              entry.pathInArchive,
            );
            if (extractedPath != null) {
              playlistItems.add(
                MediaItem(
                  path: extractedPath,
                  name: entry.name,
                  parentFolder: archiveFile.name,
                  lastPlayed: DateTime.now(),
                ),
              );
            }
          }
          if (playlistItems.isNotEmpty && mounted) {
            _playlistController.setItems(playlistItems, activePath: playlistItems.first.path);
            _playMediaItem(playlistItems.first);
            _showFeedbackMessage(
              'Loaded ${playlistItems.length} tracks from ${archiveFile.name}',
              Icons.folder_zip_rounded,
              EDesign.primaryCyan,
            );
          }
        }
      }).catchError((e) {
        debugPrint('[PlayerScreen] Failed to inspect dropped archive: $e');
        if (mounted) {
          _showFeedbackMessage(
            'Failed to read archive',
            Icons.error_outline_rounded,
            EDesign.danger,
          );
        }
      });
      return;
    }

    // 4. If video or audio dropped: play primary media (VLC parity)
    if (event.hasVideoAudio) {
      final mediaItem = event.videoAudioItems.first;
      try {
        _player.open(Media(mediaItem.path));
        setState(() {
          _currentMediaPath = mediaItem.path;
          _showResumePrompt = false;
          _savedResumePosition = null;
        });
        final playlistItem = MediaItem(
          path: mediaItem.path,
          name: mediaItem.name,
          parentFolder: p.dirname(mediaItem.path),
          lastPlayed: DateTime.now(),
        );
        if (!_playlistController.items.any((i) => i.path == mediaItem.path)) {
          final updated = List<MediaItem>.from(_playlistController.items)..add(playlistItem);
          _playlistController.setItems(updated, activePath: mediaItem.path);
        } else {
          _playlistController.setCurrentPlayingPath(mediaItem.path);
        }
        _checkResumePosition();
        _showFeedbackMessage(
          'Playing: ${mediaItem.name}',
          Icons.play_circle_fill_rounded,
          EDesign.primaryCyan,
        );
      } catch (e) {
        debugPrint('[PlayerScreen] Failed to open dropped media: $e');
      }
      return;
    }

    // 3. If unsupported file format dropped
    if (event.primaryItem != null) {
      _showFeedbackMessage(
        'Unsupported format: ${event.primaryItem!.name}',
        Icons.warning_amber_rounded,
        Colors.orangeAccent,
      );
    }
  }

  Future<void> _checkResumePosition() async {
    final targetPath = _currentMediaPath ?? widget.mediaPath;
    if (targetPath.isEmpty) return;

    try {
      final item = await DatabaseHelper.instance.getItemByPath(targetPath);
      if (item != null && item.lastPositionMs >= 5000) {
        // Only prompt if not completed (e.g. not within last 15 seconds)
        if (item.durationMs == 0 || item.lastPositionMs < item.durationMs - 15000) {
          if (mounted) {
            setState(() {
              _savedResumePosition = Duration(milliseconds: item.lastPositionMs);
              _showResumePrompt = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to query resume position: $e');
    }
  }

  void _handleResumePlayback() {
    if (_savedResumePosition != null) {
      _player.seek(_savedResumePosition!);
      _showFeedbackMessage(
        'Resumed from ${_formatDuration(_savedResumePosition!)}',
        Icons.history_rounded,
        EDesign.primaryCyan,
      );
    }
    if (mounted) {
      setState(() => _showResumePrompt = false);
    }
  }

  void _handleRestartPlayback() {
    _player.seek(Duration.zero);
    _showFeedbackMessage(
      'Restarted from beginning',
      Icons.replay_rounded,
      EDesign.primaryCyan,
    );
    if (mounted) {
      setState(() => _showResumePrompt = false);
    }
    final targetPath = _currentMediaPath ?? widget.mediaPath;
    if (targetPath.isNotEmpty) {
      try {
        context.read<LibraryProvider>().updateWatchProgress(
              targetPath,
              0,
              _duration.inMilliseconds,
            );
      } catch (_) {}
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds";
  }

  String _formatPosition(Duration d) {
    if (d < Duration.zero) d = Duration.zero;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '${d.inHours}:$minutes:$seconds';
    } else {
      final minutes = d.inMinutes.remainder(60).toString();
      return '$minutes:$seconds';
    }
  }

  String _formatRemainingDuration(Duration pos, Duration dur) {
    if (dur <= Duration.zero || dur < pos) return '- 0:00';
    final remaining = dur - pos;
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (remaining.inHours > 0) {
      final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '- ${remaining.inHours}:$minutes:$seconds';
    } else {
      final minutes = remaining.inMinutes.remainder(60).toString();
      return '- $minutes:$seconds';
    }
  }

  void _toggleTimeDisplayMode() {
    setState(() {
      _showRemainingTime = !_showRemainingTime;
    });
    _showFeedbackMessage(
      _showRemainingTime ? 'Time: Remaining' : 'Time: Total Duration',
      Icons.schedule_rounded,
      EDesign.primaryCyan,
    );
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('player_show_remaining_time', _showRemainingTime);
    }).catchError((_) {});
  }

  String _formatTrackShortName(SubtitleTrack track) {
    if (track.language != null && track.language!.isNotEmpty) {
      return track.language!.toUpperCase();
    }
    if (track.title != null && track.title!.isNotEmpty) {
      return track.title!.length > 8 ? track.title!.substring(0, 8) : track.title!;
    }
    return track.id == 'no' ? 'NONE' : track.id;
  }

  void _togglePlaylist() {
    _showControls();
    if (_playlistController.isUndocked) {
      _playlistController.toggleVisible();
    } else {
      _showDockedPlaylistSheet();
    }
  }

  void _playMediaItem(MediaItem item) {
    try {
      _player.open(Media(item.path));
      setState(() {
        _currentMediaPath = item.path;
        _showResumePrompt = false;
        _savedResumePosition = null;
      });
      _playlistController.setCurrentPlayingPath(item.path);
      _checkResumePosition();
      _showFeedbackMessage(
        'Playing: ${item.name}',
        Icons.play_circle_fill_rounded,
        EDesign.primaryCyan,
      );
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to open track: $e');
    }
  }

  Future<void> _handleImportPlaylist() async {
    try {
      final result = await FilePicker.pickFile(
        dialogTitle: 'Import Playlist',
        type: FileType.custom,
        allowedExtensions: ['m3u8', 'm3u', 'xspf'],
      );
      if (result != null && result.path != null) {
        final count = await _playlistController.importPlaylist(result.path!);
        if (!mounted) return;
        if (count > 0 && _playlistController.items.isNotEmpty) {
          _playMediaItem(_playlistController.items.first);
          _showFeedbackMessage(
            'Imported $count tracks',
            Icons.playlist_play_rounded,
            EDesign.primaryCyan,
          );
        } else {
          _showFeedbackMessage(
            'Playlist empty or no valid tracks found',
            Icons.playlist_remove_rounded,
            EDesign.warning,
          );
        }
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to import playlist: $e');
      if (mounted) {
        _showFeedbackMessage(
          'Failed to import playlist',
          Icons.error_outline_rounded,
          EDesign.danger,
        );
      }
    }
  }

  Future<void> _handleExportPlaylist() async {
    try {
      if (_playlistController.items.isEmpty) {
        _showFeedbackMessage(
          'Playlist is empty',
          Icons.info_outline_rounded,
          EDesign.warning,
        );
        return;
      }
      final serialized = PlaylistSerializer.serializeM3u8(_playlistController.items);
      final bytes = Uint8List.fromList(utf8.encode(serialized));
      final defaultName = 'playlist_${DateTime.now().millisecondsSinceEpoch}.m3u8';
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Export Playlist (.m3u8)',
        fileName: defaultName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['m3u8', 'm3u', 'xspf'],
      );
      if (savedUri != null && mounted) {
        _showFeedbackMessage(
          'Playlist exported successfully',
          Icons.check_circle_rounded,
          EDesign.primaryCyan,
        );
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to export playlist: $e');
      if (mounted) {
        _showFeedbackMessage(
          'Failed to export playlist',
          Icons.error_outline_rounded,
          EDesign.danger,
        );
      }
    }
  }

  void _showDockedPlaylistSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          decoration: BoxDecoration(
            color: EDesign.surface.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_play_rounded, color: EDesign.primaryCyan, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Playlist (Docked)',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('docked_playlist_import_button'),
                        icon: const Icon(Icons.file_open_rounded, size: 18),
                        color: EDesign.primaryCyan,
                        tooltip: 'Import Playlist (.m3u, .m3u8, .xspf)',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleImportPlaylist();
                        },
                      ),
                      IconButton(
                        key: const Key('docked_playlist_export_button'),
                        icon: const Icon(Icons.save_alt_rounded, size: 18),
                        color: Colors.white70,
                        tooltip: 'Export Playlist (.m3u8)',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleExportPlaylist();
                        },
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        key: const Key('docked_playlist_undock_button'),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16, color: EDesign.primaryCyan),
                        label: const Text('Undock', style: TextStyle(color: EDesign.primaryCyan)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _playlistController.setUndocked(true);
                            _playlistController.setVisible(true);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: _playlistController.items.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (ctx, index) {
                      final item = _playlistController.items[index];
                      final isPlaying = item.path == (_currentMediaPath ?? widget.mediaPath);
                      return ListTile(
                        leading: Icon(
                          isPlaying ? Icons.play_circle_fill_rounded : Icons.movie_outlined,
                          color: isPlaying ? EDesign.primaryCyan : Colors.white60,
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            color: isPlaying ? EDesign.primaryCyan : Colors.white,
                            fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _playMediaItem(item);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _player.setRate(speed);
    _showFeedbackMessage('Speed: ${speed}x', Icons.speed);
    _showControls();
  }

  void _openAiStudio() {
    _controlsTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final screenHeight = MediaQuery.of(context).size.height;
        final sheetHeight = isLandscape ? (screenHeight * 0.94) : (screenHeight * 0.78);
        return SafeArea(
          top: isLandscape,
          child: SizedBox(
            height: sheetHeight,
            child: EnhancementStudioSheet(
              aiEngine: _aiEngine,
              mediaPath: widget.mediaPath,
              config: _enhancementConfig,
              onConfigChanged: () {
                setState(() {});
                _applyEnhancements();
              },
            ),
          ),
        );
      },
    ).then((_) {
      _startControlsTimer();
      setState(() {});
      _applyEnhancements();
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  void _onBookmarksChanged() {
    if (mounted) setState(() {});
  }

  void _showBookmarksSheet() {
    BookmarksSheet.show(
      context,
      player: _player,
      mediaId: widget.mediaPath,
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  void _jumpToBookmark(int index) {
    final bookmarks = BookmarkService.instance.getBookmarks(widget.mediaPath);
    if (index >= 0 && index < bookmarks.length) {
      final target = bookmarks[index];
      _player.seek(target.position);
      _showFeedbackMessage(
        'Jump to [${index + 1}]: ${target.label} (${target.formattedTime})',
        Icons.bookmark_added_rounded,
        Colors.amber,
      );
    } else {
      _showFeedbackMessage(
        'No bookmark at slot F${index + 1}',
        Icons.bookmark_border_rounded,
        EDesign.textSecondary,
      );
    }
  }

  void _showFeedbackMessage(String msg, IconData icon, [Color? color]) {
    setState(() {
      _feedbackText = msg;
      _feedbackIcon = icon;
      _feedbackColor = color;
      _showFeedback = true;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showFeedback = false);
    });
  }

  Future<void> _takeSnapshot() async {
    _showFeedbackMessage('Capturing snapshot...', Icons.camera_alt_rounded, EDesign.aiAccent);
    try {
      final result = await VideoSnapshotService.instance.captureFromPlayer(
        _player,
        mediaTitle: widget.mediaPath,
      );
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _lastSnapshotResult = result;
        });
        _snapshotPreviewTimer?.cancel();
        _snapshotPreviewTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _lastSnapshotResult = null);
        });
        _showFeedbackMessage(
          'Saved: ${result.fileName}',
          Icons.check_circle_outline_rounded,
          Colors.greenAccent,
        );
      } else {
        _showFeedbackMessage(
          'Snapshot failed: ${result.errorMessage ?? "Unknown"}',
          Icons.error_outline_rounded,
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackMessage(
          'Snapshot error: $e',
          Icons.error_outline_rounded,
          Colors.redAccent,
        );
      }
    }
  }

  void _showVideoContextMenu(Offset globalPosition) {
    _showControls();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: EDesign.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EDesign.r12),
        side: BorderSide(
          color: EDesign.primary.withValues(alpha: 0.3),
        ),
      ),
      items: [
        PopupMenuItem(
          onTap: _takeSnapshot,
          child: const ListTile(
            leading: Icon(Icons.camera_alt_outlined, color: EDesign.aiAccent),
            title: Text('Take Snapshot (Shift+S)', style: TextStyle(color: Colors.white, fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          onTap: _showBookmarksSheet,
          child: const ListTile(
            leading: Icon(Icons.bookmark_outline_rounded, color: Colors.amber),
            title: Text('Chapters & Bookmarks (Ctrl+B)', style: TextStyle(color: Colors.white, fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          onTap: _showAudioTrackMenu,
          child: const ListTile(
            leading: Icon(Icons.audiotrack_outlined, color: Colors.white70),
            title: Text('Audio Tracks', style: TextStyle(color: Colors.white, fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          onTap: _showSubtitleMenu,
          child: const ListTile(
            leading: Icon(Icons.subtitles_outlined, color: Colors.white70),
            title: Text('Subtitle Tracks', style: TextStyle(color: Colors.white, fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          onTap: _showAspectRatioMenu,
          child: ListTile(
            leading: const Icon(Icons.aspect_ratio_rounded, color: Colors.white70),
            title: Text('Aspect Ratio ($_aspectRatio)', style: const TextStyle(color: Colors.white, fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) _showVideoEffectsSheet();
            });
          },
          child: const ListTile(
            leading: Icon(Icons.tune_rounded, color: Colors.white70),
            title: Text('Video Effects Studio', style: TextStyle(color: Colors.white, fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) _showAudioStudioSheet();
            });
          },
          child: const ListTile(
            leading: Icon(Icons.equalizer, color: Colors.white70),
            title: Text('Audio Equalizer & Visualizer', style: TextStyle(color: Colors.white, fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          onTap: _toggleFullscreen,
          child: ListTile(
            leading: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white70),
            title: Text(_isFullscreen ? 'Exit Fullscreen' : 'Fullscreen (F)', style: const TextStyle(color: Colors.white, fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildSnapshotPreviewCard(SnapshotResult snapshot) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: EDesign.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(EDesign.r12),
          border: Border.all(
            color: EDesign.aiAccent.withValues(alpha: 0.8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt_rounded, color: EDesign.aiAccent, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Snapshot Captured',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _lastSnapshotResult = null);
                  },
                  child: const Icon(Icons.close, color: Colors.white70, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                snapshot.previewBytes!,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              snapshot.fileName,
              style: const TextStyle(
                color: EDesign.textSecondary,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Time: ${snapshot.formattedPosition}',
              style: const TextStyle(
                color: EDesign.aiAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (!_gesturesEnabled || _isLocked) return;
    _showControls();
    final viewportSize = MediaQuery.of(context).size;
    _gestureEngine.handleDoubleTapDown(
      details,
      viewportSize,
      _position,
      _duration,
    );
    setState(() {
      _scale = _gestureEngine.scale;
      _offset = _gestureEngine.panOffset;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!_gesturesEnabled || _isLocked) return;
    final viewportSize = MediaQuery.of(context).size;
    _gestureEngine.handleScaleStart(details, viewportSize);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_gesturesEnabled || _isLocked) return;
    final viewportSize = MediaQuery.of(context).size;
    _gestureEngine.handleScaleUpdate(
      details,
      viewportSize,
      _position,
      _duration,
    );
    setState(() {
      _scale = _gestureEngine.scale;
      _offset = _gestureEngine.panOffset;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!_gesturesEnabled || _isLocked) return;
    _gestureEngine.handleScaleEnd(details);
    setState(() {
      _scale = _gestureEngine.scale;
      _offset = _gestureEngine.panOffset;
    });
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
    final targetMode = DecoderMode.fromString(mode);
    setState(() => _decoderMode = targetMode.label);
    try {
      final result = await _decoderPipelineService.setMode(targetMode);
      if (mounted) {
        setState(() {
          _decoderMode = _decoderPipelineService.currentMode.label;
        });
        if (!result.success && result.fallbackReason != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Decoder fallback: ${result.fallbackReason}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Decoder switch error: $e');
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
            for (final mode in DecoderMode.values)
              ListTile(
                title: Text(mode.label, style: EDesign.body),
                subtitle: Text(
                  mode == DecoderMode.auto
                      ? 'Automatic hardware probe & negotiation'
                      : mode == DecoderMode.hw
                          ? 'Zero-copy direct GPU hardware decoding'
                          : mode == DecoderMode.hwPlus
                              ? 'Hybrid hardware decode with CPU copy-back'
                              : 'Software decoding via FFmpeg CPU pipeline',
                  style: const TextStyle(
                    fontSize: 12,
                    color: EDesign.textMuted,
                  ),
                ),
                trailing: _decoderPipelineService.currentMode == mode
                    ? const Icon(Icons.check, color: EDesign.primary)
                    : null,
                onTap: () {
                  _setDecoderMode(mode.label);
                  Navigator.pop(context);
                },
              ),
          ],
        );
      },
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
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

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (Platform.isAndroid || Platform.isIOS) {
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
    _showFeedbackMessage(
      _isFullscreen ? 'Fullscreen' : 'Windowed',
      _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
    );
  }

  void _cycleAspectRatio() {
    const ratios = ['Fit', 'Crop', '16:9', '4:3', 'Fill', 'Original'];
    final currentIndex = ratios.indexOf(_aspectRatio);
    final nextIndex = (currentIndex + 1) % ratios.length;
    final nextRatio = ratios[nextIndex];
    _setAspectRatio(nextRatio);
    _showFeedbackMessage('Aspect: $nextRatio', Icons.aspect_ratio_rounded);
  }

  Future<void> _stepFrame() async {
    if (_isPlaying) {
      await _player.pause();
    }
    try {
      final dynamic platform = _player.platform;
      await platform.command(['frame-step']);
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to step frame: $e');
    }
    _showFeedbackMessage('Frame Step (+1)', Icons.skip_next_rounded, EDesign.primary);
  }

  Future<void> _cycleCropRatio() async {
    await _cropController.cycleNext(onCropChanged: (preset) {
      _showFeedbackMessage('Crop: ${preset.label}', Icons.crop_rounded, EDesign.primary);
      if (mounted) setState(() {});
    });
  }

  void _cycleABRepeat() {
    _abRepeatController.cycle(
      _position,
      onUpdate: () {
        if (mounted) setState(() {});
      },
      onMessage: (msg) {
        _showFeedbackMessage(msg, Icons.repeat_rounded, EDesign.primary);
      },
    );
  }

  void _cycleAudioTrack() {
    if (_audioTracks.isEmpty) {
      _showFeedbackMessage('No audio tracks', Icons.audiotrack);
      return;
    }
    final currentIndex = _audioTracks.indexOf(_selectedAudioTrack);
    final nextIndex = (currentIndex + 1) % _audioTracks.length;
    final nextTrack = _audioTracks[nextIndex];
    _player.setAudioTrack(nextTrack);
    setState(() => _selectedAudioTrack = nextTrack);
    final label = nextTrack.title ?? nextTrack.language ?? nextTrack.id;
    _showFeedbackMessage('Audio: $label', Icons.audiotrack);
  }

  void _showAudioTrackMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StreamBuilder<Track>(
          stream: _player.stream.track,
          initialData: _player.state.track,
          builder: (context, trackSnapshot) {
            final activeTrack = trackSnapshot.data?.audio ?? _selectedAudioTrack;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: Material(
                key: const Key('audio_tracks_sheet'),
                color: EDesign.surface,
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.5),
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(EDesign.r24),
                  ),
                  side: BorderSide(color: EDesign.border, width: 1.0),
                ),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Top Drag Handle Pill
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 2. Header with Title & Dismiss Icon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.audiotrack, color: EDesign.primary, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Audio Tracks',
                              style: TextStyle(
                                color: EDesign.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: EDesign.textMuted, size: 20),
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: EDesign.border, height: 1),

                  // 3. Content Body: Empty State or Scrollable Track Items
                  Flexible(
                    child: _audioTracks.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.audiotrack_outlined,
                                  size: 48,
                                  color: EDesign.textMuted,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No audio tracks found',
                                  key: Key('audio_tracks_empty'),
                                  style: TextStyle(
                                    color: EDesign.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'This media stream does not contain selectable audio tracks.',
                                  textAlign: TextAlign.center,
                                  style: EDesign.caption,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            itemCount: _audioTracks.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final track = _audioTracks[index];
                              final isSelected = activeTrack.id == track.id ||
                                  _selectedAudioTrack.id == track.id;

                              // Compose Rich Metadata Subtitle
                              final List<String> metaParts = [];
                              if (track.language != null &&
                                  track.language!.isNotEmpty &&
                                  track.language != track.title) {
                                metaParts.add(track.language!.toUpperCase());
                              }
                              if (track.codec != null && track.codec!.isNotEmpty) {
                                metaParts.add(track.codec!.toUpperCase());
                              }
                              if (track.channels != null && track.channels!.isNotEmpty) {
                                metaParts.add(track.channels!);
                              } else if (track.channelscount != null && track.channelscount! > 0) {
                                metaParts.add('${track.channelscount} ch');
                              }
                              if (track.samplerate != null && track.samplerate! > 0) {
                                metaParts.add('${(track.samplerate! / 1000).toStringAsFixed(1)} kHz');
                              }
                              final subtitleText = metaParts.join(' • ');

                              return Material(
                                color: isSelected
                                    ? EDesign.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(EDesign.r12),
                                  side: isSelected
                                      ? BorderSide(
                                          color: EDesign.primary.withValues(alpha: 0.4),
                                          width: 1,
                                        )
                                      : BorderSide.none,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  key: Key('audio_track_item_${track.id}'),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(EDesign.r12),
                                    side: isSelected
                                        ? BorderSide(
                                            color: EDesign.primary.withValues(alpha: 0.4),
                                            width: 1,
                                          )
                                        : BorderSide.none,
                                  ),
                                  leading: Icon(
                                    Icons.audiotrack,
                                    color: isSelected ? EDesign.primary : Colors.white60,
                                    size: 20,
                                  ),
                                  title: Text(
                                    track.title ?? track.language ?? track.id,
                                    style: TextStyle(
                                      color: isSelected ? EDesign.primary : EDesign.textPrimary,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: subtitleText.isNotEmpty
                                      ? Text(
                                          subtitleText,
                                          style: const TextStyle(
                                            color: EDesign.textMuted,
                                            fontSize: 11,
                                          ),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: EDesign.primary,
                                          key: Key('active_track_check'),
                                        )
                                      : null,
                                  onTap: () {
                                    _player.setAudioTrack(track);
                                    setState(() => _selectedAudioTrack = track);
                                    final label = track.title ?? track.language ?? track.id;
                                    _showFeedbackMessage('Audio: $label', Icons.audiotrack);
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
        );
      },
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  void _cycleSubtitleTrack() {
    if (_subtitleTracks.isEmpty) {
      _showFeedbackMessage('No subtitles', Icons.subtitles_off);
      return;
    }
    final allOptions = [SubtitleTrack.no(), ..._subtitleTracks];
    final currentIndex = allOptions.indexOf(_selectedSubtitleTrack);
    final nextIndex = (currentIndex + 1) % allOptions.length;
    final nextTrack = allOptions[nextIndex];
    _player.setSubtitleTrack(nextTrack);
    setState(() => _selectedSubtitleTrack = nextTrack);
    final label = nextTrack == SubtitleTrack.no()
        ? 'Subtitles Off'
        : (nextTrack.title ?? nextTrack.language ?? nextTrack.id);
    _showFeedbackMessage('Subtitle: $label', Icons.subtitles);
  }

  void _nudgeSubtitleDelay(int offsetMs) {
    _subtitleConfig.delay += (offsetMs / 1000.0);
    try {
      final platform = _player.platform as dynamic;
      platform.setProperty('sub-delay', _subtitleConfig.delay.toStringAsFixed(2));
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to set sub-delay: $e');
    }
    final sign = _subtitleConfig.delay >= 0 ? '+' : '';
    final ms = (_subtitleConfig.delay * 1000).round();
    _showFeedbackMessage('Sub Delay: $sign${ms}ms', Icons.subtitles);
  }

  void _nudgeAudioDelay(int offsetMs) {
    _audioDelayMs = (_audioDelayMs + offsetMs).clamp(-10000.0, 10000.0);
    _audioConfig.audioDelay = _audioDelayMs;
    try {
      final platform = _player.platform as dynamic;
      platform.setProperty('audio-delay', (_audioDelayMs / 1000.0).toStringAsFixed(3));
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to set audio-delay: $e');
    }
    final sign = _audioDelayMs >= 0 ? '+' : '';
    _showFeedbackMessage('Audio Delay: $sign${_audioDelayMs.round()}ms', Icons.audiotrack);
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
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
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
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
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
              leading: const Icon(Icons.closed_caption, color: EDesign.primaryCyan),
              title: const Text('Teletext & Closed-Captions (CC)...', style: EDesign.body),
              subtitle: const Text('EIA-608 / CEA-708 & VBI Teletext (zvbi.c)', style: EDesign.caption),
              onTap: () {
                Navigator.pop(context);
                TeletextClosedCaptionsSheet.show(
                  context,
                  controller: _teletextCcController,
                ).then((_) {
                  if (mounted) _keyboardFocusNode.requestFocus();
                });
              },
            ),
            ListTile(
              leading: Icon(
                Icons.subtitles_rounded,
                color: _dualSubtitleController.isDualActive ? const Color(0xFFE741FF) : EDesign.primaryCyan,
              ),
              title: Row(
                children: [
                  const Text('Dual Subtitles Studio...', style: EDesign.body),
                  const SizedBox(width: 8),
                  if (_dualSubtitleController.isDualActive)
                    EDesign.buildBadge('ACTIVE', color: const Color(0xFFE741FF)),
                ],
              ),
              subtitle: Text(
                _dualSubtitleController.isDualActive
                    ? 'Bottom: ${_formatTrackShortName(_dualSubtitleController.primaryTrack)} · Top: ${_formatTrackShortName(_dualSubtitleController.secondaryTrack)}'
                    : 'Simultaneous top & bottom tracks (VLC parity)',
                style: EDesign.caption,
              ),
              onTap: () {
                Navigator.pop(context);
                DualSubtitleSheet.show(
                  context,
                  controller: _dualSubtitleController,
                  availableTracks: _subtitleTracks,
                ).then((_) {
                  if (mounted) _keyboardFocusNode.requestFocus();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune, color: EDesign.textPrimary),
              title: const Text('Styles & Delay...', style: EDesign.body),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => SubtitleSettingsSheet(
                    player: _player,
                    config: _subtitleConfig,
                  ),
                ).then((_) {
                  if (mounted) _keyboardFocusNode.requestFocus();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined, color: EDesign.primary),
              title: const Text('Search Online Subtitles (VLSub)...', style: EDesign.body),
              onTap: () {
                Navigator.pop(context);
                final file = widget.mediaPath.startsWith('http') || widget.mediaPath.startsWith('smb')
                    ? null
                    : File(widget.mediaPath);
                final title = p.basenameWithoutExtension(widget.mediaPath);
                OnlineSubtitlesSheet.show(
                  context,
                  videoFile: file,
                  videoTitle: title,
                  onSubtitleLoaded: (downloadedFile, subtitle) {
                    _player.setSubtitleTrack(
                      SubtitleTrack.uri(downloadedFile.uri.toString()),
                    );
                    _showFeedbackMessage(
                      'Subtitle loaded: ${subtitle.languageName.isNotEmpty ? subtitle.languageName : subtitle.language}',
                      Icons.subtitles,
                    );
                  },
                ).then((_) {
                  if (mounted) _keyboardFocusNode.requestFocus();
                });
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
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
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
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
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
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
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
            zoomController: _interactiveZoomController,
            puzzleWallController: _puzzleWallController,
            onConfigChanged: () {
              _puzzleWallController.syncWithConfig(_videoEffectsConfig);
              setState(() {});
            },
          ),
        );
      },
    ).then((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  Future<void> _openDlnaBrowserSheet() async {
    _controlsTimer?.cancel();
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => DlnaServerBrowserSheet(
          dlnaService: _dlnaService,
          onPlayMediaItem: (item) {
            if (item.streamUrl.isNotEmpty) {
              final mediaItem = MediaItem(
                path: item.streamUrl,
                name: item.title,
                parentFolder: 'DLNA',
                durationMs: item.duration?.inMilliseconds ?? 0,
                lastPlayed: DateTime.now(),
              );
              _playMediaItem(mediaItem);
            }
          },
          onEnqueueMediaItem: (item) {
            if (item.streamUrl.isNotEmpty) {
              _playlistController.addTrack(
                MediaItem(
                  path: item.streamUrl,
                  name: item.title,
                  parentFolder: 'DLNA',
                  durationMs: item.duration?.inMilliseconds ?? 0,
                  lastPlayed: DateTime.now(),
                ),
              );
            }
          },
        ),
      );
    } finally {
      if (mounted) {
        _startControlsTimer();
      }
    }
  }

  Future<void> _initOnlineStreamService() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _onlineStreamService.init(prefs);
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to init OnlineStreamService: $e');
    }
  }

  Future<void> _openOnlineStreamSheet() async {
    _controlsTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      await OnlineStreamSheet.show(
        context,
        service: _onlineStreamService,
        prefs: prefs,
        onPlayStream: (streamUrl, title) {
          final mediaItem = MediaItem(
            path: streamUrl,
            name: title,
            parentFolder: 'Online Stream',
            lastPlayed: DateTime.now(),
          );
          _playMediaItem(mediaItem);
        },
        onEnqueueStream: (streamUrl, title) {
          _playlistController.addTrack(
            MediaItem(
              path: streamUrl,
              name: title,
              parentFolder: 'Online Stream',
              lastPlayed: DateTime.now(),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        _startControlsTimer();
      }
    }
  }

  Future<void> _openCastSheet() async {
    _controlsTimer?.cancel();
    try {
      await CastSheet.show(
        context,
        player: _player,
        mediaTitle: p.basename(widget.mediaPath),
      );
    } finally {
      if (mounted) {
        _startControlsTimer();
        _keyboardFocusNode.requestFocus();
      }
    }
  }

  void _showAudioStudioSheet() {
    _audioConfig.audioDelay = _audioDelayMs;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AudioStudioSheet(
        player: _player,
        config: _audioConfig,
      ),
    ).then((_) {
      _audioDelayMs = _audioConfig.audioDelay;
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  void _showMorePlayerOptionsSheet() {
    _controlsTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.elevatedBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune_rounded, color: EDesign.primary, size: 20),
                            SizedBox(width: 8),
                            Text('Playback & Controls', style: EDesign.h3),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: EDesign.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Playback Speed', style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        InkWell(
                          onTap: () {
                            _cyclePlaybackSpeed();
                            setSheetState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              'Cycle Speed (${_playbackSpeed.toStringAsFixed(2)}x)',
                              style: const TextStyle(color: EDesign.primary, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                          final isSelected = (_playbackSpeed - speed).abs() < 0.05;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${speed}x'),
                              selected: isSelected,
                              selectedColor: const Color(0xFFFF5722),
                              backgroundColor: EDesign.surface,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : EDesign.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                Navigator.pop(ctx);
                                _setSpeed(speed);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: EDesign.border, height: 1),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.3,
                      children: [
                        _buildQuickOptionTile(
                          key: const Key('hud_audio_tracks_button'),
                          icon: Icons.audiotrack_outlined,
                          title: 'Audio Tracks',
                          subtitle: _selectedAudioTrack.title ?? 'Default',
                          onTap: () {
                            Navigator.pop(ctx);
                            _showAudioTrackMenu();
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_audio_equalizer_button'),
                          icon: Icons.equalizer,
                          title: 'Equalizer',
                          subtitle: '10-Band EQ & FX',
                          onTap: () {
                            Navigator.pop(ctx);
                            _showAudioStudioSheet();
                          },
                        ),
                        _buildQuickOptionTile(
                          icon: Icons.auto_awesome,
                          title: 'AI Studio',
                          subtitle: _enhancementConfig.masterToggle ? 'Active' : 'Off',
                          accentColor: EDesign.aiAccent,
                          onTap: () {
                            Navigator.pop(ctx);
                            _openAiStudio();
                          },
                        ),
                        _buildQuickOptionTile(
                          icon: Icons.tune,
                          title: 'Video Effects',
                          subtitle: 'Colors & Contrast',
                          onTap: () {
                            Navigator.pop(ctx);
                            _showVideoEffectsSheet();
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_ab_repeat_button'),
                          icon: Icons.repeat_rounded,
                          title: 'A-B Loop',
                          subtitle: _abRepeatController.state.name.toUpperCase(),
                          onTap: () {
                            Navigator.pop(ctx);
                            _cycleABRepeat();
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_frame_step_button'),
                          icon: Icons.skip_next_rounded,
                          title: 'Frame Step',
                          subtitle: 'Step Forward (e)',
                          onTap: () {
                            Navigator.pop(ctx);
                            _stepFrame();
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_interactive_zoom_button'),
                          icon: Icons.zoom_in_rounded,
                          title: 'Interactive Zoom',
                          subtitle: _interactiveZoomController.state.isActive
                              ? '${_interactiveZoomController.state.zoomFactor.toStringAsFixed(1)}x Active'
                              : 'VLC Magnifier HUD',
                          accentColor: _interactiveZoomController.state.isActive ? EDesign.primaryCyan : EDesign.primary,
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _showZoomViewfinder = !_showZoomViewfinder;
                              if (_showZoomViewfinder && !_interactiveZoomController.state.isActive) {
                                _interactiveZoomController.setZoom(2.0);
                              }
                            });
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_bookmarks_button'),
                          icon: Icons.bookmark_outline_rounded,
                          title: 'Bookmarks',
                          subtitle: 'Chapters & Tags',
                          onTap: () {
                            Navigator.pop(ctx);
                            _showBookmarksSheet();
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_snapshot_button'),
                          icon: Icons.camera_alt_outlined,
                          title: 'Snapshot',
                          subtitle: 'PNG Frame (Shift+S)',
                          onTap: () {
                            Navigator.pop(ctx);
                            _takeSnapshot();
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_stream_recorder_button'),
                          icon: Icons.fiber_manual_record,
                          title: 'Record Stream',
                          subtitle: _streamRecorderController.isRecording
                              ? 'Recording (${_streamRecorderController.activeFormattedDuration})'
                              : 'Dump Stream (Shift+R)',
                          accentColor: _streamRecorderController.isRecording ? Colors.redAccent : EDesign.primaryCyan,
                          onTap: () {
                            Navigator.pop(ctx);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => StreamRecorderSheet(
                                controller: _streamRecorderController,
                                mediaTitle: p.basename(widget.mediaPath),
                                sourceUrl: widget.mediaPath,
                              ),
                            );
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_web_remote_button'),
                          icon: Icons.phonelink_rounded,
                          title: 'Web Remote Control',
                          subtitle: _webRemoteService.isRunning
                              ? 'Active (${_webRemoteService.port})'
                              : 'Wi-Fi QR Remote',
                          accentColor: _webRemoteService.isRunning ? EDesign.success : EDesign.primaryCyan,
                          onTap: () {
                            Navigator.pop(ctx);
                            WebRemoteSheet.show(context, _webRemoteService);
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_watermark_studio_button'),
                          icon: Icons.branding_watermark_rounded,
                          title: 'Watermark & Logo',
                          subtitle: _videoEffectsConfig.logoEnabled
                              ? 'Active (${_videoEffectsConfig.logoPosition.label})'
                              : 'VLC Logo Overlay',
                          accentColor: _videoEffectsConfig.logoEnabled ? EDesign.primaryCyan : EDesign.textSecondary,
                          onTap: () {
                            Navigator.pop(ctx);
                            WatermarkStudioSheet.show(
                              context,
                              config: _videoEffectsConfig,
                              onConfigChanged: (updated) {
                                setState(() {
                                  _videoEffectsConfig = updated;
                                });
                                _videoEffectsService.saveToPreferences(updated);
                              },
                            );
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_anaglyph_studio_button'),
                          icon: Icons.remove_red_eye_rounded,
                          title: '3D Anaglyph',
                          subtitle: _videoEffectsConfig.anaglyphEnabled
                              ? 'Active (${_videoEffectsConfig.anaglyphMatrix.label})'
                              : 'VLC 3D Filter',
                          accentColor: _videoEffectsConfig.anaglyphEnabled ? Colors.redAccent : EDesign.textSecondary,
                          onTap: () {
                            Navigator.pop(ctx);
                            AnaglyphStudioSheet.show(
                              context,
                              config: _videoEffectsConfig,
                              onConfigChanged: (updated) {
                                setState(() {
                                  _videoEffectsConfig = updated;
                                });
                                _videoEffectsService.apply(_player, updated, immediateVf: true);
                                _videoEffectsService.saveToPreferences(updated);
                              },
                            );
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_dual_audio_button'),
                          icon: Icons.speaker_group_rounded,
                          title: 'Dual Audio & Dubbing',
                          subtitle: _dualAudioService.config.enabled
                              ? 'Active (${_dualAudioService.config.routingMode.label})'
                              : 'Multi-Device Sync',
                          accentColor: _dualAudioService.config.enabled ? EDesign.primaryCyan : EDesign.textSecondary,
                          onTap: () {
                            Navigator.pop(ctx);
                            DualAudioSheet.show(
                              context,
                              service: _dualAudioService,
                              player: _player,
                            );
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_media_converter_button'),
                          icon: Icons.transform_rounded,
                          title: 'Convert & Extract',
                          subtitle: _mediaConverterService.isConverting
                              ? 'Converting (${_mediaConverterService.activeTask?.progressPercent}%)'
                              : 'VLC Transcoder',
                          accentColor: _mediaConverterService.isConverting ? Colors.amberAccent : EDesign.primaryCyan,
                          onTap: () {
                            Navigator.pop(ctx);
                            MediaConverterSheet.show(
                              context,
                              service: _mediaConverterService,
                              initialSourcePath: _currentMediaPath ?? widget.mediaPath,
                              currentDuration: _player.state.duration,
                            );
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_dlna_browser_button'),
                          icon: Icons.settings_input_antenna_rounded,
                          title: 'DLNA / UPnP',
                          subtitle: _dlnaService.isScanning
                              ? 'Scanning...'
                              : 'LAN Media Servers',
                          accentColor: _dlnaService.servers.isNotEmpty ? EDesign.primaryCyan : EDesign.textSecondary,
                          onTap: () {
                            Navigator.pop(ctx);
                            _openDlnaBrowserSheet();
                          },
                        ),
                        _buildQuickOptionTile(
                          key: const Key('hud_online_stream_button'),
                          icon: Icons.travel_explore_rounded,
                          title: 'Network Stream',
                          subtitle: 'YouTube & URL (Ctrl+N)',
                          accentColor: EDesign.primaryCyan,
                          onTap: () {
                            Navigator.pop(ctx);
                            _openOnlineStreamSheet();
                          },
                        ),
                        _buildQuickOptionTile(
                          icon: Icons.picture_in_picture_alt_rounded,
                          title: 'PiP Window',
                          subtitle: 'Background Float',
                          onTap: () {
                            Navigator.pop(ctx);
                            _triggerPip();
                          },
                        ),
                        _buildQuickOptionTile(
                          icon: Icons.cast_rounded,
                          title: 'Cast Media',
                          subtitle: 'Wireless Display',
                          onTap: () {
                            Navigator.pop(ctx);
                            _openCastSheet();
                          },
                        ),
                        _buildQuickOptionTile(
                          icon: Icons.memory_rounded,
                          title: 'Decoder',
                          subtitle: _decoderMode,
                          onTap: () {
                            Navigator.pop(ctx);
                            _showDecoderMenu();
                          },
                        ),
                        _buildQuickOptionTile(
                          icon: Icons.speed_rounded,
                          title: 'Custom Speed',
                          subtitle: 'Precision Slider',
                          onTap: () {
                            Navigator.pop(ctx);
                            _showSpeedMenu();
                          },
                        ),
                        _buildQuickOptionTile(
                          icon: Icons.info_outline_rounded,
                          title: 'Technical Info',
                          subtitle: 'Codec & Stream Specs',
                          onTap: () {
                            Navigator.pop(ctx);
                            MediaInfoSheet.show(context, mediaPath: widget.mediaPath);
                          },
                        ),
                        _buildQuickOptionTile(
                          icon: Icons.settings_outlined,
                          title: 'Full Settings',
                          subtitle: 'Drawer Config',
                          onTap: () {
                            Navigator.pop(ctx);
                            Scaffold.of(context).openEndDrawer();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _startControlsTimer();
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  Widget _buildQuickOptionTile({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    Color accentColor = EDesign.primary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: EDesign.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EDesign.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: EDesign.textMuted,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

    // Video Overlay Layer (VLC SPU logo.c & marq.c parity)
    videoWidget = Stack(
      fit: StackFit.passthrough,
      children: [
        videoWidget,
        VideoOverlayWidget(
          config: _videoEffectsConfig,
          mediaTitle: p.basename(widget.mediaPath),
          position: _position,
          duration: _duration,
        ),
      ],
    );

    // Interactive Puzzle Game & Video Wall (VLC puzzle.c & wall.c parity)
    if (_videoEffectsConfig.puzzleEnabled || _videoEffectsConfig.wallEnabled) {
      videoWidget = PuzzleWallSurfaceWidget(
        config: _videoEffectsConfig,
        controller: _puzzleWallController,
        child: videoWidget,
      );
    }

    if (_pipService.isInPip) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: videoWidget,
        ),
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
            SwitchListTile(
              title: const Text('Minimize to System Tray', style: EDesign.body),
              subtitle: const Text('Keeps audio playing in background when minimized', style: EDesign.caption),
              value: DesktopTrayAudioService.instance.minimizeToTrayEnabled,
              activeThumbColor: EDesign.primary,
              onChanged: (v) {
                setState(() {
                  DesktopTrayAudioService.instance.setMinimizeToTray(v);
                });
              },
            ),
          ],
        ),
      ),
      onEndDrawerChanged: (isOpen) {
        if (!isOpen && mounted) {
          _keyboardFocusNode.requestFocus();
        }
      },
      body: DesktopKeyboardHandler(
        player: _player,
        focusNode: _keyboardFocusNode,
        onToggleFullscreen: _toggleFullscreen,
        onCycleAspectRatio: _cycleAspectRatio,
        onCycleAudioTrack: _cycleAudioTrack,
        onCycleSubtitleTrack: _cycleSubtitleTrack,
        onNudgeAudioDelay: _nudgeAudioDelay,
        onNudgeSubtitleDelay: _nudgeSubtitleDelay,
        onStepFrame: _stepFrame,
        onCycleCrop: _cycleCropRatio,
        onOpenBookmarks: _showBookmarksSheet,
        onJumpToBookmark: _jumpToBookmark,
        onTakeSnapshot: _takeSnapshot,
        onToggleZoom: () {
          setState(() {
            _showZoomViewfinder = !_showZoomViewfinder;
            if (_showZoomViewfinder && !_interactiveZoomController.state.isActive) {
              _interactiveZoomController.setZoom(2.0);
            }
          });
          _showFeedbackMessage(
            _interactiveZoomController.state.isActive
                ? 'Interactive Zoom: ${_interactiveZoomController.state.zoomFactor.toStringAsFixed(1)}x'
                : 'Interactive Zoom: Normal',
            Icons.zoom_in,
          );
        },
        onToggleTeletext: () {
          _teletextCcController.toggleTeletext();
          _showFeedbackMessage(
            _teletextCcController.teletextConfig.enabled
                ? 'Teletext: Page ${_teletextCcController.teletextConfig.page}'
                : 'Teletext: Off',
            Icons.tv,
          );
        },
        onCycleClosedCaptions: () {
          _teletextCcController.cycleClosedCaptionChannel();
          _showFeedbackMessage(
            'Closed Captions: ${_teletextCcController.captionConfig.channel.shortCode}',
            Icons.closed_caption,
          );
        },
        onToggleRecord: () async {
          await _streamRecorderController.toggleRecording(
            mediaTitle: p.basename(widget.mediaPath),
            sourceUrl: widget.mediaPath,
          );
          _showFeedbackMessage(
            _streamRecorderController.isRecording
                ? 'Recording Started (Shift+R)'
                : 'Recording Stopped (Shift+R)',
            Icons.fiber_manual_record,
            _streamRecorderController.isRecording ? Colors.redAccent : EDesign.primaryCyan,
          );
        },
        onCycleDeinterlace: () {
          setState(() {
            _videoEffectsConfig.deinterlaceMode = _videoEffectsConfig.deinterlaceMode.next();
          });
          _videoEffectsService.apply(_player, _videoEffectsConfig, immediateVf: true);
          _showFeedbackMessage(
            'Deinterlace: ${_videoEffectsConfig.deinterlaceMode.label}',
            Icons.horizontal_distribute,
          );
        },
        onTogglePlaylist: _togglePlaylist,
        onOpenNetworkStream: _openOnlineStreamSheet,
        onShowOsd: (msg, icon, [color]) => _showFeedbackMessage(msg, icon, color),
        onUserActivity: _showControls,
        onBeforeSeek: () {
          _aiEngine.invalidateQueue();
          _showControls();
        },
        child: MouseRegion(
          cursor: _controlsVisible ? SystemMouseCursors.basic : SystemMouseCursors.none,
          onHover: (_) => _showControls(),
          onEnter: (_) => _showControls(),
          child: GestureDetector(
            onTap: () {
              _toggleControls();
              _keyboardFocusNode.requestFocus();
            },
            onSecondaryTapUp: (details) {
              _showVideoContextMenu(details.globalPosition);
            },
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

              // Top Bar Controls (Cinematic Minimalist Overlay - Exact Reference Match)
              Positioned(
                top: 20,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Back button & Screen Orientation Lock
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                              tooltip: 'Back',
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              key: const Key('hud_orientation_lock_button'),
                              icon: const EVectorIcon(
                                name: 'screen_orientation_lock',
                                size: 22,
                                color: Colors.white,
                              ),
                              tooltip: 'Orientation Lock: ${VideoRotationService.getModeLabel(_orientationMode)}',
                              onPressed: () {
                                _showControls();
                                _cycleOrientationMode();
                              },
                            ),
                          ],
                        ),

                        // Center: Clean Centered Title with subtle shadow
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              _currentMediaPath != null && _currentMediaPath!.isNotEmpty
                                  ? p.basename(_currentMediaPath!)
                                  : (widget.mediaPath.isNotEmpty
                                      ? p.basename(widget.mediaPath)
                                      : 'The Last Horizon.mkv'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                letterSpacing: 0.15,
                                shadows: [
                                  Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Right: Active Cast Pill, Web Remote & Playlist Toggle Button (Ctrl+L)
                        SizedBox(
                          width: 140,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Consumer<CastService>(
                                  builder: (context, castService, _) {
                                    final isCasting = castService.connectedDevice != null;
                                    if (!isCasting) return const SizedBox.shrink();
                                    return IconButton(
                                      icon: const EVectorIcon(name: 'cast', size: 19, color: EDesign.primaryCyan),
                                      tooltip: 'Casting to ${castService.connectedDevice!.name}',
                                      onPressed: _openCastSheet,
                                    );
                                  },
                                ),
                                IconButton(
                                  key: const Key('hud_web_remote_top_button'),
                                  icon: Icon(
                                    Icons.phonelink_rounded,
                                    color: _webRemoteService.isRunning ? EDesign.success : Colors.white,
                                    size: 20,
                                  ),
                                  tooltip: 'Web Remote (${_webRemoteService.isRunning ? "Active" : "Off"})',
                                  onPressed: () => WebRemoteSheet.show(context, _webRemoteService),
                                ),
                                IconButton(
                                  key: const Key('hud_playlist_button'),
                                  icon: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 22),
                                  tooltip: 'Playlist (Ctrl+L)',
                                  onPressed: _togglePlaylist,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

              // Active Wireless Casting HUD Banner (VLC sout Redirection Parity)
              Consumer<CastService>(
                builder: (context, castService, child) {
                  final connected = castService.connectedDevice;
                  if (connected == null) return const SizedBox.shrink();

                  return Positioned(
                    top: 86,
                    left: 20,
                    right: 20,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1.0 : 0.45,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: EDesign.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(EDesign.r14),
                          border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.8)),
                          boxShadow: [
                            BoxShadow(
                              color: EDesign.primaryCyan.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: EDesign.primaryCyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(EDesign.r8),
                              ),
                              child: const EVectorIcon(name: 'cast', color: EDesign.primaryCyan, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Streaming to ${connected.name}',
                                          style: const TextStyle(
                                            color: EDesign.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: EDesign.success.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'ACTIVE SINK',
                                          style: TextStyle(
                                            color: EDesign.success,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${connected.protocol.label} · ${castService.activeSession?.transcodeProfile.label ?? "Direct Stream"} · ${castService.activeSession?.pingMs ?? 14}ms sync',
                                    style: EDesign.caption.copyWith(color: EDesign.textSecondary, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: EDesign.danger,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                castService.disconnect();
                              },
                              icon: const Icon(Icons.link_off_rounded, size: 16),
                              label: const Text('Disconnect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Bottom Controls (Cinematic Minimalist Overlay - Exact Reference Match)
            if (!_isLocked)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Scrubber and Timestamps (Exact Reference Match)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatPosition(_position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                  shadows: [
                                    Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                key: const Key('timeline_duration_toggle'),
                                onTap: _toggleTimeDisplayMode,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                  child: Text(
                                    _showRemainingTime
                                        ? _formatRemainingDuration(_position, _duration)
                                        : _formatPosition(_duration),
                                    style: TextStyle(
                                      color: _showRemainingTime ? Colors.white : EDesign.primaryCyan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                      shadows: const [
                                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Sleek Slider with Hotstar Orange Accent
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFFF5722),
                            inactiveTrackColor: Colors.white24,
                            thumbColor: const Color(0xFFFF5722),
                            overlayColor: const Color(0xFFFF5722).withValues(alpha: 0.25),
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
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
                        const SizedBox(height: 2),
                        // Controls Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left: Subtitles & Screen Rotate / Aspect Loop
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: const Key('hud_subtitles_button'),
                                    icon: EVectorIcon(
                                      name: 'subtitles',
                                      size: 22,
                                      color: _dualSubtitleController.isDualActive
                                          ? const Color(0xFFE741FF)
                                          : Colors.white,
                                    ),
                                    tooltip: _dualSubtitleController.isDualActive
                                        ? 'Dual Subtitles Active'
                                        : 'Subtitles',
                                    onPressed: _showSubtitleMenu,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    key: const Key('hud_crop_button'),
                                    icon: const EVectorIcon(name: 'cycle_rotate', size: 21, color: Colors.white),
                                    tooltip: 'Cycle Aspect & Rotation',
                                    onPressed: () {
                                      _showControls();
                                      _cycleOrientationMode();
                                    },
                                  ),
                                ],
                              ),
                              // Center: Replay 10, Ring Play/Pause, Forward 10
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 28),
                                    tooltip: '-10s',
                                    onPressed: () {
                                      final newPos = _position - const Duration(seconds: 10);
                                      _aiEngine.invalidateQueue();
                                      _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
                                      _showControls();
                                    },
                                  ),
                                  const SizedBox(width: 14),
                                  GestureDetector(
                                    key: const Key('hud_play_pause_button'),
                                    onTap: () {
                                      _showControls();
                                      _isPlaying ? _player.pause() : _player.play();
                                    },
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2.2),
                                        color: Colors.black.withValues(alpha: 0.25),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  IconButton(
                                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 28),
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
                              // Right: Fit / Fullscreen & More options
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.fit_screen_rounded, color: Colors.white, size: 22),
                                    tooltip: 'Aspect Ratio & Scaling ($_aspectRatio)',
                                    onPressed: _showAspectRatioMenu,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 26),
                                    tooltip: 'More Options',
                                    onPressed: _showMorePlayerOptionsSheet,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    'Decoder: ${_decoderPipelineService.currentMode.label} (${_latestDecoderTelemetry?.activeDecoder ?? _decoderPipelineService.activeDecoder})\n'
                    'Codec: ${_latestDecoderTelemetry?.codec ?? _decoderPipelineService.videoCodec}\n'
                    'Dropped Frames: ${_latestDecoderTelemetry?.droppedFrames ?? _decoderPipelineService.droppedFrames}\n'
                    'FPS: ${(_latestDecoderTelemetry?.fps ?? _decoderPipelineService.fps).toStringAsFixed(1)}\n'
                    'Aspect: $_aspectRatio (Zoom: ${_scale.toStringAsFixed(1)}x)\n'
                    'Resolution: ${_player.state.width ?? _latestDecoderTelemetry?.width ?? 0}x${_player.state.height ?? _latestDecoderTelemetry?.height ?? 0}\n'
                    'Video Track: ${_player.state.track.video.title ?? _player.state.track.video.id}\n'
                    'Audio Track: ${_player.state.track.audio.title ?? _player.state.track.audio.id}\n'
                    'Audio Bitrate: ${_player.state.audioBitrate ?? "Unknown"}'
                    '${_latestDecoderTelemetry?.fallbackReason != null ? "\nFallback: ${_latestDecoderTelemetry!.fallbackReason}" : ""}',
                    style: const TextStyle(
                      color: EDesign.primary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),

            // Left Wing Ripple Indicator (-10s Jump)
            if (_leftWingRipple)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.33,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _leftWingRipple ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            EDesign.primary.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(100),
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fast_rewind, color: Colors.white, size: 48),
                            SizedBox(height: 8),
                            Text(
                              '-10s',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Right Wing Ripple Indicator (+10s Jump)
            if (_rightWingRipple)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.33,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _rightWingRipple ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            EDesign.primary.withValues(alpha: 0.35),
                          ],
                        ),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(100),
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fast_forward, color: Colors.white, size: 48),
                            SizedBox(height: 8),
                            Text(
                              '+10s',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Cinematic Gesture Feedback Overlay Card
            if (_showFeedbackOverlay && _activeFeedbackEvent != null)
              Positioned(
                top: 90,
                left: 0,
                right: 0,
                child: Center(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showFeedbackOverlay ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: EDesign.surface.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(EDesign.r18),
                          border: Border.all(
                            color: (_activeFeedbackEvent?.type == GestureFeedbackType.volume)
                                ? VolumeSafetyColors.resolve(_activeFeedbackEvent!.value).withValues(alpha: 0.8)
                                : EDesign.primary.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_activeFeedbackEvent?.type == GestureFeedbackType.volume)
                                  ? VolumeSafetyColors.resolveGlow(_activeFeedbackEvent!.value)
                                  : Colors.black.withValues(alpha: 0.55),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildGestureFeedbackContent(_activeFeedbackEvent!),
                      ),
                    ),
                  ),
                ),
              ),

            // Glassmorphic OSD Feedback Pill Overlay (Shortcuts & Player Feedback)
            if (_showFeedback)
              Positioned(
                top: 90,
                left: 0,
                right: 0,
                child: Center(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showFeedback ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: EDesign.surface.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(EDesign.r18),
                          border: Border.all(
                            color: (_feedbackColor ?? EDesign.primary).withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_feedbackColor != null)
                                  ? _feedbackColor!.withValues(alpha: 0.4)
                                  : Colors.black.withValues(alpha: 0.55),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_feedbackIcon != null) ...[
                              Icon(_feedbackIcon, color: _feedbackColor ?? EDesign.primary, size: 22),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _feedbackText,
                              style: TextStyle(
                                color: _feedbackColor ?? Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Video Snapshot Floating Preview Card (VLC Frame Capture Parity)
            if (_lastSnapshotResult != null && _lastSnapshotResult!.previewBytes != null)
              Positioned(
                key: const Key('snapshot_preview_toast'),
                bottom: _controlsVisible ? 110 : 30,
                right: 24,
                child: _buildSnapshotPreviewCard(_lastSnapshotResult!),
              ),

            // VLC Interactive Zoom & Magnifier Viewfinder HUD (magnify.c parity)
            if (_showZoomViewfinder || _interactiveZoomController.state.isActive)
              Positioned(
                key: const Key('interactive_zoom_viewfinder'),
                top: 80,
                left: 20,
                child: InteractiveZoomViewfinder(
                  controller: _interactiveZoomController,
                  onClose: () {
                    setState(() {
                      _showZoomViewfinder = false;
                      _interactiveZoomController.reset();
                    });
                  },
                ),
              ),

            // VLC Teletext (zvbi.c) & Closed Captions (cc.c) OSD Overlay
            TeletextOsdOverlayWidget(
              controller: _teletextCcController,
              onOpenSettings: () {
                TeletextClosedCaptionsSheet.show(
                  context,
                  controller: _teletextCcController,
                );
              },
            ),

            // VLC Network Stream Recorder (record.c) Live HUD Badge
            StreamRecorderBadgeWidget(
              controller: _streamRecorderController,
            ),

            // Dual Subtitle Active Status Pill
            if (_dualSubtitleController.isDualActive)
              Positioned(
                key: const Key('dual_subtitle_active_badge'),
                top: _controlsVisible ? 75 : 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16162A).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(EDesign.r8),
                    border: Border.all(color: const Color(0xFFE741FF).withValues(alpha: 0.7)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE741FF).withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.subtitles_rounded, size: 14, color: Color(0xFFE741FF)),
                      const SizedBox(width: 6),
                      Text(
                        'DUAL SUB: ${_formatTrackShortName(_dualSubtitleController.primaryTrack)} ↓ · ${_formatTrackShortName(_dualSubtitleController.secondaryTrack)} ↑',
                        style: const TextStyle(
                          color: Color(0xFFE741FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // VLC Resume Playback Prompt Banner (--qt-continue=1 parity)
            if (_showResumePrompt && _savedResumePosition != null)
              Positioned(
                key: const Key('resume_playback_banner_overlay'),
                top: _controlsVisible ? 85 : 25,
                left: 0,
                right: 0,
                child: Center(
                  child: ResumePlaybackBannerWidget(
                    resumePosition: _savedResumePosition!,
                    onResume: _handleResumePlayback,
                    onRestart: _handleRestartPlayback,
                    onDismiss: () {
                      if (mounted) setState(() => _showResumePrompt = false);
                    },
                  ),
                ),
              ),

            // VLC Undocked / Detached Floating Multi-Window Playlist Panel (--pl-dock-status=0 parity)
            if (_playlistController.isVisible && _playlistController.isUndocked)
              Positioned(
                key: const Key('undocked_playlist_panel_overlay'),
                left: _playlistController.position.dx,
                top: _playlistController.position.dy,
                child: UndockedPlaylistPanelWidget(
                  controller: _playlistController,
                  onSelectTrack: _playMediaItem,
                  onClose: () {
                    _playlistController.setVisible(false);
                  },
                  onDockToggle: () {
                    _playlistController.setUndocked(false);
                    _showDockedPlaylistSheet();
                  },
                  onImportPlaylist: _handleImportPlaylist,
                  onExportPlaylist: _handleExportPlaylist,
                ),
              ),
          ],
        ),
      ),
    ),
    ),
  );
  }

  Widget _buildGestureFeedbackContent(GestureFeedbackEvent event) {
    switch (event.type) {
      case GestureFeedbackType.scrub:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, color: EDesign.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              _formatDuration(event.seekTarget ?? _position),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            if (event.deltaFormatted.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: EDesign.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EDesign.primary, width: 0.8),
                ),
                child: Text(
                  event.deltaFormatted,
                  style: const TextStyle(
                    color: EDesign.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      case GestureFeedbackType.brightness:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.brightness_6, color: EDesign.primaryCyan, size: 22),
            const SizedBox(width: 8),
            Text(
              'Brightness: ${event.label}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: event.value.clamp(0.0, 1.0),
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(EDesign.primaryCyan),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        );
      case GestureFeedbackType.volume:
        final safetyColor = VolumeSafetyColors.resolve(event.value);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              event.value == 0
                  ? Icons.volume_off_rounded
                  : (event.value <= 100
                      ? (event.value < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded)
                      : (event.value <= 200 ? Icons.volume_up_rounded : Icons.warning_amber_rounded)),
              color: safetyColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Volume: ${event.label}',
              style: TextStyle(
                color: safetyColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (event.value / 300.0).clamp(0.0, 1.0),
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(safetyColor),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        );
      case GestureFeedbackType.zoom:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.zoom_in, color: EDesign.aiAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Zoom: ${event.label}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (event.value > 1.0) ...[
              const SizedBox(width: 8),
              const Text(
                '(Double-tap to reset)',
                style: TextStyle(
                  color: EDesign.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        );
      case GestureFeedbackType.wingJump:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              event.value < 0 ? Icons.replay_10 : Icons.forward_10,
              color: EDesign.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              event.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        );
    }
  }
}
