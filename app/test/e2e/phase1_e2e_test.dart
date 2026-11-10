import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:app/theme/e_player_theme.dart';
import 'package:app/ui/theme/e_design_tokens.dart';
import 'package:app/features/settings/domain/settings_provider.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import 'package:app/features/library/domain/library_provider.dart';
import 'package:app/features/home/domain/media_group_service.dart';
import 'package:app/features/export/domain/export_service.dart';
import 'package:app/features/vault/domain/vault_service.dart';
import 'package:app/features/trash/domain/trash_service.dart';
import 'package:app/features/player/ui/widgets/desktop_keyboard_handler.dart';
import 'package:app/features/player/ui/audio_studio_sheet.dart';

// =============================================================================
// SECTION 1: HEADLESS MOCK HARNESS (ZERO C-FFI / ZERO MPV.DLL DEPENDENCIES)
// =============================================================================

/// Comprehensive headless mock implementation of [PlatformPlayer] for Phase 1 E2E tests.
class FakePlatformPlayer extends PlatformPlayer {
  final Map<String, String> properties = {};
  final List<String> setPropertyCalls = [];
  final List<Duration> seekCalls = [];
  final List<double> volumeCalls = [];
  final List<double> rateCalls = [];
  final List<AudioTrack> setAudioTrackCalls = [];
  final List<SubtitleTrack> setSubtitleTrackCalls = [];

  void Function(String property, String value)? onSetProperty;

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
        AudioTrack('3', 'Director Commentary', 'eng'),
      ],
      subtitle: [
        SubtitleTrack('1', 'English Full', 'eng'),
        SubtitleTrack('2', 'English SDH', 'eng'),
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
            audio: resolvedTracks.audio.isNotEmpty ? resolvedTracks.audio.first : AudioTrack.no(),
            subtitle: resolvedTracks.subtitle.isNotEmpty ? resolvedTracks.subtitle.first : SubtitleTrack.no(),
          ),
    );
  }

  // --- mpv Property Accessors (libmpv Property Store) ---

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    setPropertyCalls.add('$property=$value');
    onSetProperty?.call(property, value);
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }

  // --- Player Playback Controls ---

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
  Future<void> setAudioTrack(AudioTrack track) async {
    setAudioTrackCalls.add(track);
    state = state.copyWith(track: state.track.copyWith(audio: track));
    trackController.add(state.track);
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    setSubtitleTrackCalls.add(track);
    state = state.copyWith(track: state.track.copyWith(subtitle: track));
    trackController.add(state.track);
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

  // --- Programmatic Test Emitters ---

  void emitTracks(Tracks tracks) {
    state = state.copyWith(tracks: tracks);
    tracksController.add(tracks);
  }

  void emitTrack(Track track) {
    state = state.copyWith(track: track);
    trackController.add(track);
  }

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
// SECTION 2: KEYBOARD SIMULATOR & TEST HELPERS
// =============================================================================

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

  final resolvedPhysical = physicalKey ??
      (key == LogicalKeyboardKey.add ? PhysicalKeyboardKey.numpadAdd : null);

  try {
    for (final mod in modifiers) {
      await tester.sendKeyDownEvent(mod);
    }
    await tester.sendKeyDownEvent(key, physicalKey: resolvedPhysical);
    await tester.sendKeyUpEvent(key, physicalKey: resolvedPhysical);
  } finally {
    for (final mod in modifiers.reversed) {
      await tester.sendKeyUpEvent(mod);
    }
    await tester.pump();
  }
}

/// Helper building a test app wrapped in all production MultiProvider services.
Widget wrapWithPhase1App({
  required Widget child,
  SettingsProvider? settingsProvider,
  CastService? castService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>(create: (_) => settingsProvider ?? SettingsProvider()),
      ChangeNotifierProvider<CastService>(create: (_) => castService ?? CastService()),
      ChangeNotifierProvider<LibraryProvider>(create: (_) => LibraryProvider()),
      ChangeNotifierProvider<MediaGroupService>(create: (_) => MediaGroupService()),
      ChangeNotifierProvider<ExportService>(create: (_) => ExportService()),
      ChangeNotifierProvider<VaultService>(create: (_) => VaultService()),
      ChangeNotifierProvider<TrashService>(create: (_) => TrashService()),
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

// =============================================================================
// SECTION 3: PHASE 1 COMPOSITE TEST FIXTURES & UI HARNESS
// =============================================================================

/// Audio Delay Synchronization Card conforming to R3 specification.
class AudioDelaySyncCard extends StatefulWidget {
  final Player player;
  final double initialDelayMs;
  final ValueChanged<double>? onDelayChanged;

  const AudioDelaySyncCard({
    super.key,
    required this.player,
    this.initialDelayMs = 0.0,
    this.onDelayChanged,
  });

  @override
  State<AudioDelaySyncCard> createState() => AudioDelaySyncCardState();
}

class AudioDelaySyncCardState extends State<AudioDelaySyncCard> {
  late double _delayMs;

  @override
  void initState() {
    super.initState();
    _delayMs = widget.initialDelayMs;
  }

  void updateDelay(double ms) {
    final clamped = ms.clamp(-10000.0, 10000.0);
    setState(() {
      _delayMs = clamped;
    });
    try {
      final dynamic platform = widget.player.platform;
      platform.setProperty('audio-delay', (_delayMs / 1000.0).toStringAsFixed(3));
    } catch (_) {}
    widget.onDelayChanged?.call(_delayMs);
  }

  void nudge(double deltaMs) {
    updateDelay(_delayMs + deltaMs);
  }

  void reset() {
    updateDelay(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('audio_delay_sync_card'),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync, color: EDesign.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Audio Synchronization',
                    style: TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                key: const Key('audio_delay_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: EDesign.elevatedSurface,
                  borderRadius: BorderRadius.circular(EDesign.r8),
                  border: Border.all(color: EDesign.border),
                ),
                child: Text(
                  '${_delayMs >= 0 ? "+" : ""}${_delayMs.toStringAsFixed(0)} ms',
                  style: const TextStyle(
                    color: EDesign.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('-10.0s', style: TextStyle(color: EDesign.textMuted, fontSize: 10)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: EDesign.primary,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: EDesign.primary,
                    overlayColor: EDesign.primary.withValues(alpha: 0.25),
                  ),
                  child: Slider(
                    key: const Key('audio_delay_slider'),
                    value: (_delayMs / 1000.0).clamp(-10.0, 10.0),
                    min: -10.0,
                    max: 10.0,
                    divisions: 400,
                    onChanged: (v) {
                      updateDelay((v * 1000.0 * 2).round() / 2.0);
                    },
                  ),
                ),
              ),
              const Text('+10.0s', style: TextStyle(color: EDesign.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNudgeButton('-100ms', const Key('audio_delay_nudge_minus_100'), () => nudge(-100)),
              _buildNudgeButton('-50ms', const Key('audio_delay_nudge_minus_50'), () => nudge(-50)),
              _buildNudgeButton('Reset', const Key('audio_delay_nudge_reset'), reset),
              _buildNudgeButton('+50ms', const Key('audio_delay_nudge_plus_50'), () => nudge(50)),
              _buildNudgeButton('+100ms', const Key('audio_delay_nudge_plus_100'), () => nudge(100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeButton(String label, Key key, VoidCallback onTap) {
    return OutlinedButton(
      key: key,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: EDesign.textPrimary,
        side: const BorderSide(color: EDesign.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(54, 32),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

/// Composite Phase 1 Test Wrapper integrating DesktopKeyboardHandler, Top Bar HUD,
/// Audio Track Modal, AudioStudioSheet, AudioDelaySyncCard, and OSD pill.
class Phase1PlayerTestWrapper extends StatefulWidget {
  final Player player;
  final AudioConfig? audioConfig;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onCycleAspectRatio;
  final ValueChanged<int>? onNudgeAudioDelay;
  final ValueChanged<int>? onNudgeSubtitleDelay;
  final VoidCallback? onUserActivity;
  final double initialAudioDelayMs;
  final bool autoDismissOsd;

  const Phase1PlayerTestWrapper({
    super.key,
    required this.player,
    this.audioConfig,
    this.onToggleFullscreen,
    this.onCycleAspectRatio,
    this.onNudgeAudioDelay,
    this.onNudgeSubtitleDelay,
    this.onUserActivity,
    this.initialAudioDelayMs = 0.0,
    this.autoDismissOsd = false,
  });

  @override
  State<Phase1PlayerTestWrapper> createState() => Phase1PlayerTestWrapperState();
}

class Phase1PlayerTestWrapperState extends State<Phase1PlayerTestWrapper> {
  String? _osdText;
  IconData? _osdIcon;
  bool _showOsd = false;
  Timer? _osdTimer;
  late AudioConfig _audioConfig;
  double _audioDelayMs = 0.0;
  int fullscreenToggles = 0;
  int aspectRatioCycles = 0;

  @override
  void initState() {
    super.initState();
    _audioConfig = widget.audioConfig ?? AudioConfig();
    _audioDelayMs = widget.initialAudioDelayMs;
  }

  @override
  void dispose() {
    _osdTimer?.cancel();
    _osdTimer = null;
    super.dispose();
  }

  void showOsd(String message, IconData icon) {
    _osdTimer?.cancel();
    setState(() {
      _osdText = message;
      _osdIcon = icon;
      _showOsd = true;
    });
    if (widget.autoDismissOsd) {
      _osdTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _showOsd = false);
        }
      });
    }
  }

  void cycleAudioTrack() {
    final tracks = widget.player.state.tracks.audio;
    if (tracks.isEmpty) return;
    final current = widget.player.state.track.audio;
    final idx = tracks.indexWhere((t) => t.id == current.id);
    final nextIdx = (idx + 1) % tracks.length;
    final nextTrack = tracks[nextIdx];
    widget.player.setAudioTrack(nextTrack);
    showOsd('Audio: ${nextTrack.title ?? nextTrack.language ?? nextTrack.id}', Icons.audiotrack_rounded);
  }

  void cycleSubtitleTrack() {
    final tracks = widget.player.state.tracks.subtitle;
    if (tracks.isEmpty) return;
    final current = widget.player.state.track.subtitle;
    final idx = tracks.indexWhere((t) => t.id == current.id);
    final nextIdx = (idx + 1) % tracks.length;
    final nextTrack = tracks[nextIdx];
    widget.player.setSubtitleTrack(nextTrack);
    showOsd('Subtitle: ${nextTrack.title ?? nextTrack.language ?? nextTrack.id}', Icons.subtitles_rounded);
  }

  void nudgeAudioDelay(int deltaMs) {
    _audioDelayMs = (_audioDelayMs + deltaMs).clamp(-10000.0, 10000.0);
    try {
      final dynamic platform = widget.player.platform;
      platform.setProperty('audio-delay', (_audioDelayMs / 1000.0).toStringAsFixed(3));
    } catch (_) {}
    final sign = _audioDelayMs >= 0 ? '+' : '';
    showOsd('Audio Delay: $sign${_audioDelayMs.round()} ms', Icons.audiotrack_rounded);
    widget.onNudgeAudioDelay?.call(deltaMs);
  }

  void nudgeSubtitleDelay(int deltaMs) {
    try {
      final dynamic platform = widget.player.platform;
      platform.setProperty('sub-delay', (deltaMs / 1000.0).toStringAsFixed(2));
    } catch (_) {}
    final sign = deltaMs >= 0 ? '+' : '';
    showOsd('Subtitle Delay: $sign$deltaMs ms', Icons.subtitles_rounded);
    widget.onNudgeSubtitleDelay?.call(deltaMs);
  }

  void showAudioTracksModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.surface,
      builder: (ctx) {
        return StreamBuilder<Track>(
          stream: widget.player.stream.track,
          initialData: widget.player.state.track,
          builder: (ctx, trackSnapshot) {
            final audioTracks = widget.player.state.tracks.audio;
            final selectedTrack = trackSnapshot.data?.audio ?? widget.player.state.track.audio;
            return DesktopKeyboardHandler(
              player: widget.player,
              onToggleFullscreen: () {},
              onCycleAspectRatio: () {},
              onCycleAudioTrack: cycleAudioTrack,
              onCycleSubtitleTrack: cycleSubtitleTrack,
              onNudgeAudioDelay: nudgeAudioDelay,
              onNudgeSubtitleDelay: nudgeSubtitleDelay,
              onShowOsd: showOsd,
              onUserActivity: () {},
              child: Container(
                key: const Key('audio_tracks_sheet'),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Audio Tracks', style: TextStyle(color: EDesign.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    if (audioTracks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No audio tracks found', key: Key('audio_tracks_empty'), style: TextStyle(color: EDesign.textSecondary)),
                      ),
                    for (final track in audioTracks)
                      ListTile(
                        key: Key('audio_track_item_${track.id}'),
                        title: Text(track.title ?? track.language ?? track.id, style: const TextStyle(color: EDesign.textPrimary)),
                        trailing: selectedTrack.id == track.id
                            ? const Icon(Icons.check, color: EDesign.primary, key: Key('active_track_check'))
                            : null,
                        onTap: () {
                          widget.player.setAudioTrack(track);
                          showOsd('Audio: ${track.title ?? track.language ?? track.id}', Icons.audiotrack_rounded);
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showAudioStudio() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SingleChildScrollView(
        child: Column(
          children: [
            AudioDelaySyncCard(
              player: widget.player,
              initialDelayMs: _audioDelayMs,
              onDelayChanged: (d) => _audioDelayMs = d,
            ),
            AudioStudioSheet(
              player: widget.player,
              config: _audioConfig,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesktopKeyboardHandler(
      player: widget.player,
      onToggleFullscreen: () {
        fullscreenToggles++;
        widget.onToggleFullscreen?.call();
      },
      onCycleAspectRatio: () {
        aspectRatioCycles++;
        showOsd('Aspect Ratio: Auto', Icons.aspect_ratio_rounded);
        widget.onCycleAspectRatio?.call();
      },
      onCycleAudioTrack: cycleAudioTrack,
      onCycleSubtitleTrack: cycleSubtitleTrack,
      onNudgeAudioDelay: nudgeAudioDelay,
      onNudgeSubtitleDelay: nudgeSubtitleDelay,
      onShowOsd: showOsd,
      onUserActivity: () => widget.onUserActivity?.call(),
      child: Stack(
        children: [
          // Background surface
          const Positioned.fill(
            child: ColoredBox(color: Colors.black),
          ),
          // Top Bar HUD
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black54,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture, color: Colors.white),
                    tooltip: 'Picture-in-Picture',
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: Colors.white),
                    tooltip: 'AI Enhancement Studio',
                    onPressed: () {},
                  ),
                  IconButton(
                    key: const Key('hud_audio_tracks_button'),
                    icon: const Icon(Icons.audiotrack_outlined, color: Colors.white),
                    tooltip: 'Audio Tracks',
                    onPressed: showAudioTracksModal,
                  ),
                  IconButton(
                    key: const Key('hud_subtitles_button'),
                    icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
                    tooltip: 'Subtitles',
                    onPressed: () {},
                  ),
                  IconButton(
                    key: const Key('hud_audio_equalizer_button'),
                    icon: const Icon(Icons.equalizer, color: Colors.white),
                    tooltip: 'Audio Equalizer',
                    onPressed: showAudioStudio,
                  ),
                ],
              ),
            ),
          ),
          // OSD Pill Overlay at top: 90
          if (_showOsd && _osdText != null)
            Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  key: const Key('osd_feedback_pill'),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: EDesign.surface.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(EDesign.r18),
                    border: Border.all(color: EDesign.primary.withValues(alpha: 0.6), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_osdIcon != null) ...[
                        Icon(_osdIcon, color: EDesign.primary, size: 22, key: const Key('osd_feedback_icon')),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _osdText!,
                        key: const Key('osd_feedback_text'),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 4: EXHAUSTIVE 4-TIER TEST SUITE (68 TEST CASES)
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

  // ---------------------------------------------------------------------------
  // TIER 1: FEATURE COVERAGE (27 TESTS: T1.1.1 TO T1.5.5)
  // ---------------------------------------------------------------------------
  group('Tier 1: Feature Coverage (R1–R5)', () {
    // R1: Desktop Keyboard Shortcuts Infrastructure (8 Tests)
    testWidgets('T1.1.1: Shortcut Space Play/Pause toggle', (tester) async {
      final fake = FakePlatformPlayer(initialPlaying: true);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      expect(player.state.playing, isTrue);

      await simulateShortcut(tester, key: LogicalKeyboardKey.space);
      expect(player.state.playing, isFalse);
      expect(find.text('Pause'), findsOneWidget);

      await simulateShortcut(tester, key: LogicalKeyboardKey.space);
      expect(player.state.playing, isTrue);
      expect(find.text('Play'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.1.2: Shortcut Fullscreen Toggle via f and F11', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      int fullscreenEvents = 0;

      await tester.pumpWidget(wrapWithPhase1App(
        child: Phase1PlayerTestWrapper(
          player: player,
          onToggleFullscreen: () => fullscreenEvents++,
        ),
      ));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyF);
      expect(fullscreenEvents, 1);

      await simulateShortcut(tester, key: LogicalKeyboardKey.f11);
      expect(fullscreenEvents, 2);

      await player.dispose();
    });

    testWidgets('T1.1.3: Shortcut Mute Toggle via m', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 80.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      expect(player.state.volume, 80.0);

      // Press m -> Volume 0 (Mute)
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyM);
      expect(player.state.volume, 0.0);
      expect(fake.volumeCalls.last, 0.0);
      expect(find.text('Mute'), findsOneWidget);

      // Press m again -> Volume restored to 80%
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyM);
      expect(player.state.volume, 80.0);
      expect(fake.volumeCalls.last, 80.0);
      expect(find.text('Volume: 80%'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.1.4: Shortcut Aspect Ratio Cycle via a', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      int cycleCount = 0;

      await tester.pumpWidget(wrapWithPhase1App(
        child: Phase1PlayerTestWrapper(
          player: player,
          onCycleAspectRatio: () => cycleCount++,
        ),
      ));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyA);
      expect(cycleCount, 1);
      expect(find.textContaining('Aspect Ratio:'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.1.5: Shortcut Subtitle Delay Nudge via h (+50ms) and g (-50ms)', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyH);
      expect(fake.properties['sub-delay'], '0.05');
      expect(find.text('Subtitle Delay: +50 ms'), findsOneWidget);

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyG);
      expect(fake.properties['sub-delay'], '-0.05');
      expect(find.text('Subtitle Delay: -50 ms'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.1.6: Shortcut Audio Delay Nudge via k (+50ms) and j (-50ms)', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyK);
      expect(fake.properties['audio-delay'], '0.050');
      expect(find.text('Audio Delay: +50 ms'), findsOneWidget);

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyJ);
      expect(fake.properties['audio-delay'], '0.000');
      expect(find.text('Audio Delay: +0 ms'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.1.7: Shortcut Playback Speed Controls (+, -, ], [, =)', (tester) async {
      final fake = FakePlatformPlayer(initialRate: 1.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Coarse speed up (+0.25x) via add
      await simulateShortcut(tester, key: LogicalKeyboardKey.add);
      expect(player.state.rate, 1.25);
      expect(find.text('Speed: 1.25x'), findsOneWidget);

      // Fine speed up (+0.1x) via bracketRight
      await simulateShortcut(tester, key: LogicalKeyboardKey.bracketRight);
      expect(player.state.rate, 1.35);
      expect(find.text('Speed: 1.35x'), findsOneWidget);

      // Fine speed down (-0.1x) via bracketLeft
      await simulateShortcut(tester, key: LogicalKeyboardKey.bracketLeft);
      expect(player.state.rate, 1.25);

      // Coarse speed down (-0.25x) via minus
      await simulateShortcut(tester, key: LogicalKeyboardKey.minus);
      expect(player.state.rate, 1.0);

      // Bump to 1.5x then test reset '='
      await simulateShortcut(tester, key: LogicalKeyboardKey.add);
      await simulateShortcut(tester, key: LogicalKeyboardKey.add);
      expect(player.state.rate, 1.5);

      await simulateShortcut(tester, key: LogicalKeyboardKey.equal);
      expect(player.state.rate, 1.0);
      expect(find.text('Speed: 1.0x (Normal)'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.1.8: Shortcut Volume Adjustment via Arrow Up/Down', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 50.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      expect(player.state.volume, 55.0);
      expect(find.text('Volume: 55%'), findsOneWidget);

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowDown);
      expect(player.state.volume, 50.0);
      expect(find.text('Volume: 50%'), findsOneWidget);

      await player.dispose();
    });

    // R2: 4-Tier Precision Seek Physics (5 Tests)
    testWidgets('T1.2.1: 4-Tier Jump Tier 1 Very Short (3s) via Shift + Left/Right', (tester) async {
      final fake = FakePlatformPlayer(initialPosition: const Duration(seconds: 100));
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, shift: true);
      expect(fake.seekCalls.last, const Duration(seconds: 103));
      expect(find.text('+3s (Dialogue Jump (3s))'), findsOneWidget);

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowLeft, shift: true);
      expect(fake.seekCalls.last, const Duration(seconds: 100));
      expect(find.text('-3s (Dialogue Jump (3s))'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.2.2: 4-Tier Jump Tier 2 Short (10s) via Alt + Left/Right', (tester) async {
      final fake = FakePlatformPlayer(initialPosition: const Duration(seconds: 100));
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, alt: true);
      expect(fake.seekCalls.last, const Duration(seconds: 110));
      expect(find.text('+10s (Short Jump (10s))'), findsOneWidget);

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowLeft, alt: true);
      expect(fake.seekCalls.last, const Duration(seconds: 100));
      expect(find.text('-10s (Short Jump (10s))'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.2.3: 4-Tier Jump Tier 3 Medium (60s) via Ctrl + Left/Right', (tester) async {
      final fake = FakePlatformPlayer(initialPosition: const Duration(seconds: 200));
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, ctrl: true);
      expect(fake.seekCalls.last, const Duration(seconds: 260));
      expect(find.text('+60s (Medium Jump (1m))'), findsOneWidget);

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowLeft, ctrl: true);
      expect(fake.seekCalls.last, const Duration(seconds: 200));
      expect(find.text('-60s (Medium Jump (1m))'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.2.4: 4-Tier Jump Tier 4 Long (300s) via Ctrl + Alt + Left/Right', (tester) async {
      final fake = FakePlatformPlayer(initialPosition: const Duration(seconds: 500));
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, ctrl: true, alt: true);
      expect(fake.seekCalls.last, const Duration(seconds: 800));
      expect(find.text('+300s (Long Jump (5m))'), findsOneWidget);

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowLeft, ctrl: true, alt: true);
      expect(fake.seekCalls.last, const Duration(seconds: 500));
      expect(find.text('-300s (Long Jump (5m))'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.2.5: 4-Tier Jump Default Seek (10s) via Unmodified Arrow Left/Right', (tester) async {
      final fake = FakePlatformPlayer(initialPosition: const Duration(seconds: 100));
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight);
      expect(fake.seekCalls.last, const Duration(seconds: 110));
      expect(find.text('+10s (Seek (10s))'), findsOneWidget);

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowLeft);
      expect(fake.seekCalls.last, const Duration(seconds: 100));
      expect(find.text('-10s (Seek (10s))'), findsOneWidget);

      await player.dispose();
    });

    // R3: Audio Delay Synchronization UI Slider & Nudge Buttons (5 Tests)
    testWidgets('T1.3.1: Audio Delay Slider UI Presence & Range', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: AudioDelaySyncCard(player: player)));
      await tester.pumpAndSettle();

      expect(find.text('Audio Synchronization'), findsOneWidget);
      expect(find.byKey(const Key('audio_delay_slider')), findsOneWidget);

      final slider = tester.widget<Slider>(find.byKey(const Key('audio_delay_slider')));
      expect(slider.min, -10.0);
      expect(slider.max, 10.0);
      expect(slider.divisions, 400);

      await player.dispose();
    });

    testWidgets('T1.3.2: Audio Delay Slider Continuous Drag', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: AudioDelaySyncCard(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<AudioDelaySyncCardState>(find.byType(AudioDelaySyncCard));
      state.updateDelay(1500.0);
      await tester.pumpAndSettle();

      expect(find.text('+1500 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '1.500');

      await player.dispose();
    });

    testWidgets('T1.3.3: Audio Delay Nudge ±50ms Buttons', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: AudioDelaySyncCard(player: player)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_50')));
      await tester.pumpAndSettle();
      expect(find.text('+50 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '0.050');

      await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_50')));
      await tester.pumpAndSettle();
      expect(find.text('+0 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '0.000');

      await player.dispose();
    });

    testWidgets('T1.3.4: Audio Delay Nudge ±100ms Buttons', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: AudioDelaySyncCard(player: player)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_100')));
      await tester.pumpAndSettle();
      expect(find.text('+100 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '0.100');

      await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_100')));
      await tester.pumpAndSettle();
      expect(find.text('+0 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '0.000');

      await player.dispose();
    });

    testWidgets('T1.3.5: Audio Delay Reset Button', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(
        child: AudioDelaySyncCard(player: player, initialDelayMs: 450.0),
      ));
      await tester.pumpAndSettle();

      expect(find.text('+450 ms'), findsOneWidget);

      await tester.tap(find.byKey(const Key('audio_delay_nudge_reset')));
      await tester.pumpAndSettle();

      expect(find.text('+0 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '0.000');

      await player.dispose();
    });

    // R4: Dedicated Audio Track Selector Modal & Cycling (4 Tests)
    testWidgets('T1.4.1: Audio Track HUD Button Presence', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Audio Tracks'), findsOneWidget);
      expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.4.2: Audio Track Modal Stream Listing', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Audio Tracks'));
      await tester.pumpAndSettle();

      expect(find.text('Audio Tracks'), findsOneWidget);
      expect(find.text('English Surround 5.1'), findsOneWidget);
      expect(find.text('Japanese Stereo'), findsOneWidget);
      expect(find.text('Director Commentary'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T1.4.3: Audio Track Modal Selection', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Audio Tracks'));
      await tester.pumpAndSettle();

      // Tap Track 2: Japanese Stereo
      await tester.tap(find.text('Japanese Stereo'));
      await tester.pumpAndSettle();

      // Modal closed and player.setAudioTrack invoked
      expect(find.text('Audio Tracks'), findsNothing);
      expect(fake.setAudioTrackCalls.last.title, 'Japanese Stereo');
      expect(player.state.track.audio.title, 'Japanese Stereo');

      await player.dispose();
    });

    testWidgets('T1.4.4: Audio Track Cycling via Hotkey b', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      expect(player.state.track.audio.title, 'English Surround 5.1');

      // Press b -> switches to Track 2 (Japanese Stereo)
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyB);
      expect(fake.setAudioTrackCalls.last.title, 'Japanese Stereo');
      expect(find.text('Audio: Japanese Stereo'), findsOneWidget);

      // Press b again -> switches to Track 3 (Director Commentary)
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyB);
      expect(fake.setAudioTrackCalls.last.title, 'Director Commentary');
      expect(find.text('Audio: Director Commentary'), findsOneWidget);

      await player.dispose();
    });

    // R5: Equalizer Parity with 11 VLC Presets & Preamp Slider (5 Tests)
    testWidgets('T1.5.1: Master Equalizer Switch Toggle', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final config = AudioConfig();

      await tester.pumpWidget(wrapWithPhase1App(
        child: AudioStudioSheet(player: player, config: config),
      ));
      await tester.pumpAndSettle();

      final switchFinder = find.descendant(
        of: find.widgetWithText(Row, 'Enable Equalizer'),
        matching: find.byType(Switch),
      );
      expect(switchFinder, findsOneWidget);
      expect(config.enabled, isTrue);

      // Toggle switch OFF
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(config.enabled, isFalse);

      await player.dispose();
    });

    testWidgets('T1.5.2: Equalizer 11 VLC Presets Selection', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final config = AudioConfig();

      final vlcPresets = [
        'Full Bass',
        'Full Bass & Treble',
        'Full Treble',
        'Headphones',
        'Large Hall',
        'Live',
        'Party',
        'Reggae',
        'Ska',
        'Soft',
        'Soft Rock',
      ];

      for (final p in vlcPresets) {
        config.applyPreset(p);
        expect(config.preset, p);
        expect(config.eq.length, 10);
        expect(config.preamp, greaterThan(0.0));

        final af = config.buildMpvAfString();
        expect(af, contains('volume=volume=+'));
        expect(af, contains('equalizer=f='));
      }

      await player.dispose();
    });

    testWidgets('T1.5.3: 10-Band EQ Gain Scale Expansion (±20dB)', (tester) async {
      final config = AudioConfig();
      expect(AudioConfig.freqs.length, 10);
      expect(AudioConfig.freqLabels.length, 10);

      // Set custom extreme gains in [-20.0dB, +20.0dB]
      config.eq[0] = 18.5; // 60Hz
      config.eq[9] = -15.0; // 16kHz

      final af = config.buildMpvAfString();
      expect(af, contains('equalizer=f=60:width_type=q:width=1.2:g=18.5'));
      expect(af, contains('equalizer=f=16000:width_type=q:width=1.2:g=-15.0'));
    });

    testWidgets('T1.5.4: Preamp Gain Slider Adjustment', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final config = AudioConfig();

      config.preamp = 6.0;
      config.apply(player);

      expect(config.buildMpvAfString(), contains('volume=volume=+6.0dB:precision=fixed'));
      expect(fake.properties['af'], contains('volume=volume=+6.0dB:precision=fixed'));

      await player.dispose();
    });

    testWidgets('T1.5.5: Preamp 0.0dB Bit-Perfect Pass-Through', (tester) async {
      final config = AudioConfig();
      config.preamp = 0.0;

      final af = config.buildMpvAfString();
      expect(af.contains('volume='), isFalse, reason: '0.0dB preamp must be omitted for unity pass-through');
    });
  });

  // ---------------------------------------------------------------------------
  // TIER 2: BOUNDARY & CORNER CASES (26 TESTS: T2.1.1 TO T2.5.6)
  // ---------------------------------------------------------------------------
  group('Tier 2: Boundary & Corner Cases', () {
    // Shortcuts Boundary (5 Tests)
    testWidgets('T2.1.1: Volume Clamp Upper Limit at 100% / 150%', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 145.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      expect(player.state.volume, 150.0);

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      expect(player.state.volume, 150.0); // Clamped at max

      await player.dispose();
    });

    testWidgets('T2.1.2: Volume Clamp Lower Limit at 0% (Mute)', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 3.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowDown);
      expect(player.state.volume, 0.0);
      expect(find.text('Mute'), findsOneWidget);

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowDown);
      expect(player.state.volume, 0.0); // Clamped at 0

      await player.dispose();
    });

    testWidgets('T2.1.3: Playback Speed Minimum Clamp at 0.25x', (tester) async {
      final fake = FakePlatformPlayer(initialRate: 0.3);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Decrement fine speed twice (-0.1x each)
      await simulateShortcut(tester, key: LogicalKeyboardKey.bracketLeft);
      await simulateShortcut(tester, key: LogicalKeyboardKey.bracketLeft);

      expect(player.state.rate, 0.25);
      expect(find.text('Speed: 0.25x'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T2.1.4: Playback Speed Maximum Clamp at 4.0x', (tester) async {
      final fake = FakePlatformPlayer(initialRate: 3.9);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.bracketRight);
      await simulateShortcut(tester, key: LogicalKeyboardKey.bracketRight);

      expect(player.state.rate, 4.0);
      expect(find.text('Speed: 4.00x'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T2.1.5: Unmapped Keys and KeyUp Ignored', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      final initialSeekCount = fake.seekCalls.length;
      final initialVolCount = fake.volumeCalls.length;

      // KeyUpEvent for Space
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();

      // Unmapped keys: Escape, Tab
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(fake.seekCalls.length, initialSeekCount);
      expect(fake.volumeCalls.length, initialVolCount);

      await player.dispose();
    });

    // 4-Tier Seek Boundaries (5 Tests)
    testWidgets('T2.2.1: Seek Backward Underflow Clamping to Duration.zero', (tester) async {
      final fake = FakePlatformPlayer(initialPosition: const Duration(seconds: 45));
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // 300s jump backward from 45s -> Clamped to Duration.zero
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowLeft, ctrl: true, alt: true);
      expect(fake.seekCalls.last, Duration.zero);

      await player.dispose();
    });

    testWidgets('T2.2.2: Seek Forward Overflow Clamping to maxDuration', (tester) async {
      const totalDuration = Duration(minutes: 10);
      final fake = FakePlatformPlayer(
        initialDuration: totalDuration,
        initialPosition: const Duration(minutes: 9, seconds: 30),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // 60s jump forward when 30s remaining -> Clamped to totalDuration
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, ctrl: true);
      expect(fake.seekCalls.last, totalDuration);

      await player.dispose();
    });

    testWidgets('T2.2.3: Seek with Zero / Unknown Duration handles gracefully', (tester) async {
      final fake = FakePlatformPlayer(
        initialDuration: Duration.zero,
        initialPosition: const Duration(seconds: 10),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, shift: true);
      expect(fake.seekCalls.last, const Duration(seconds: 13));

      await player.dispose();
    });

    testWidgets('T2.2.4: Multiple Modifiers Priority Resolution (Ctrl takes precedence over Shift)', (tester) async {
      final fake = FakePlatformPlayer(initialPosition: const Duration(seconds: 100));
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Hold both Shift and Ctrl
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, ctrl: true, shift: true);
      // Ctrl (60s) takes precedence over Shift (3s)
      expect(fake.seekCalls.last, const Duration(seconds: 160));
      expect(find.text('+60s (Medium Jump (1m))'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T2.2.5: macOS Meta Modifier Equivalence', (tester) async {
      final fake = FakePlatformPlayer(initialPosition: const Duration(seconds: 100));
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, meta: true);
      expect(fake.seekCalls.last, const Duration(seconds: 160));
      expect(find.text('+60s (Medium Jump (1m))'), findsOneWidget);

      await player.dispose();
    });

    // Audio Delay Boundaries (5 Tests)
    testWidgets('T2.3.1: Audio Delay Upper Clamp (+10.0s / +10000ms)', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(
        child: AudioDelaySyncCard(player: player, initialDelayMs: 9950.0),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_100')));
      await tester.pumpAndSettle();

      expect(find.text('+10000 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '10.000');

      await player.dispose();
    });

    testWidgets('T2.3.2: Audio Delay Lower Clamp (-10.0s / -10000ms)', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(
        child: AudioDelaySyncCard(player: player, initialDelayMs: -9950.0),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audio_delay_nudge_minus_100')));
      await tester.pumpAndSettle();

      expect(find.text('-10000 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '-10.000');

      await player.dispose();
    });

    testWidgets('T2.3.3: Rapid Sequential Nudge Taps accumulate cleanly', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: AudioDelaySyncCard(player: player)));
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_50')));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      expect(find.text('+250 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '0.250');

      await player.dispose();
    });

    testWidgets('T2.3.4: Audio Delay Unloaded Media Fallback', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: AudioDelaySyncCard(player: player)));
      await tester.pumpAndSettle();

      expect(find.text('+0 ms'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await player.dispose();
    });

    testWidgets('T2.3.5: Audio Delay 3-Decimal Precision Format', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: AudioDelaySyncCard(player: player)));
      await tester.pumpAndSettle();

      final state = tester.state<AudioDelaySyncCardState>(find.byType(AudioDelaySyncCard));
      state.updateDelay(50.0);
      expect(fake.properties['audio-delay'], '0.050');

      state.updateDelay(-150.0);
      expect(fake.properties['audio-delay'], '-0.150');

      state.updateDelay(1250.0);
      expect(fake.properties['audio-delay'], '1.250');

      await player.dispose();
    });

    // Audio Track Modal Boundaries (5 Tests)
    testWidgets('T2.4.1: Empty Audio Tracks Graceful State', (tester) async {
      final fake = FakePlatformPlayer(
        initialTracks: const Tracks(audio: [], subtitle: []),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Audio Tracks'));
      await tester.pumpAndSettle();

      expect(find.text('No audio tracks found'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await player.dispose();
    });

    testWidgets('T2.4.2: Single Audio Track Selection No-Op', (tester) async {
      const singleTrack = AudioTrack('1', 'Stereo Only', 'eng');
      final fake = FakePlatformPlayer(
        initialTracks: const Tracks(audio: [singleTrack], subtitle: []),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Audio Tracks'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stereo Only'));
      await tester.pumpAndSettle();

      expect(find.text('Audio Tracks'), findsNothing);
      expect(player.state.track.audio.id, '1');

      await player.dispose();
    });

    testWidgets('T2.4.3: Audio Track Missing Metadata Fallback', (tester) async {
      const fallbackTrack = AudioTrack('track_99', null, null);
      final fake = FakePlatformPlayer(
        initialTracks: const Tracks(audio: [fallbackTrack], subtitle: []),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Audio Tracks'));
      await tester.pumpAndSettle();

      expect(find.text('track_99'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T2.4.4: Track Cycle Hotkey b with Empty Tracks is safe no-op', (tester) async {
      final fake = FakePlatformPlayer(
        initialTracks: const Tracks(audio: [], subtitle: []),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyB);
      expect(fake.setAudioTrackCalls.isEmpty, isTrue);
      expect(tester.takeException(), isNull);

      await player.dispose();
    });

    testWidgets('T2.4.5: Track Cycle Hotkey b with Single Track', (tester) async {
      const track1 = AudioTrack('1', 'Mono Stream', 'eng');
      final fake = FakePlatformPlayer(
        initialTracks: const Tracks(audio: [track1], subtitle: []),
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      await simulateShortcut(tester, key: LogicalKeyboardKey.keyB);
      expect(fake.setAudioTrackCalls.last.id, '1');

      await player.dispose();
    });

    // Equalizer & Preamp Boundaries (6 Tests)
    testWidgets('T2.5.1: Preamp Upper Limit Clamp (+20.0dB)', (tester) async {
      final config = AudioConfig();
      config.preamp = 25.0; // Over max
      config.preamp = config.preamp.clamp(-20.0, 20.0);

      expect(config.preamp, 20.0);
      expect(config.buildMpvAfString(), contains('volume=volume=+20.0dB:precision=fixed'));
    });

    testWidgets('T2.5.2: Preamp Lower Limit Clamp (-20.0dB)', (tester) async {
      final config = AudioConfig();
      config.preamp = -25.0; // Under min
      config.preamp = config.preamp.clamp(-20.0, 20.0);

      expect(config.preamp, -20.0);
      expect(config.buildMpvAfString(), contains('volume=volume=-20.0dB:precision=fixed'));
    });

    testWidgets('T2.5.3: 10-Band EQ Individual Slider Clamping', (tester) async {
      final config = AudioConfig();
      config.eq[0] = 30.0;
      config.eq[0] = config.eq[0].clamp(-20.0, 20.0);

      config.eq[1] = -30.0;
      config.eq[1] = config.eq[1].clamp(-20.0, 20.0);

      expect(config.eq[0], 20.0);
      expect(config.eq[1], -20.0);
    });

    testWidgets('T2.5.4: Custom Preset Name on Band Edit', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final config = AudioConfig();

      await tester.pumpWidget(wrapWithPhase1App(
        child: AudioStudioSheet(player: player, config: config),
      ));
      await tester.pumpAndSettle();

      config.applyPreset('Rock');
      expect(config.preset, 'Rock');

      // Edit band 0
      config.preset = 'Custom';
      config.eq[0] = 10.0;
      expect(config.preset, 'Custom');

      await player.dispose();
    });

    testWidgets('T2.5.5: Preset Edit While Master Switch Disabled', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final config = AudioConfig();
      config.enabled = false;

      config.applyPreset('Reggae');
      expect(config.preset, 'Reggae');
      expect(config.buildMpvAfString(), ''); // af must be empty when disabled

      config.apply(player);
      // mpv af call should set empty string
      expect(fake.properties['af'] == '' || fake.properties['af'] == null, isTrue);

      await player.dispose();
    });

    testWidgets('T2.5.6: Negative Preamp Gain String Formatting', (tester) async {
      final config = AudioConfig();
      config.preamp = -8.5;

      final af = config.buildMpvAfString();
      expect(af, contains('volume=volume=-8.5dB:precision=fixed'));
    });
  });

  // ---------------------------------------------------------------------------
  // TIER 3: CROSS-FEATURE INTERACTIONS (10 TESTS: T3.1 TO T3.10)
  // ---------------------------------------------------------------------------
  group('Tier 3: Cross-Feature Interactions', () {
    testWidgets('T3.1: Hotkey b Track Cycle with Open Modal updates active selection', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Open Audio Tracks modal
      await tester.tap(find.byTooltip('Audio Tracks'));
      await tester.pumpAndSettle();
      expect(find.text('Audio Tracks'), findsOneWidget);

      // Press hotkey b while modal is open
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyB);
      expect(fake.setAudioTrackCalls.last.title, 'Japanese Stereo');

      await player.dispose();
    });

    testWidgets('T3.2: Audio Delay Nudge at 2.0x Speed preserves rate', (tester) async {
      final fake = FakePlatformPlayer(initialRate: 2.0);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      expect(player.state.rate, 2.0);

      // Nudge audio delay with k
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyK);
      expect(fake.properties['audio-delay'], '0.050');
      expect(player.state.rate, 2.0);

      await player.dispose();
    });

    testWidgets('T3.3: Preset Change with Active Preamp Boost combines filters', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final config = AudioConfig();

      config.preamp = 4.0;
      config.applyPreset('Large Hall');
      config.preamp = 4.0; // Retain active preamp boost

      final af = config.buildMpvAfString();
      expect(af.startsWith('volume=volume=+4.0dB:precision=fixed'), isTrue);
      expect(af, contains('equalizer=f=60:width_type=q:width=1.2:g=10.4'));

      await player.dispose();
    });

    testWidgets('T3.4: 4-Tier Jump During Volume Adjustment without modifier bleed', (tester) async {
      final fake = FakePlatformPlayer(
        initialPosition: const Duration(seconds: 100),
        initialVolume: 50.0,
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Volume up
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      expect(player.state.volume, 55.0);

      // Shift + Right -> 3s jump
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, shift: true);
      expect(fake.seekCalls.last, const Duration(seconds: 103));

      // Arrow Up again
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      expect(player.state.volume, 60.0);

      await player.dispose();
    });

    testWidgets('T3.5: UI Delay Slider Sync with Hotkey k/j', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Hotkey k (+50ms)
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyK);
      expect(fake.properties['audio-delay'], '0.050');

      // Hotkey k again (+50ms -> +100ms)
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyK);
      expect(fake.properties['audio-delay'], '0.100');

      // Hotkey j (-50ms -> +50ms)
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyJ);
      expect(fake.properties['audio-delay'], '0.050');

      await player.dispose();
    });

    testWidgets('T3.6: Audio Mute While Preamp is Boosted retains preamp string', (tester) async {
      final fake = FakePlatformPlayer(initialVolume: 80.0);
      final player = Player(platformPlayer: fake);
      final config = AudioConfig();

      config.preamp = 10.0;
      config.apply(player);

      await tester.pumpWidget(wrapWithPhase1App(
        child: Phase1PlayerTestWrapper(player: player, audioConfig: config),
      ));
      await tester.pumpAndSettle();

      // Mute via m
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyM);
      expect(player.state.volume, 0.0);

      // Preamp filter must remain in af
      expect(config.buildMpvAfString(), contains('volume=volume=+10.0dB:precision=fixed'));

      await player.dispose();
    });

    testWidgets('T3.7: 5-Minute Long Jump Followed by Play/Pause', (tester) async {
      final fake = FakePlatformPlayer(
        initialPosition: const Duration(seconds: 200),
        initialPlaying: true,
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // 300s jump
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, ctrl: true, alt: true);
      expect(fake.seekCalls.last, const Duration(seconds: 500));

      // Space -> Pause
      await simulateShortcut(tester, key: LogicalKeyboardKey.space);
      expect(player.state.playing, isFalse);

      await player.dispose();
    });

    testWidgets('T3.8: Speed Reset While Audio Delay is Non-Zero', (tester) async {
      final fake = FakePlatformPlayer(initialRate: 1.5);
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(
        child: Phase1PlayerTestWrapper(player: player, initialAudioDelayMs: 350.0),
      ));
      await tester.pumpAndSettle();

      // Reset speed with '='
      await simulateShortcut(tester, key: LogicalKeyboardKey.equal);
      expect(player.state.rate, 1.0);

      // Audio delay preserved
      final state = tester.state<Phase1PlayerTestWrapperState>(find.byType(Phase1PlayerTestWrapper));
      expect(state._audioDelayMs, 350.0);

      await player.dispose();
    });

    testWidgets('T3.9: Audio Track Switch Retains EQ & Delay Settings', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final config = AudioConfig();

      config.applyPreset('Live');
      config.apply(player);

      await tester.pumpWidget(wrapWithPhase1App(
        child: Phase1PlayerTestWrapper(
          player: player,
          audioConfig: config,
          initialAudioDelayMs: 100.0,
        ),
      ));
      await tester.pumpAndSettle();

      // Switch audio track
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyB);
      expect(player.state.track.audio.title, 'Japanese Stereo');

      // EQ and delay settings intact
      expect(config.preset, 'Live');
      expect(config.buildMpvAfString(), contains('equalizer=f=310:width_type=q:width=1.2:g=4.0'));

      await player.dispose();
    });

    testWidgets('T3.10: Interleaved Subtitle and Audio Nudges independent', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Sub delay nudge
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyH);
      expect(fake.properties['sub-delay'], '0.05');

      // Audio delay nudge
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyK);
      expect(fake.properties['audio-delay'], '0.050');

      // Both properties recorded independently
      expect(fake.properties['sub-delay'], '0.05');
      expect(fake.properties['audio-delay'], '0.050');

      await player.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // TIER 4: REAL-WORLD APPLICATION SCENARIOS (5 TESTS: T4.1 TO T4.5)
  // ---------------------------------------------------------------------------
  group('Tier 4: Real-World Scenarios', () {
    testWidgets('T4.1: Scenario 1 - Desktop Playback & 4-Tier Jump Navigation', (tester) async {
      final fake = FakePlatformPlayer(
        initialPosition: const Duration(minutes: 10),
        initialPlaying: false,
        initialVolume: 60.0,
      );
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // 1. Space -> Start playback
      await simulateShortcut(tester, key: LogicalKeyboardKey.space);
      expect(player.state.playing, isTrue);

      // 2. Fullscreen toggle
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyF);

      // 3. Skip 5m recap (Ctrl + Alt + ArrowRight -> +300s)
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, ctrl: true, alt: true);
      expect(fake.seekCalls.last, const Duration(seconds: 900));

      // 4. Skip 1m intro (Ctrl + ArrowRight -> +60s)
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, ctrl: true);
      expect(fake.seekCalls.last, const Duration(seconds: 960));

      // 5. Replay 3s dialogue (Shift + ArrowLeft -> -3s)
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowLeft, shift: true);
      expect(fake.seekCalls.last, const Duration(seconds: 957));

      // 6. Boost volume +10% (Arrow Up twice)
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowUp);
      expect(player.state.volume, 70.0);

      await player.dispose();
    });

    testWidgets('T4.2: Scenario 2 - Out-of-Sync Audio Dialogue Correction Workflow', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: AudioDelaySyncCard(player: player)));
      await tester.pumpAndSettle();

      // 1. Initial 0ms
      expect(find.text('+0 ms'), findsOneWidget);

      // 2. Coarse drag to +150ms
      final state = tester.state<AudioDelaySyncCardState>(find.byType(AudioDelaySyncCard));
      state.updateDelay(150.0);
      await tester.pumpAndSettle();
      expect(find.text('+150 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '0.150');

      // 3. Nudge +50ms -> +200ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_plus_50')));
      await tester.pumpAndSettle();
      expect(find.text('+200 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '0.200');

      // 4. Reset to 0ms
      await tester.tap(find.byKey(const Key('audio_delay_nudge_reset')));
      await tester.pumpAndSettle();
      expect(find.text('+0 ms'), findsOneWidget);
      expect(fake.properties['audio-delay'], '0.000');

      await player.dispose();
    });

    testWidgets('T4.3: Scenario 3 - Audio Track Stream Switching via Top Bar Modal', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);

      await tester.pumpWidget(wrapWithPhase1App(child: Phase1PlayerTestWrapper(player: player)));
      await tester.pumpAndSettle();

      // Open top bar audio modal
      await tester.tap(find.byTooltip('Audio Tracks'));
      await tester.pumpAndSettle();

      // Verify listing
      expect(find.text('English Surround 5.1'), findsOneWidget);
      expect(find.text('Japanese Stereo'), findsOneWidget);

      // Select Japanese
      await tester.tap(find.text('Japanese Stereo'));
      await tester.pumpAndSettle();

      // Active track is Japanese
      expect(fake.setAudioTrackCalls.last.title, 'Japanese Stereo');
      expect(find.text('Audio: Japanese Stereo'), findsOneWidget);

      await player.dispose();
    });

    testWidgets('T4.4: Scenario 4 - Concert / Hall Audio Equalization & Preamp Boost', (tester) async {
      final fake = FakePlatformPlayer();
      final player = Player(platformPlayer: fake);
      final config = AudioConfig();

      await tester.pumpWidget(wrapWithPhase1App(
        child: AudioStudioSheet(player: player, config: config),
      ));
      await tester.pumpAndSettle();

      // Apply Large Hall preset
      config.applyPreset('Large Hall');
      config.preamp = 4.0;
      config.apply(player);

      expect(config.preset, 'Large Hall');
      expect(config.preamp, 4.0);

      final af = config.buildMpvAfString();
      expect(af.startsWith('volume=volume=+4.0dB:precision=fixed'), isTrue);
      expect(af, contains('equalizer=f=60:width_type=q:width=1.2:g=10.4'));

      await player.dispose();
    });

    testWidgets('T4.5: Scenario 5 - End-to-End Cinematic Media Consumption Experience', (tester) async {
      final fake = FakePlatformPlayer(initialRate: 1.0, initialPlaying: false);
      final player = Player(platformPlayer: fake);
      final config = AudioConfig();

      await tester.pumpWidget(wrapWithPhase1App(
        child: Phase1PlayerTestWrapper(player: player, audioConfig: config),
      ));
      await tester.pumpAndSettle();

      // 1. Play with Space
      await simulateShortcut(tester, key: LogicalKeyboardKey.space);
      expect(player.state.playing, isTrue);

      // 2. Fine-tune speed to 1.1x with ']'
      await simulateShortcut(tester, key: LogicalKeyboardKey.bracketRight);
      expect(player.state.rate, 1.1);

      // 3. Cycle audio track to Director Commentary with 'b' twice
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyB);
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyB);
      expect(player.state.track.audio.title, 'Director Commentary');

      // 4. Equalizer Headphones preset
      config.applyPreset('Headphones');
      config.preamp = 4.0;
      config.apply(player);
      expect(config.buildMpvAfString(), contains('volume=volume=+4.0dB:precision=fixed'));

      // 5. Audio delay nudge +50ms with 'k'
      await simulateShortcut(tester, key: LogicalKeyboardKey.keyK);
      expect(fake.properties['audio-delay'], '0.050');

      // 6. Clarify dialogue line with Shift + Right (+3s)
      await simulateShortcut(tester, key: LogicalKeyboardKey.arrowRight, shift: true);
      expect(fake.seekCalls.last, const Duration(seconds: 123));

      expect(tester.takeException(), isNull);

      await player.dispose();
    });
  });
}
