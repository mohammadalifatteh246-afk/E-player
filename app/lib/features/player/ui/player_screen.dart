import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../../core/engine_orchestrator.dart';
import '../../enhancement/ui/enhancement_studio_sheet.dart';
import 'subtitle_settings_sheet.dart';
import 'audio_studio_sheet.dart';

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
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  final EnhancementConfig _enhancementConfig = EnhancementConfig();
  final SubtitleConfig _subtitleConfig = SubtitleConfig();
  final AudioConfig _audioConfig = AudioConfig();

  String _decoderMode = 'Auto';
  String _aspectRatio = 'Fit';
  bool _pitchCorrection = true;
  bool _showTelemetry = false;

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

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(libass: true),
    );
    _controller = VideoController(_player);
    _aiEngine = NativeEngineOrchestrator();
    try { _aiEngine.initialize(); } catch (e) { debugPrint("AI load err: $e"); }

    _player.stream.playing.listen((playing) { if (mounted) setState(() => _isPlaying = playing); });
    _player.stream.position.listen((pos) { if (mounted) setState(() => _position = pos); });
    _player.stream.duration.listen((dur) { if (mounted) setState(() => _duration = dur); });
    _player.stream.rate.listen((rate) { if (mounted) setState(() => _playbackSpeed = rate); });
    _player.stream.tracks.listen((tracks) { if (mounted) setState(() => _subtitleTracks = tracks.subtitle); });
    _player.stream.track.listen((track) { if (mounted) setState(() => _selectedSubtitleTrack = track.subtitle); });
    _player.stream.volume.listen((vol) { if (mounted && !_isSwiping) _volume = vol; });

    try {
      if (widget.mediaPath.startsWith('http')) _player.open(Media(widget.mediaPath));
      else _player.open(Media(widget.mediaPath));
    } catch (e) {
      debugPrint("Media open err: $e");
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
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
    if (!_gesturesEnabled) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;
    if (dx < screenWidth * 0.33) {
       final newPos = _position - const Duration(seconds: 10);
       _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
       _showFeedbackMessage("-10s", Icons.fast_rewind);
    } else if (dx > screenWidth * 0.66) {
       final newPos = _position + const Duration(seconds: 10);
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
    if (!_gesturesEnabled) return;
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
    if (!_gesturesEnabled || !_isSwiping) return;

    if (details.pointerCount >= 2) {
       if ((details.scale - 1.0).abs() > 0.05 || _scale != 1.0) {
          setState(() {
            _scale = (_baseScale * details.scale).clamp(1.0, 5.0);
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
          _player.seek(newPos);
          _showFeedbackMessage(_formatDuration(newPos), Icons.schedule);
       }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _isSwiping = false;
    _swipeAction = '';
  }

  void _applyEnhancements() {
    try {
      final dynamic platform = _player.platform;
      if (_enhancementConfig.masterToggle && _aiEngine.isLoaded) {
        String sat = '0', con = '0', gamma = '0';
        bool isAnime = _enhancementConfig.aiModel.contains('Anime');
        if (isAnime) { sat = '25'; gamma = '5'; } 
        else { sat = '15'; gamma = '-5'; }

        switch (_enhancementConfig.resolution) {
          case '720p': con = isAnime ? '5' : '8'; break;
          case '1080p': con = isAnime ? '10' : '12'; break;
          case '1440p': con = isAnime ? '15' : '18'; break;
          case '4K': con = isAnime ? '25' : '30'; break;
        }

        platform.setProperty('saturation', sat);
        platform.setProperty('contrast', con);
        platform.setProperty('gamma', gamma);
        
        if (_enhancementConfig.audioEnhance) _player.setVolume(150.0);
        else if (_enhancementConfig.nightMode) _player.setVolume(50.0);
        else _player.setVolume(100.0);
      } else {
        platform.setProperty('saturation', '0');
        platform.setProperty('contrast', '0');
        platform.setProperty('gamma', '0');
        _player.setVolume(100.0);
      }
    } catch (e) {
      debugPrint("Enhancement err: $e");
    }
  }

  void _setDecoderMode(String mode) async {
    setState(() => _decoderMode = mode);
    final dynamic platform = _player.platform;
    try {
      String hwdecValue = 'auto';
      if (mode == 'HW') hwdecValue = 'yes';
      else if (mode == 'HW+') hwdecValue = 'auto-copy';
      else if (mode == 'SW') hwdecValue = 'no';
      await platform.setProperty('hwdec', hwdecValue);
    } catch (e) { debugPrint("hwdec err: $e"); }
  }

  void _showDecoderMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Decoder Mode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final mode in ['Auto', 'HW', 'HW+', 'SW'])
              ListTile(
                title: Text(mode, style: const TextStyle(color: Colors.white)),
                trailing: _decoderMode == mode ? const Icon(Icons.check, color: Colors.blueAccent) : null,
                onTap: () { _setDecoderMode(mode); Navigator.pop(context); },
              ),
          ],
        );
      }
    );
  }

  void _setAspectRatio(String ratio) {
    setState(() {
      _aspectRatio = ratio;
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  void _showAspectRatioMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Aspect Ratio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final ratio in ['Fit', 'Fill', 'Crop', 'Stretch', 'Original', '16:9', '4:3', '21:9', 'Pan & Scan'])
              ListTile(
                title: Text(ratio, style: const TextStyle(color: Colors.white)),
                trailing: _aspectRatio == ratio ? const Icon(Icons.check, color: Colors.blueAccent) : null,
                onTap: () { _setAspectRatio(ratio); Navigator.pop(context); },
              ),
          ],
        );
      }
    );
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0).copyWith(bottom: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Playback Speed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('${_playbackSpeed.toStringAsFixed(2)}x', style: const TextStyle(color: Colors.blueAccent, fontSize: 24)),
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
                    activeColor: Colors.blueAccent,
                  ),
                  SwitchListTile(
                    title: const Text('Pitch Correction', style: TextStyle(color: Colors.white)),
                    value: _pitchCorrection,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) {
                      setModalState(() => _pitchCorrection = v);
                      setState(() => _pitchCorrection = v);
                      _player.setPitch(_pitchCorrection ? 1.0 : _playbackSpeed);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [0.5, 1.0, 1.25, 1.5, 2.0].map((s) => TextButton(
                      onPressed: () {
                        setModalState(() => _playbackSpeed = s);
                        setState(() => _playbackSpeed = s);
                        _player.setRate(s);
                      },
                      child: Text('${s}x', style: const TextStyle(color: Colors.white)),
                    )).toList(),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showSubtitleMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Subtitles', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (_subtitleTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No subtitle tracks found', style: TextStyle(color: Colors.white54)),
              ),
            for (final track in _subtitleTracks)
              ListTile(
                title: Text(track.title ?? track.language ?? track.id, style: const TextStyle(color: Colors.white)),
                trailing: _selectedSubtitleTrack == track ? const Icon(Icons.check, color: Colors.blueAccent) : null,
                onTap: () { _player.setSubtitleTrack(track); Navigator.pop(context); },
              ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.tune, color: Colors.white),
              title: const Text('Styles & Delay...', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => SubtitleSettingsSheet(player: _player, config: _subtitleConfig),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_open, color: Colors.white),
              title: const Text('Load external subtitle...', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.pickFile(
                  type: FileType.custom, allowedExtensions: ['srt', 'ass', 'vtt'],
                );
                if (result != null && result.path != null) {
                  _player.setSubtitleTrack(SubtitleTrack.uri(File(result.path!).uri.toString()));
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
      case 'Fill': return BoxFit.cover;
      case 'Crop': return BoxFit.cover;
      case 'Stretch': return BoxFit.fill;
      case 'Pan & Scan': return BoxFit.cover;
      case 'Original': return BoxFit.none;
      default: return BoxFit.contain;
    }
  }

  double? _getAspectRatio() {
    switch (_aspectRatio) {
      case '16:9': return 16/9;
      case '4:3': return 4/3;
      case '21:9': return 21/9;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: Drawer(
        backgroundColor: const Color(0xFF0F0F13),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1A1A24)),
              child: Text('Player Settings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            SwitchListTile(
              title: const Text('Gesture Controls', style: TextStyle(color: Colors.white)),
              value: _gesturesEnabled,
              activeColor: const Color(0xFF00E5FF),
              onChanged: (v) => setState(() => _gesturesEnabled = v),
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onDoubleTapDown: _onDoubleTapDown,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Video Layer
            Center(
              child: Transform.translate(
                offset: _offset,
                child: Transform.scale(
                  scale: _scale,
                  child: Video(
                    controller: _controller,
                    fit: _aspectRatio == 'Fit' ? BoxFit.contain 
                        : _aspectRatio == 'Fill' ? BoxFit.fill 
                        : _aspectRatio == 'Crop' ? BoxFit.cover 
                        : _aspectRatio == '16:9' ? BoxFit.contain
                        : _aspectRatio == '4:3' ? BoxFit.contain
                        : _aspectRatio == '21:9' ? BoxFit.contain
                        : BoxFit.contain,
                    controls: NoVideoControls,
                  ),
                ),
              ),
            ),

            // Top Gradient Overlay (Cinematic)
            Positioned(
              top: 0, left: 0, right: 0,
              height: 100,
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
            
            // Top Bar Controls
            Positioned(
              top: 24, left: 16, right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('E-PLAYER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.auto_awesome, color: _enhancementConfig.masterToggle ? const Color(0xFF00E5FF) : Colors.white),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (context) {
                              return SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: EnhancementStudioSheet(
                                  aiEngine: _aiEngine, mediaPath: widget.mediaPath, config: _enhancementConfig,
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
                        icon: const Icon(Icons.equalizer, color: Colors.white),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => AudioStudioSheet(player: _player, config: _audioConfig),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.subtitles, color: Colors.white),
                        onPressed: _showSubtitleMenu,
                      ),
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Gradient Overlay
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: 160,
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

            // Visual Feedback Overlay
            if (_showFeedback)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_feedbackIcon != null) Icon(_feedbackIcon, color: Colors.white, size: 48),
                      if (_feedbackIcon != null) const SizedBox(height: 8),
                      Text(_feedbackText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

            // Bottom Controls (Glassmorphic vibe)
            Positioned(
              bottom: 24, left: 24, right: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: const Color(0xFF1A1A24).withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(_formatDuration(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF00E5FF),
                                inactiveTrackColor: Colors.white24,
                                thumbColor: const Color(0xFF00E5FF),
                                overlayColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                trackHeight: 4.0,
                              ),
                              child: Slider(
                                value: _position.inMilliseconds.toDouble(),
                                min: 0.0,
                                max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                              ),
                            ),
                          ),
                          Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              TextButton(
                                onPressed: _showSpeedMenu,
                                child: Text('x', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.aspect_ratio, color: Colors.white70),
                                onPressed: _showAspectRatioMenu,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                                onPressed: () {
                                  final newPos = _position - const Duration(seconds: 10);
                                  _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
                                },
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00E5FF),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 32),
                                  onPressed: () => _isPlaying ? _player.pause() : _player.play(),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                                onPressed: () {
                                  final newPos = _position + const Duration(seconds: 10);
                                  _player.seek(newPos > _duration ? _duration : newPos);
                                },
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.memory, color: Colors.white70),
                                onPressed: _showDecoderMenu,
                              ),
                              IconButton(
                                icon: Icon(Icons.analytics, color: _showTelemetry ? const Color(0xFF00E5FF) : Colors.white70),
                                onPressed: () => setState(() => _showTelemetry = !_showTelemetry),
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
            
            // Telemetry Overlay
            if (_showTelemetry)
              Positioned(
                top: 80,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Decoder: \$_decoderMode\n'
                    'Resolution: \${_player.state.width}x\${_player.state.height}\n'
                    'Video Codec: \${_player.state.track.video.title ?? _player.state.track.video.id}\n'
                    'Audio Codec: \${_player.state.track.audio.title ?? _player.state.track.audio.id}\n'
                    'Bitrate: \${_player.state.audioBitrate ?? "Unknown"}',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
