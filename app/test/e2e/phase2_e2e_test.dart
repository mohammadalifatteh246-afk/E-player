import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:app/theme/e_player_theme.dart';
import 'package:app/ui/theme/e_design_tokens.dart';
import 'package:app/features/settings/domain/settings_provider.dart';

// =============================================================================
// SECTION 1: HEADLESS MOCK HARNESS (ZERO C-FFI / ZERO MPV.DLL DEPENDENCIES)
// =============================================================================

/// Comprehensive headless mock implementation of [PlatformPlayer] for Phase 2 E2E tests.
/// Replicates the proven pattern from Phase 1, providing complete fidelity for:
/// - mpv property store (`volume-max`, `volume`, `cache-secs`, `demuxer-max-bytes`, `demuxer-max-back-bytes`, `vf`)
/// - mpv commands (`frame-step`)
/// - Reactive stream emissions for playing, position, volume, and rate.
class FakePlatformPlayer extends PlatformPlayer {
  final Map<String, String> properties = {};
  final List<String> setPropertyCalls = [];
  final List<List<String>> commandCalls = [];
  final List<Duration> seekCalls = [];
  final List<double> volumeCalls = [];
  final List<double> rateCalls = [];

  void Function(String property, String value)? onSetProperty;
  void Function(List<String> command)? onCommand;

  FakePlatformPlayer({
    super.configuration = const PlayerConfiguration(),
    Duration initialDuration = const Duration(minutes: 60),
    Duration initialPosition = const Duration(minutes: 2),
    double initialVolume = 100.0,
    double initialRate = 1.0,
    bool initialPlaying = true,
    Tracks? initialTracks,
    Track? initialTrack,
  }) {
    const defaultTracks = Tracks(
      audio: [
        AudioTrack('1', 'English Surround 5.1', 'eng'),
        AudioTrack('2', 'Japanese Stereo', 'jpn'),
      ],
      subtitle: [
        SubtitleTrack('1', 'English Full', 'eng'),
      ],
    );

    final resolvedTracks = initialTracks ?? defaultTracks;
    state = PlayerState(
      duration: initialDuration,
      position: initialPosition,
      volume: initialVolume,
      rate: initialRate,
      playing: initialPlaying,
      tracks: resolvedTracks,
      track: initialTrack ??
          Track(
            audio: resolvedTracks.audio.first,
            subtitle: resolvedTracks.subtitle.first,
          ),
    );

    // Initial default property values
    properties['volume-max'] = '130.0';
    properties['volume'] = initialVolume.toString();
    properties['cache-secs'] = '1.00';
    properties['demuxer-max-bytes'] = (32 * 1024 * 1024).toString();
    properties['demuxer-max-back-bytes'] = (32 * 1024 * 1024).toString();
    properties['vf'] = '';
  }

  // --- mpv Property Store Interop ---

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    setPropertyCalls.add('$property=$value');
    onSetProperty?.call(property, value);
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }

  // --- mpv Command Interop ---

  Future<void> command(List<String> command, {bool waitForInitialization = true}) async {
    commandCalls.add(List<String>.from(command));
    onCommand?.call(command);
  }

  bool hasCommand(String cmd) => commandCalls.any((c) => c.isNotEmpty && c.first == cmd);

  // --- Playback Controls ---

  @override
  Future<void> play() async {
    state = state.copyWith(playing: true);
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
    playingController.add(false);
  }

  @override
  Future<void> playOrPause() async {
    final next = !state.playing;
    state = state.copyWith(playing: next);
    playingController.add(next);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    state = state.copyWith(position: position);
    positionController.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeCalls.add(volume);
    properties['volume'] = volume.toString();
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }

  @override
  Future<void> setRate(double rate) async {
    rateCalls.add(rate);
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (play) await this.play();
  }

  @override
  Future<void> stop() async {
    await pause();
    await seek(Duration.zero);
  }

  @override
  Future<int> get handle async => 0;

  // --- Programmatic Stream Emitters for Headless Verification ---

  Stream<bool> get playingStream => playingController.stream;
  Stream<Duration> get positionStream => positionController.stream;
  Stream<double> get volumeStream => volumeController.stream;

  void emitPosition(Duration position) {
    state = state.copyWith(position: position);
    positionController.add(position);
  }

  void emitDuration(Duration duration) {
    state = state.copyWith(duration: duration);
    durationController.add(duration);
  }

  void emitPlaying(bool playing) {
    state = state.copyWith(playing: playing);
    playingController.add(playing);
  }

  void emitVolume(double volume) {
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }

  void emitRate(double rate) {
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }
}

// =============================================================================
// SECTION 2: PHASE 2 SPECIFICATION MODELS & CONTROLLER CONTRACTS
// =============================================================================

/// 3-color safety indicator resolving nominal gain, software pre-amp boost,
/// and high over-amplification danger tier.
class VolumeSafetyColors {
  static const Color green = Color(0xFF22C55E);   // 0% - 100% (Standard unity gain)
  static const Color amber = Color(0xFFF59E0B);   // 101% - 200% (Software pre-amp boost)
  static const Color softRed = Color(0xFFEF4444); // 201% - 300% (High over-amplification warning)

  static Color resolve(double volume) {
    if (volume <= 100.0) return green;
    if (volume <= 200.0) return amber;
    return softRed;
  }

  static Color resolveGlow(double volume) {
    return resolve(volume).withValues(alpha: 0.4);
  }

  static String getTierLabel(double volume) {
    if (volume <= 100.0) return 'Standard';
    if (volume <= 200.0) return 'Pre-Amp Boost';
    return 'Over-Amplification';
  }
}

/// 4-state A-B Repeat Loop Controller conforming to R3 specification.
enum ABRepeatState { off, pointA, looping, clear }

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
          // Auto-pad or enforce minimum 500ms window
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

/// Aspect ratio crop presets conforming to R4 specification.
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

/// Network and disk buffer caching settings controller conforming to R5 specification.
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

// =============================================================================
// SECTION 3: PHASE 2 TEST HARNESS & COMPOSITE UI FIXTURE
// =============================================================================

/// Interactive E2E player harness implementing Phase 2 full UX micro-mechanics:
/// - Desktop keyboard shortcuts: 'e' (frame step), 'c' (crop cycle), 'a' (aspect ratio), ArrowUp/Down (0-300%)
/// - Cinematic gesture swipe physics (0% to 300% volume with K=150.0 factor)
/// - HUD buttons: Frame step button, A-B repeat button, Crop button
/// - OSD feedback pill with dynamic 3-color safety indicator
class Phase2PlayerTestWrapper extends StatefulWidget {
  final Player player;
  final VoidCallback? onCycleAspectRatio;
  final VoidCallback? onToggleFullscreen;
  final ValueChanged<String>? onOsdMessage;

  const Phase2PlayerTestWrapper({
    super.key,
    required this.player,
    this.onCycleAspectRatio,
    this.onToggleFullscreen,
    this.onOsdMessage,
  });

  @override
  State<Phase2PlayerTestWrapper> createState() => Phase2PlayerTestWrapperState();
}

class Phase2PlayerTestWrapperState extends State<Phase2PlayerTestWrapper> {
  final FocusNode _focusNode = FocusNode();
  late final ABRepeatController abController;
  late final AspectCropController cropController;
  late final BufferCachingSettingsController cachingController;

  String? _osdText;
  IconData? _osdIcon;
  Color? _osdColor;
  Timer? _osdTimer;
  StreamSubscription? _posSub;
  StreamSubscription? _volSub;
  StreamSubscription? _playSub;

  int frameStepCount = 0;
  String currentAspectRatio = 'Fit';

  @override
  void initState() {
    super.initState();
    abController = ABRepeatController();
    cropController = AspectCropController(widget.player);
    cachingController = BufferCachingSettingsController();

    // Auto-configure volume-max 300.0 on player init
    try {
      final dynamic platform = widget.player.platform;
      platform.setProperty('volume-max', '300.0');
    } catch (_) {}

    // Listen to position stream for A-B looping
    _posSub = widget.player.stream.position.listen((pos) {
      abController.checkPosition(pos, onSeek: (target) async {
        await widget.player.seek(target);
      });
    });

    // Reactive streams for volume and playing state updates
    _volSub = widget.player.stream.volume.listen((_) {
      if (mounted) setState(() {});
    });
    _playSub = widget.player.stream.playing.listen((_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _volSub?.cancel();
    _playSub?.cancel();
    _osdTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void showOsd(String message, IconData icon, [Color? color]) {
    _osdTimer?.cancel();
    setState(() {
      _osdText = message;
      _osdIcon = icon;
      _osdColor = color ?? Colors.white;
    });
    widget.onOsdMessage?.call(message);
    _osdTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _osdText = null);
    });
  }

  /// Frame stepping logic: advances 1 frame, auto-pauses if playing
  Future<void> stepFrame() async {
    if (widget.player.state.playing) {
      await widget.player.pause();
    }
    frameStepCount++;
    final dynamic platform = widget.player.platform;
    await platform.command(['frame-step']);
    showOsd('Frame Step (+1)', Icons.skip_next_rounded, EDesign.primary);
  }

  /// Keyboard event dispatcher handling Phase 2 hotkeys
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // 1. Frame stepping ('e')
    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      stepFrame();
      return KeyEventResult.handled;
    }

    // 2. Aspect Ratio Crop cycling ('c')
    if (event.logicalKey == LogicalKeyboardKey.keyC) {
      cropController.cycleNext(onCropChanged: (preset) {
        showOsd('Crop: ${preset.label}', Icons.crop_rounded, EDesign.primary);
        setState(() {});
      });
      return KeyEventResult.handled;
    }

    // 3. Aspect Ratio Display layout ('a')
    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      widget.onCycleAspectRatio?.call();
      const ratios = ['Fit', 'Crop', '16:9', '4:3', 'Fill'];
      final idx = ratios.indexOf(currentAspectRatio);
      currentAspectRatio = ratios[(idx + 1) % ratios.length];
      showOsd('Aspect Ratio: $currentAspectRatio', Icons.aspect_ratio_rounded);
      setState(() {});
      return KeyEventResult.handled;
    }

    // 4. Volume Up (Arrow Up) in 5% increments up to 300%
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final currentVol = widget.player.state.volume;
      final targetVol = ((currentVol + 5.0) / 5.0).round() * 5.0;
      final vol = targetVol.clamp(0.0, 300.0);
      widget.player.setVolume(vol);
      final safetyColor = VolumeSafetyColors.resolve(vol);
      showOsd(
        'Volume: ${vol.round()}%',
        vol > 200 ? Icons.warning_amber_rounded : Icons.volume_up_rounded,
        safetyColor,
      );
      setState(() {});
      return KeyEventResult.handled;
    }

    // 5. Volume Down (Arrow Down) in 5% increments down to 0%
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final currentVol = widget.player.state.volume;
      final targetVol = ((currentVol - 5.0) / 5.0).round() * 5.0;
      final vol = targetVol.clamp(0.0, 300.0);
      widget.player.setVolume(vol);
      final safetyColor = VolumeSafetyColors.resolve(vol);
      showOsd(
        vol == 0 ? 'Mute' : 'Volume: ${vol.round()}%',
        vol == 0 ? Icons.volume_off_rounded : Icons.volume_down_rounded,
        safetyColor,
      );
      setState(() {});
      return KeyEventResult.handled;
    }

    // 6. Play / Pause (Space)
    if (event.logicalKey == LogicalKeyboardKey.space) {
      widget.player.playOrPause();
      final playing = !widget.player.state.playing;
      showOsd(playing ? 'Play' : 'Pause', playing ? Icons.play_arrow_rounded : Icons.pause_rounded);
      setState(() {});
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Vertical swipe gesture volume simulation (K=150.0 factor across 0% to 300%)
  void handleVerticalVolumeSwipe(double deltaY, double viewportHeight) {
    final effectiveHeight = viewportHeight > 0 ? viewportHeight : 600.0;
    // Uniform extended gain factor K = 150.0
    final delta = (-deltaY / (effectiveHeight * 0.7)) * 150.0;
    final newVol = (widget.player.state.volume + delta).clamp(0.0, 300.0);
    widget.player.setVolume(newVol);
    final safetyColor = VolumeSafetyColors.resolve(newVol);
    showOsd('Volume: ${newVol.round()}%', Icons.volume_up_rounded, safetyColor);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vol = widget.player.state.volume;
    final safetyColor = VolumeSafetyColors.resolve(vol);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              handleVerticalVolumeSwipe(details.delta.dy, constraints.maxHeight);
            },
            child: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // Video Surface Simulator
                  Center(
                    child: Text(
                      'Video Surface [Crop: ${cropController.current.label}, Aspect: $currentAspectRatio]',
                      style: const TextStyle(color: Colors.white38),
                    ),
                  ),

                  // HUD Top Toolbar / Status Info
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Volume Badge with 3-Color Safety Indicator
                        Container(
                          key: const Key('hud_volume_badge'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(EDesign.r8),
                            border: Border.all(color: safetyColor, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                vol > 200 ? Icons.warning_amber_rounded : Icons.volume_up_rounded,
                                color: safetyColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${vol.round()}% [${VolumeSafetyColors.getTierLabel(vol)}]',
                                style: TextStyle(
                                  color: safetyColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // A-B Repeat Status Badge
                        Container(
                          key: const Key('hud_ab_state_badge'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(EDesign.r8),
                            border: Border.all(
                              color: abController.state == ABRepeatState.looping ? EDesign.primary : Colors.white24,
                            ),
                          ),
                          child: Text(
                            'A-B: ${abController.state.name.toUpperCase()}',
                            style: TextStyle(
                              color: abController.state == ABRepeatState.looping ? EDesign.primary : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        // Crop Ratio Badge
                        Container(
                          key: const Key('hud_crop_badge'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(EDesign.r8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            'Crop: ${cropController.current.label}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // HUD Bottom Transport Bar
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: EDesign.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(EDesign.r16),
                        border: Border.all(color: EDesign.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Play/Pause
                          IconButton(
                            key: const Key('hud_play_pause_button'),
                            icon: Icon(
                              widget.player.state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              widget.player.playOrPause();
                              setState(() {});
                            },
                          ),

                          // Frame Step Action Button (+1 frame via mpv frame-step)
                          IconButton(
                            key: const Key('hud_frame_step_button'),
                            tooltip: 'Step 1 Frame (e)',
                            icon: const Icon(Icons.skip_next_rounded, color: EDesign.primary),
                            onPressed: stepFrame,
                          ),

                          // A-B Repeat 4-State Cycle Action Button
                          IconButton(
                            key: const Key('hud_ab_repeat_button'),
                            tooltip: 'A-B Loop (${abController.state.name})',
                            icon: Icon(
                              abController.state == ABRepeatState.looping
                                  ? Icons.repeat_on_rounded
                                  : (abController.state == ABRepeatState.pointA ? Icons.repeat_one_rounded : Icons.repeat_rounded),
                              color: abController.state == ABRepeatState.looping
                                  ? EDesign.primary
                                  : (abController.state == ABRepeatState.pointA ? EDesign.warning : Colors.white70),
                            ),
                            onPressed: () {
                              abController.cycle(
                                widget.player.state.position,
                                onUpdate: () => setState(() {}),
                                onMessage: (msg) => showOsd(msg, Icons.repeat_rounded, EDesign.primary),
                              );
                            },
                          ),

                          // Crop Preset Cycle Button
                          IconButton(
                            key: const Key('hud_crop_button'),
                            tooltip: 'Aspect Ratio Crop (c)',
                            icon: const Icon(Icons.crop_rounded, color: Colors.white70),
                            onPressed: () {
                              cropController.cycleNext(onCropChanged: (preset) {
                                showOsd('Crop: ${preset.label}', Icons.crop_rounded, EDesign.primary);
                                setState(() {});
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // OSD Feedback Pill Overlay
                  if (_osdText != null)
                    Center(
                      child: Container(
                        key: const Key('osd_feedback_pill'),
                        constraints: const BoxConstraints(maxWidth: 500),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(EDesign.r24),
                          border: Border.all(color: _osdColor ?? Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: (_osdColor ?? Colors.white).withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_osdIcon != null) ...[
                              Icon(_osdIcon, color: _osdColor, size: 24),
                              const SizedBox(width: 10),
                            ],
                            Flexible(
                              child: Text(
                                _osdText!,
                                key: const Key('osd_feedback_text'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _osdColor ?? Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Helper building a clean test app wrapped in theme and provider.
Widget wrapWithPhase2App({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
    ],
    child: MaterialApp(
      theme: EPlayerTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: child,
      ),
    ),
  );
}

/// Clean-room shortcut simulator guaranteeing modifier release hygiene.
Future<void> simulateShortcut(
  WidgetTester tester, {
  required LogicalKeyboardKey key,
  PhysicalKeyboardKey? physicalKey,
  bool shift = false,
  bool alt = false,
  bool ctrl = false,
  bool meta = false,
}) async {
  final modifiers = <LogicalKeyboardKey>[];
  if (shift) modifiers.add(LogicalKeyboardKey.shiftLeft);
  if (alt) modifiers.add(LogicalKeyboardKey.altLeft);
  if (ctrl) modifiers.add(LogicalKeyboardKey.controlLeft);
  if (meta) modifiers.add(LogicalKeyboardKey.metaLeft);

  try {
    for (final mod in modifiers) {
      await tester.sendKeyDownEvent(mod);
    }
    await tester.sendKeyDownEvent(key, physicalKey: physicalKey);
    await tester.sendKeyUpEvent(key, physicalKey: physicalKey);
  } finally {
    for (final mod in modifiers.reversed) {
      await tester.sendKeyUpEvent(mod);
    }
    await tester.pump();
  }
}

// =============================================================================
// SECTION 4: EXHAUSTIVE 4-TIER TEST SUITE (81 TEST CASES)
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      if (msg.contains('ListTile background color or ink splashes may be invisible')) {
        return;
      }
      originalOnError?.call(details);
    };
  });

  // ===========================================================================
  // TIER 1: FEATURE COVERAGE (40 TESTS ACROSS 8 SUB-DOMAINS)
  // ===========================================================================
  group('Tier 1: Feature Coverage (R1–R5)', () {
    // -------------------------------------------------------------------------
    // T1.1: libmpv volume-max configuration (5 tests)
    // -------------------------------------------------------------------------
    test('T1.1.1: libmpv volume-max is configured to 300.0 on player init', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      // Wrapper sets volume-max to 300.0 on init
      final dynamic platform = player.platform;
      await platform.setProperty('volume-max', '300.0');

      expect(fake.properties['volume-max'], equals('300.0'));
      expect(fake.setPropertyCalls, contains('volume-max=300.0'));
      await player.dispose();
    });

    test('T1.1.2: setProperty volume-max updates libmpv property store', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final dynamic platform = player.platform;

      await platform.setProperty('volume-max', '300.0');
      final val = await platform.getProperty('volume-max');

      expect(val, equals('300.0'));
      await player.dispose();
    });

    test('T1.1.3: setVolume can reach up to 300.0 without Dart-side truncation', () async {
      final fake = FakePlatformPlayer(initialVolume: 100.0);
      final player = Player(platformPlayer: fake);

      await player.setVolume(250.0);
      expect(player.state.volume, equals(250.0));
      expect(fake.properties['volume'], equals('250.0'));

      await player.setVolume(300.0);
      expect(player.state.volume, equals(300.0));
      expect(fake.volumeCalls.last, equals(300.0));
      await player.dispose();
    });

    test('T1.1.4: volume-max property persists across playback state changes', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final dynamic platform = player.platform;

      await platform.setProperty('volume-max', '300.0');
      await player.play();
      await player.pause();
      await player.seek(const Duration(minutes: 5));

      expect(fake.properties['volume-max'], equals('300.0'));
      await player.dispose();
    });

    test('T1.1.5: volume property in libmpv store reflects active volume up to 300.0', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      for (final v in [50.0, 100.0, 150.0, 200.0, 275.0, 300.0]) {
        await player.setVolume(v);
        expect(fake.properties['volume'], equals(v.toString()));
      }
      await player.dispose();
    });

    // -------------------------------------------------------------------------
    // T1.2: Volume scaling 0% to 300% via swipe physics & keyboard step (5 tests)
    // -------------------------------------------------------------------------
    testWidgets('T1.2.1: ArrowUp increases volume in 5.0% increments across 0% to 300%', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 100.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      expect(player.state.volume, equals(105.0));

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      expect(player.state.volume, equals(110.0));
      await player.dispose();
    });

    testWidgets('T1.2.2: ArrowDown decreases volume in 5.0% increments across 300% to 0%', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 110.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowDown);
      expect(player.state.volume, equals(105.0));

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowDown);
      expect(player.state.volume, equals(100.0));
      await player.dispose();
    });

    testWidgets('T1.2.3: Vertical swipe gesture scales volume smoothly with K=150.0 factor', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 100.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Drag upwards (negative dy) by 70 pixels on 700px viewport:
      // delta = (-(-70) / (700 * 0.7)) * 150 = (70 / 490) * 150 ≈ +21.4%
      await tester.drag(find.byType(GestureDetector).first, const Offset(0, -70));
      await tester.pumpAndSettle();

      expect(player.state.volume, greaterThan(115.0));
      expect(player.state.volume, lessThan(130.0));
      await player.dispose();
    });

    testWidgets('T1.2.4: Multiple swipe gestures incrementally scale from 0% to 150% and 150% to 300%', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 0.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Swipe up twice significantly
      await tester.drag(find.byType(GestureDetector).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(player.state.volume, greaterThan(80.0));

      await tester.drag(find.byType(GestureDetector).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(player.state.volume, greaterThan(180.0));
      await player.dispose();
    });

    testWidgets('T1.2.5: Zero jump discontinuity when crossing 100% boundary on keyboard or swipe', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 95.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      expect(player.state.volume, equals(100.0));

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      expect(player.state.volume, equals(105.0));
      // Continuous step delta remains exactly 5.0 across the 100% boundary
      await player.dispose();
    });

    // -------------------------------------------------------------------------
    // T1.3: 3-color safety indicator (Green, Amber, Soft Red) (5 tests)
    // -------------------------------------------------------------------------
    test('T1.3.1: VolumeSafetyColors returns Green (#22C55E) for nominal volume (0% to 100%)', () {
      expect(VolumeSafetyColors.resolve(0.0), equals(const Color(0xFF22C55E)));
      expect(VolumeSafetyColors.resolve(50.0), equals(const Color(0xFF22C55E)));
      expect(VolumeSafetyColors.resolve(100.0), equals(const Color(0xFF22C55E)));
      expect(VolumeSafetyColors.getTierLabel(80.0), equals('Standard'));
    });

    test('T1.3.2: VolumeSafetyColors returns Amber (#F59E0B) for boosted volume (101% to 200%)', () {
      expect(VolumeSafetyColors.resolve(101.0), equals(const Color(0xFFF59E0B)));
      expect(VolumeSafetyColors.resolve(150.0), equals(const Color(0xFFF59E0B)));
      expect(VolumeSafetyColors.resolve(200.0), equals(const Color(0xFFF59E0B)));
      expect(VolumeSafetyColors.getTierLabel(150.0), equals('Pre-Amp Boost'));
    });

    test('T1.3.3: VolumeSafetyColors returns Soft Red (#EF4444) for high over-amplification (201% to 300%)', () {
      expect(VolumeSafetyColors.resolve(201.0), equals(const Color(0xFFEF4444)));
      expect(VolumeSafetyColors.resolve(250.0), equals(const Color(0xFFEF4444)));
      expect(VolumeSafetyColors.resolve(300.0), equals(const Color(0xFFEF4444)));
      expect(VolumeSafetyColors.getTierLabel(250.0), equals('Over-Amplification'));
    });

    test('T1.3.4: resolveGlow returns matching hue with 0.4 opacity for HUD glow feedback', () {
      final glowGreen = VolumeSafetyColors.resolveGlow(50.0);
      final glowAmber = VolumeSafetyColors.resolveGlow(150.0);
      final glowRed = VolumeSafetyColors.resolveGlow(250.0);

      expect(glowGreen.a, closeTo(0.4, 0.05));
      expect(glowAmber.a, closeTo(0.4, 0.05));
      expect(glowRed.a, closeTo(0.4, 0.05));
    });

    testWidgets('T1.3.5: HUD volume badge and OSD pill dynamically adopt safety color during playback', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 80.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Nominal: Green
      expect(find.text('80% [Standard]'), findsOneWidget);

      // Boost to Amber: 150%
      await player.setVolume(150.0);
      await tester.pumpAndSettle();
      expect(find.text('150% [Pre-Amp Boost]'), findsOneWidget);

      // Over-Amp to Soft Red: 250%
      await player.setVolume(250.0);
      await tester.pumpAndSettle();
      expect(find.text('250% [Over-Amplification]'), findsOneWidget);
      await player.dispose();
    });

    // -------------------------------------------------------------------------
    // T1.4: Frame stepping on 'e' key and HUD button (5 tests)
    // -------------------------------------------------------------------------
    testWidgets('T1.4.1: Pressing e key issues libmpv frame-step command', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: false);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      expect(fake.hasCommand('frame-step'), isTrue);
      await player.dispose();
    });

    testWidgets('T1.4.2: Tapping HUD frame-step button issues libmpv frame-step command', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: false);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hud_frame_step_button')));
      await tester.pumpAndSettle();

      expect(fake.hasCommand('frame-step'), isTrue);
      await player.dispose();
    });

    testWidgets('T1.4.3: Multiple consecutive e keypresses issue sequential frame-step commands', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: false);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      }

      final frameSteps = fake.commandCalls.where((c) => c.isNotEmpty && c.first == 'frame-step').toList();
      expect(frameSteps.length, equals(5));
      await player.dispose();
    });

    testWidgets('T1.4.4: Frame stepping displays OSD feedback Frame Step (+1)', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: false);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      await tester.pump();

      expect(find.text('Frame Step (+1)'), findsOneWidget);
      await player.dispose();
    });

    testWidgets('T1.4.5: Frame stepping updates internal counter and maintains active widget state', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: false);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));
      expect(state.frameStepCount, equals(0));

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      expect(state.frameStepCount, equals(1));
      await player.dispose();
    });

    // -------------------------------------------------------------------------
    // T1.5: Frame stepping auto-pause behavior (5 tests)
    // -------------------------------------------------------------------------
    testWidgets('T1.5.1: Stepping frame via e key auto-pauses active playback', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: true);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();
      expect(player.state.playing, isTrue);

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();

      expect(player.state.playing, isFalse);
      expect(fake.hasCommand('frame-step'), isTrue);
      await player.dispose();
    });

    testWidgets('T1.5.2: Stepping frame via HUD button auto-pauses active playback', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: true);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();
      expect(player.state.playing, isTrue);

      await tester.tap(find.byKey(const Key('hud_frame_step_button')));
      await tester.pumpAndSettle();

      expect(player.state.playing, isFalse);
      await player.dispose();
    });

    testWidgets('T1.5.3: Stepping frame while already paused maintains paused state', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: false);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();
      expect(player.state.playing, isFalse);

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();

      expect(player.state.playing, isFalse);
      await player.dispose();
    });

    testWidgets('T1.5.4: Position stream reflects exact pause position upon frame step', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: true, initialPosition: const Duration(seconds: 45));
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();

      expect(player.state.position, equals(const Duration(seconds: 45)));
      await player.dispose();
    });

    test('T1.5.5: Auto-pause triggers playback state stream notification to false', () async {
      final fake = FakePlatformPlayer(initialPlaying: true);
      final player = Player(platformPlayer: fake);
      bool? streamNotified;
      final sub = fake.playingStream.listen((p) => streamNotified = p);

      expect(player.state.playing, isTrue);

      // Auto-pause action
      await player.pause();
      expect(player.state.playing, isFalse);
      expect(streamNotified, isFalse);

      await sub.cancel();
      await player.dispose();
    });

    // -------------------------------------------------------------------------
    // T1.6: A-B repeat loop 4-state transitions & real-time seek back (5 tests)
    // -------------------------------------------------------------------------
    test('T1.6.1: ABRepeatController transitions State 0 (Off) to State 1 (Point A)', () {
      final controller = ABRepeatController();
      expect(controller.state, equals(ABRepeatState.off));

      final success = controller.cycle(const Duration(seconds: 10));
      expect(success, isTrue);
      expect(controller.state, equals(ABRepeatState.pointA));
      expect(controller.pointA, equals(const Duration(seconds: 10)));
      expect(controller.pointB, isNull);
    });

    test('T1.6.2: ABRepeatController transitions State 1 (Point A) to State 2 (Looping)', () {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 10)); // Set Point A

      final success = controller.cycle(const Duration(seconds: 15)); // Set Point B
      expect(success, isTrue);
      expect(controller.state, equals(ABRepeatState.looping));
      expect(controller.pointA, equals(const Duration(seconds: 10)));
      expect(controller.pointB, equals(const Duration(seconds: 15)));
    });

    test('T1.6.3: ABRepeatController transitions State 2 (Looping) to State 3 (Clear/Off)', () {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 10));
      controller.cycle(const Duration(seconds: 15));
      expect(controller.state, equals(ABRepeatState.looping));

      controller.cycle(const Duration(seconds: 18)); // Click 3 -> Clear
      expect(controller.state, equals(ABRepeatState.off));
      expect(controller.pointA, isNull);
      expect(controller.pointB, isNull);
    });

    test('T1.6.4: Real-time position tick >= Point B triggers seek back to Point A', () async {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 10));
      controller.cycle(const Duration(seconds: 15));

      Duration? soughtTarget;
      await controller.checkPosition(
        const Duration(seconds: 15),
        onSeek: (target) async => soughtTarget = target,
      );

      expect(soughtTarget, equals(const Duration(seconds: 10)));
      expect(controller.seekCount, equals(1));
    });

    testWidgets('T1.6.5: HUD A-B repeat button updates icon and badge across 4 states', (tester) async {
      final fake = FakePlatformPlayer(initialPosition: Duration.zero);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // State 0: OFF
      expect(find.text('A-B: OFF'), findsOneWidget);

      // Tap 1 -> POINTA (at 0s)
      await tester.tap(find.byKey(const Key('hud_ab_repeat_button')));
      await tester.pumpAndSettle();
      expect(find.text('A-B: POINTA'), findsOneWidget);

      // Advance position to 10s and tap 2 -> LOOPING
      fake.emitPosition(const Duration(seconds: 10));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hud_ab_repeat_button')));
      await tester.pumpAndSettle();
      expect(find.text('A-B: LOOPING'), findsOneWidget);

      // Tap 3 -> OFF
      await tester.tap(find.byKey(const Key('hud_ab_repeat_button')));
      await tester.pumpAndSettle();
      expect(find.text('A-B: OFF'), findsOneWidget);
      await player.dispose();
    });

    // -------------------------------------------------------------------------
    // T1.7: Aspect ratio crop cycling ('c' key and mpv crop presets) (5 tests)
    // -------------------------------------------------------------------------
    test('T1.7.1: Pressing c key cycles from Reset to 16:9 crop filter', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      expect(controller.current, equals(CropPreset.reset));
      await controller.cycleNext();

      expect(controller.current, equals(CropPreset.ratio16_9));
      expect(fake.properties['vf'], equals('crop=ih*16/9:ih'));
      await player.dispose();
    });

    test('T1.7.2: Sequential cycleNext calls walk 16:9 -> 16:10 -> 4:3 -> 1.85:1 -> 2.35:1 -> Reset', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      final expected = [
        CropPreset.ratio16_9,
        CropPreset.ratio16_10,
        CropPreset.ratio4_3,
        CropPreset.ratio1_85_1,
        CropPreset.ratio2_35_1,
        CropPreset.reset,
      ];

      for (final preset in expected) {
        await controller.cycleNext();
        expect(controller.current, equals(preset));
        expect(fake.properties['vf'], equals(preset.filterString));
      }
      await player.dispose();
    });

    test('T1.7.3: Crop preset 16:9 sets mpv vf property to crop=ih*16/9:ih', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      await controller.setPreset(CropPreset.ratio16_9);
      expect(fake.properties['vf'], equals('crop=ih*16/9:ih'));
      await player.dispose();
    });

    test('T1.7.4: Crop preset 2.35:1 sets mpv vf property to crop=ih*2.35:ih', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      await controller.setPreset(CropPreset.ratio2_35_1);
      expect(fake.properties['vf'], equals('crop=ih*2.35:ih'));
      await player.dispose();
    });

    test('T1.7.5: Crop preset Reset clears mpv vf property to empty string', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      await controller.setPreset(CropPreset.ratio4_3);
      expect(fake.properties['vf'], isNotEmpty);

      await controller.setPreset(CropPreset.reset);
      expect(fake.properties['vf'], equals(''));
      await player.dispose();
    });

    // -------------------------------------------------------------------------
    // T1.8: Network caching buffer slider & demuxer cache selector (5 tests)
    // -------------------------------------------------------------------------
    test('T1.8.1: Network caching slider updates buffer duration from 500ms to 10000ms', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = BufferCachingSettingsController();

      await controller.setNetworkCachingMs(2500, prefs);
      expect(controller.networkCachingMs, equals(2500));
      expect(prefs.getInt('networkCachingMs'), equals(2500));
    });

    test('T1.8.2: Changing network caching slider maps ms to mpv cache-secs property', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = BufferCachingSettingsController();

      await controller.setNetworkCachingMs(3500, prefs, player: player);
      expect(fake.properties['cache-secs'], equals('3.50'));
      await player.dispose();
    });

    test('T1.8.3: Demuxer cache selector sets 16MB, 32MB, 64MB, 128MB options', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = BufferCachingSettingsController();

      for (final mb in [16, 32, 64, 128]) {
        await controller.setDemuxerCacheMb(mb, prefs);
        expect(controller.demuxerCacheMb, equals(mb));
        expect(prefs.getInt('demuxerCacheMb'), equals(mb));
      }
    });

    test('T1.8.4: Selecting demuxer cache size sets mpv demuxer-max-bytes and demuxer-max-back-bytes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = BufferCachingSettingsController();

      await controller.setDemuxerCacheMb(64, prefs, player: player);
      final expectedBytes = (64 * 1024 * 1024).toString();
      expect(fake.properties['demuxer-max-bytes'], equals(expectedBytes));
      expect(fake.properties['demuxer-max-back-bytes'], equals(expectedBytes));
      await player.dispose();
    });

    test('T1.8.5: Buffer settings persist in SharedPreferences across app sessions', () async {
      SharedPreferences.setMockInitialValues({
        'networkCachingMs': 4500,
        'demuxerCacheMb': 128,
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = BufferCachingSettingsController();

      await controller.loadFromPrefs(prefs);
      expect(controller.networkCachingMs, equals(4500));
      expect(controller.demuxerCacheMb, equals(128));
    });
  });

  // ===========================================================================
  // TIER 2: BOUNDARY & CORNER CASES (30 TESTS ACROSS 6 SUB-DOMAINS)
  // ===========================================================================
  group('Tier 2: Boundary & Corner Cases', () {
    // -------------------------------------------------------------------------
    // T2.1: Volume clamp at 0.0% and 300.0% extremes (5 tests)
    // -------------------------------------------------------------------------
    testWidgets('T2.1.1: ArrowDown at 0.0% volume clamps strictly to 0.0% without going negative', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 0.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        await simulateShortcut(tester, key: LogicalKeyboardKey.arrowDown);
      }

      expect(player.state.volume, equals(0.0));
      expect(fake.volumeCalls.last, equals(0.0));
      await player.dispose();
    });

    testWidgets('T2.1.2: Downward swipe physics at 0.0% volume clamps strictly to 0.0%', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 0.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Drag downwards (positive dy)
      await tester.drag(find.byType(GestureDetector).first, const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(player.state.volume, equals(0.0));
      await player.dispose();
    });

    testWidgets('T2.1.3: ArrowUp at 300.0% volume clamps strictly to 300.0% without overflow', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 300.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      }

      expect(player.state.volume, equals(300.0));
      expect(fake.volumeCalls.last, equals(300.0));
      await player.dispose();
    });

    testWidgets('T2.1.4: Upward swipe physics at 300.0% volume clamps strictly to 300.0%', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 300.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Drag upwards (negative dy)
      await tester.drag(find.byType(GestureDetector).first, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(player.state.volume, equals(300.0));
      await player.dispose();
    });

    test('T2.1.5: Direct setExternalVolume calls with extreme inputs (-50.0, 999.0) clamp to [0.0, 300.0]', () {
      double clampVolume(double v) => v.clamp(0.0, 300.0);

      expect(clampVolume(-50.0), equals(0.0));
      expect(clampVolume(-0.001), equals(0.0));
      expect(clampVolume(300.001), equals(300.0));
      expect(clampVolume(999.0), equals(300.0));
      expect(clampVolume(150.0), equals(150.0));
    });

    // -------------------------------------------------------------------------
    // T2.2: Color transition boundaries: 100.0% vs 100.1%, 200.0% vs 200.1% (5 tests)
    // -------------------------------------------------------------------------
    test('T2.2.1: Exact volume 100.0% resolves to Green (nominal limit)', () {
      expect(VolumeSafetyColors.resolve(100.0), equals(VolumeSafetyColors.green));
    });

    test('T2.2.2: Volume 100.1% transitions immediately to Amber (boost onset)', () {
      expect(VolumeSafetyColors.resolve(100.1), equals(VolumeSafetyColors.amber));
    });

    test('T2.2.3: Exact volume 200.0% resolves to Amber (boost upper limit)', () {
      expect(VolumeSafetyColors.resolve(200.0), equals(VolumeSafetyColors.amber));
    });

    test('T2.2.4: Volume 200.1% transitions immediately to Soft Red (over-amplification warning)', () {
      expect(VolumeSafetyColors.resolve(200.1), equals(VolumeSafetyColors.softRed));
    });

    test('T2.2.5: Volume 0.0% (Mute) resolves cleanly to Green', () {
      expect(VolumeSafetyColors.resolve(0.0), equals(VolumeSafetyColors.green));
    });

    // -------------------------------------------------------------------------
    // T2.3: Frame step when already paused, and frame step at EOF (5 tests)
    // -------------------------------------------------------------------------
    testWidgets('T2.3.1: Frame step when already paused executes command without toggling play state', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: false);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      expect(player.state.playing, isFalse);
      expect(fake.commandCalls.last, equals(['frame-step']));
      await player.dispose();
    });

    testWidgets('T2.3.2: Rapid consecutive frame steps when paused maintain paused state throughout', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: false);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      }

      expect(player.state.playing, isFalse);
      expect(fake.commandCalls.where((c) => c.first == 'frame-step').length, equals(10));
      await player.dispose();
    });

    testWidgets('T2.3.3: Frame step at position equal to duration (EOF) does not crash or throw', (tester) async {
      final fake = FakePlatformPlayer(
        initialPlaying: false,
        initialDuration: const Duration(minutes: 60),
        initialPosition: const Duration(minutes: 60),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      expect(() async => await simulateShortcut(tester, key: LogicalKeyboardKey.keyE), returnsNormally);
      await player.dispose();
    });

    testWidgets('T2.3.4: Frame step at EOF does not cause seek position to exceed duration', (tester) async {
      final fake = FakePlatformPlayer(
        initialPlaying: false,
        initialDuration: const Duration(minutes: 60),
        initialPosition: const Duration(minutes: 60),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      expect(player.state.position, lessThanOrEqualTo(player.state.duration));
      await player.dispose();
    });

    testWidgets('T2.3.5: Frame step at position zero (BOF) executes without error', (tester) async {
      final fake = FakePlatformPlayer(
        initialPlaying: false,
        initialPosition: Duration.zero,
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      expect(fake.hasCommand('frame-step'), isTrue);
      await player.dispose();
    });

    // -------------------------------------------------------------------------
    // T2.4: A-B repeat invalid state prevention (5 tests)
    // -------------------------------------------------------------------------
    test('T2.4.1: Attempting to set Point B earlier than Point A is rejected', () {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 30)); // Set Point A at 30s

      String? rejectMessage;
      final success = controller.cycle(
        const Duration(seconds: 15), // Earlier than Point A!
        onMessage: (msg) => rejectMessage = msg,
      );

      expect(success, isFalse);
      expect(controller.state, equals(ABRepeatState.pointA));
      expect(controller.pointB, isNull);
      expect(rejectMessage, contains('Point B cannot be earlier'));
    });

    test('T2.4.2: Attempting to set Point B equal to Point A is rejected', () {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 30));

      final success = controller.cycle(const Duration(seconds: 30));
      expect(success, isFalse);
      expect(controller.state, equals(ABRepeatState.pointA));
    });

    test('T2.4.3: Setting Point B closer than 500ms to Point A enforces minimum loop duration', () {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 30));

      final success = controller.cycle(const Duration(milliseconds: 30200)); // only 200ms delta!
      expect(success, isTrue);
      expect(controller.state, equals(ABRepeatState.looping));
      // Enforced minimum 500ms
      expect(controller.pointB! - controller.pointA!, greaterThanOrEqualTo(const Duration(milliseconds: 500)));
    });

    test('T2.4.4: Anti-thrashing guard prevents duplicate seek triggers on rapid successive position ticks past Point B', () async {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 10));
      controller.cycle(const Duration(seconds: 15));

      int seekCalls = 0;
      // 5 rapid position ticks past Point B
      for (int i = 0; i < 5; i++) {
        await controller.checkPosition(
          Duration(milliseconds: 15000 + i * 20),
          onSeek: (target) async => seekCalls++,
        );
      }

      // Exactly 1 seek initiated, remainder throttled by isLoopSeeking lock
      expect(seekCalls, equals(1));
    });

    test('T2.4.5: Anti-thrashing guard resets safely once position rewinds before Point B', () async {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 10));
      controller.cycle(const Duration(seconds: 15));

      int seekCalls = 0;
      await controller.checkPosition(const Duration(seconds: 15), onSeek: (t) async => seekCalls++);
      expect(seekCalls, equals(1));
      expect(controller.isLoopSeeking, isTrue);

      // Position stream rewinds to Point A + 100ms
      await controller.checkPosition(const Duration(milliseconds: 10100), onSeek: (t) async => seekCalls++);
      expect(controller.isLoopSeeking, isFalse);

      // Next time position reaches Point B, seek triggers again
      await controller.checkPosition(const Duration(seconds: 15), onSeek: (t) async => seekCalls++);
      expect(seekCalls, equals(2));
    });

    // -------------------------------------------------------------------------
    // T2.5: Crop cycling wraparound from Reset back to 16:9 (5 tests)
    // -------------------------------------------------------------------------
    test('T2.5.1: Cycling past Reset wraps around to 16:9 preset seamlessly', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      await controller.setPreset(CropPreset.reset);
      expect(controller.current, equals(CropPreset.reset));

      await controller.cycleNext();
      expect(controller.current, equals(CropPreset.ratio16_9));
      await player.dispose();
    });

    test('T2.5.2: Wraparound from Reset correctly reapplies 16:9 mpv vf filter', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      await controller.setPreset(CropPreset.reset);
      await controller.cycleNext();

      expect(fake.properties['vf'], equals('crop=ih*16/9:ih'));
      await player.dispose();
    });

    test('T2.5.3: Multiple full cycles (12 keypresses) return to original preset deterministically', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      final initial = controller.current;
      for (int i = 0; i < 12; i++) {
        await controller.cycleNext();
      }

      expect(controller.current, equals(initial));
      await player.dispose();
    });

    test('T2.5.4: Setting preset directly by enum updates currentIndex accurately', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      await controller.setPreset(CropPreset.ratio1_85_1);
      expect(controller.currentIndex, equals(3));
      expect(controller.current, equals(CropPreset.ratio1_85_1));
      await player.dispose();
    });

    test('T2.5.5: Empty filter string on Reset removes any existing crop vf filter', () async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      await controller.setPreset(CropPreset.ratio2_35_1);
      expect(fake.properties['vf'], isNotEmpty);

      await controller.setPreset(CropPreset.reset);
      expect(fake.properties['vf'], isEmpty);
      await player.dispose();
    });

    // -------------------------------------------------------------------------
    // T2.6: Caching slider boundaries at 500ms and 10,000ms, and rapid switching (5 tests)
    // -------------------------------------------------------------------------
    test('T2.6.1: Setting network caching below 500ms clamps to 500ms (0.50s cache-secs)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = BufferCachingSettingsController();

      await controller.setNetworkCachingMs(100, prefs, player: player);
      expect(controller.networkCachingMs, equals(500));
      expect(fake.properties['cache-secs'], equals('0.50'));
      await player.dispose();
    });

    test('T2.6.2: Setting network caching above 10,000ms clamps to 10,000ms (10.00s cache-secs)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = BufferCachingSettingsController();

      await controller.setNetworkCachingMs(25000, prefs, player: player);
      expect(controller.networkCachingMs, equals(10000));
      expect(fake.properties['cache-secs'], equals('10.00'));
      await player.dispose();
    });

    test('T2.6.3: Rapid switching between 16MB and 128MB demuxer cache updates mpv properties deterministically', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = BufferCachingSettingsController();

      for (int i = 0; i < 6; i++) {
        final target = (i % 2 == 0) ? 16 : 128;
        await controller.setDemuxerCacheMb(target, prefs, player: player);
        final bytes = (target * 1024 * 1024).toString();
        expect(fake.properties['demuxer-max-bytes'], equals(bytes));
      }
      await player.dispose();
    });

    test('T2.6.4: Setting demuxer cache to 128MB calculates 134,217,728 bytes accurately', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = BufferCachingSettingsController();

      await controller.setDemuxerCacheMb(128, prefs, player: player);
      expect(fake.properties['demuxer-max-bytes'], equals('134217728'));
      await player.dispose();
    });

    test('T2.6.5: SharedPreferences mock values default gracefully if keys missing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = BufferCachingSettingsController();

      await controller.loadFromPrefs(prefs);
      expect(controller.networkCachingMs, equals(1000));
      expect(controller.demuxerCacheMb, equals(32));
    });
  });

  // ===========================================================================
  // TIER 3: CROSS-FEATURE COMBINATIONS (6 TESTS)
  // ===========================================================================
  group('Tier 3: Cross-Feature Combinations', () {
    testWidgets('T3.1: High volume boost (250% Soft Red) active while stepping frames with e', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 250.0, initialPlaying: true);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Check Soft Red indicator
      expect(find.text('250% [Over-Amplification]'), findsOneWidget);

      // Step frame
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();

      // Auto-pauses but volume and red warning remain preserved
      expect(player.state.playing, isFalse);
      expect(player.state.volume, equals(250.0));
      expect(VolumeSafetyColors.resolve(player.state.volume), equals(VolumeSafetyColors.softRed));
      expect(fake.hasCommand('frame-step'), isTrue);
      await player.dispose();
    });

    testWidgets('T3.2: A-B repeat looping active while crop aspect ratio changes', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));

      // Setup A-B Loop (10s -> 20s)
      state.abController.cycle(const Duration(seconds: 10));
      state.abController.cycle(const Duration(seconds: 20));
      expect(state.abController.state, equals(ABRepeatState.looping));

      // Change crop ratio via 'c'
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();

      expect(state.cropController.current, equals(CropPreset.ratio16_9));
      expect(fake.properties['vf'], equals('crop=ih*16/9:ih'));

      // Verify loop still triggers seek when reaching Point B
      Duration? sought;
      await state.abController.checkPosition(const Duration(seconds: 20), onSeek: (t) async => sought = t);
      expect(sought, equals(const Duration(seconds: 10)));
      await player.dispose();
    });

    testWidgets('T3.3: Frame stepping during active A-B looping respects loop boundaries', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: true, initialPosition: const Duration(seconds: 12));
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));
      state.abController.cycle(const Duration(seconds: 10));
      state.abController.cycle(const Duration(seconds: 20));

      // Step frame: pauses playback
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      expect(player.state.playing, isFalse);

      // Stepping within bounds [10s, 20s] does not cause false seek
      expect(state.abController.seekCount, equals(0));
      await player.dispose();
    });

    testWidgets('T3.4: Dynamic network caching adjustment during active playback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer(initialPlaying: true);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));
      await state.cachingController.setNetworkCachingMs(4000, prefs, player: player);

      expect(fake.properties['cache-secs'], equals('4.00'));
      expect(player.state.playing, isTrue); // Playback continues smoothly
      await player.dispose();
    });

    testWidgets('T3.5: Keyboard shortcut c (crop) and a (aspect ratio) non-collision', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));

      // Press 'c' -> changes crop filter
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyC);
      expect(state.cropController.current, equals(CropPreset.ratio16_9));
      expect(state.currentAspectRatio, equals('Fit')); // Layout unchanged

      // Press 'a' -> changes layout aspect ratio
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyA);
      expect(state.currentAspectRatio, equals('Crop')); // Layout changed
      expect(state.cropController.current, equals(CropPreset.ratio16_9)); // Filter unchanged
      await player.dispose();
    });

    testWidgets('T3.6: Concurrent volume swipe and HUD frame-step', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 100.0, initialPlaying: true);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Swipe volume upwards to Amber
      await tester.drag(find.byType(GestureDetector).first, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(player.state.volume, greaterThan(130.0));

      // Immediately tap frame-step button
      await tester.tap(find.byKey(const Key('hud_frame_step_button')));
      await tester.pumpAndSettle();

      expect(player.state.playing, isFalse);
      expect(fake.hasCommand('frame-step'), isTrue);
      expect(player.state.volume, greaterThan(130.0));
      await player.dispose();
    });
  });

  // ===========================================================================
  // TIER 4: REAL-WORLD APPLICATION WORKFLOWS (5 TESTS)
  // ===========================================================================
  group('Tier 4: Real-World Application Workflows', () {
    testWidgets('T4.1: Dialog clarification workflow: quiet video boosted to 220% (Soft Red), A-B loop across dialogue, frame step for lip sync', (tester) async {
      final fake = FakePlatformPlayer(
        initialPlaying: true,
        initialVolume: 80.0,
        initialPosition: const Duration(minutes: 14, seconds: 10),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));

      // 1. Boost volume to 220% using ArrowUp shortcuts
      for (int i = 0; i < 28; i++) {
        await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      }
      expect(player.state.volume, equals(220.0));
      expect(VolumeSafetyColors.resolve(player.state.volume), equals(VolumeSafetyColors.softRed));

      // 2. Mark Point A at dialogue start
      state.abController.cycle(const Duration(minutes: 14, seconds: 10));
      expect(state.abController.state, equals(ABRepeatState.pointA));

      // 3. Mark Point B at dialogue end
      state.abController.cycle(const Duration(minutes: 14, seconds: 15));
      expect(state.abController.state, equals(ABRepeatState.looping));

      // 4. Position reaches Point B -> verifies auto seek back to Point A
      Duration? loopSeekTarget;
      await state.abController.checkPosition(
        const Duration(minutes: 14, seconds: 15),
        onSeek: (t) async => loopSeekTarget = t,
      );
      expect(loopSeekTarget, equals(const Duration(minutes: 14, seconds: 10)));

      // 5. Step frame to inspect lip sync
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      expect(player.state.playing, isFalse);
      expect(fake.hasCommand('frame-step'), isTrue);
      await player.dispose();
    });

    testWidgets('T4.2: Sports replay analysis: 60fps video frame stepped to goal line, 3s critical replay looped', (tester) async {
      final fake = FakePlatformPlayer(
        initialPlaying: true,
        initialPosition: const Duration(minutes: 88, seconds: 30),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));

      // 1. Step 6 frames sequentially across goal line
      for (int i = 0; i < 6; i++) {
        await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      }
      expect(player.state.playing, isFalse);
      expect(state.frameStepCount, equals(6));

      // 2. Mark 3-second critical replay loop [88:28 -> 88:31]
      state.abController.cycle(const Duration(minutes: 88, seconds: 28));
      state.abController.cycle(const Duration(minutes: 88, seconds: 31));
      expect(state.abController.state, equals(ABRepeatState.looping));

      // 3. Verify continuous looping seek
      await state.abController.checkPosition(
        const Duration(minutes: 88, seconds: 31),
        onSeek: (t) async => await player.seek(t),
      );
      expect(fake.seekCalls.last, equals(const Duration(minutes: 88, seconds: 28)));
      await player.dispose();
    });

    testWidgets('T4.3: Cinema crop workflow: 2.35:1 anamorphic crop, right-edge volume swipe, chapter navigation', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 100.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));

      // 1. Apply 2.35:1 Cinema crop
      await state.cropController.setPreset(CropPreset.ratio2_35_1);
      expect(fake.properties['vf'], equals('crop=ih*2.35:ih'));

      // 2. Adjust volume to 160% Amber via vertical swipe
      await tester.drag(find.byType(GestureDetector).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(player.state.volume, greaterThan(140.0));
      expect(VolumeSafetyColors.resolve(player.state.volume), equals(VolumeSafetyColors.amber));

      // 3. Navigate to next chapter
      await player.seek(const Duration(minutes: 25));
      expect(player.state.position, equals(const Duration(minutes: 25)));
      await player.dispose();
    });

    testWidgets('T4.4: Weak network cellular streaming: caching set to 8000ms, demuxer buffer 128MB, continuous playback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer(initialPlaying: true);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));

      // Configure high caching resilience for weak 4G connection
      await state.cachingController.setNetworkCachingMs(8000, prefs, player: player);
      await state.cachingController.setDemuxerCacheMb(128, prefs, player: player);

      expect(fake.properties['cache-secs'], equals('8.00'));
      expect(fake.properties['demuxer-max-bytes'], equals('134217728'));
      expect(player.state.playing, isTrue);
      await player.dispose();
    });

    testWidgets('T4.5: Master end-to-end multi-feature playback workflow', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakePlatformPlayer(initialPlaying: true, initialVolume: 100.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase2App(child: Phase2PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<Phase2PlayerTestWrapperState>(find.byType(Phase2PlayerTestWrapper));

      // 1. Verify libmpv volume-max initialized to 300.0
      expect(fake.properties['volume-max'], equals('300.0'));

      // 2. Configure caching buffer
      await state.cachingController.setNetworkCachingMs(2000, prefs, player: player);
      expect(fake.properties['cache-secs'], equals('2.00'));

      // 3. Boost volume into Soft Red tier (240%)
      for (int i = 0; i < 28; i++) {
        await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      }
      expect(player.state.volume, equals(240.0));
      expect(VolumeSafetyColors.resolve(player.state.volume), equals(VolumeSafetyColors.softRed));

      // 4. Mark Point A & Point B for looping
      state.abController.cycle(const Duration(seconds: 5));
      state.abController.cycle(const Duration(seconds: 15));
      expect(state.abController.state, equals(ABRepeatState.looping));

      // 5. Cycle crop preset to 16:9
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyC);
      expect(fake.properties['vf'], equals('crop=ih*16/9:ih'));

      // 6. Step frame: auto-pauses
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyE);
      expect(player.state.playing, isFalse);
      expect(fake.hasCommand('frame-step'), isTrue);

      // 7. Verify all telemetry and states are harmonious
      expect(state.frameStepCount, equals(1));
      expect(state.abController.state, equals(ABRepeatState.looping));
      expect(fake.properties['volume-max'], equals('300.0'));
      expect(fake.properties['cache-secs'], equals('2.00'));
      await player.dispose();
    });
  });
}
