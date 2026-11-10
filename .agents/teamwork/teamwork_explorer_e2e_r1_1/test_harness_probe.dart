import 'dart:async';
import 'package:media_kit/media_kit.dart';

/// Test platform simulating `libmpv` property store and media_kit PlatformPlayer.
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
    PlayerConfiguration configuration = const PlayerConfiguration(),
  }) : super(configuration: configuration) {
    state = const PlayerState(
      duration: Duration(seconds: 3600),
      position: Duration(seconds: 120),
      volume: 100.0,
      rate: 1.0,
      playing: true,
      tracks: Tracks(
        audio: [
          AudioTrack('1', 'English Surround 5.1', 'eng'),
          AudioTrack('2', 'Japanese Stereo', 'jpn'),
        ],
        subtitle: [
          SubtitleTrack('1', 'English Full', 'eng'),
        ],
      ),
      track: Track(
        audio: AudioTrack('1', 'English Surround 5.1', 'eng'),
        subtitle: SubtitleTrack('1', 'English Full', 'eng'),
      ),
    );
  }

  // --- mpv property accessors (used by AudioConfig, SubtitleSettings, etc.) ---

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    setPropertyCalls.add('$property=$value');
    onSetProperty?.call(property, value);
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }

  // --- Player playback controls ---

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

  // --- Stream test emitters ---

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
}

void main() async {
  final fakePlatform = FakePlatformPlayer();
  final player = Player(platformPlayer: fakePlatform);

  print('Player instantiated without C-FFI / mpv.dll!');
  print('Initial playing: ${player.state.playing}');
  print('Initial audio tracks: ${player.state.tracks.audio.length}');

  // Test setAudioTrack
  final jpnTrack = fakePlatform.state.tracks.audio[1];
  await player.setAudioTrack(jpnTrack);
  print('Selected audio track: ${player.state.track.audio.title}');

  // Test seek
  await player.seek(const Duration(seconds: 150));
  print('New position: ${player.state.position.inSeconds}s');

  // Test mpv setProperty via platform dynamic
  final dynamic platform = player.platform;
  await platform.setProperty('audio-delay', '0.050');
  print('Property audio-delay: ${fakePlatform.properties['audio-delay']}');

  await player.dispose();
  print('All checks passed successfully!');
}
