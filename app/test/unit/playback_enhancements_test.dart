import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/player/ui/playback_enhancements.dart';

class FakeMpvPlatformPlayer extends PlatformPlayer {
  final Map<String, String> properties = {};
  final List<String> propertyCalls = [];
  final List<List<String>> commandCalls = [];
  final List<Duration> seekCalls = [];

  FakeMpvPlatformPlayer({super.configuration = const PlayerConfiguration()});

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
    propertyCalls.add('$property=$value');
  }

  Future<dynamic> getProperty(String property) async {
    return properties[property];
  }

  Future<void> command(List<String> command, {bool waitForInitialization = true}) async {
    commandCalls.add(List<String>.from(command));
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ABRepeatController Unit Tests', () {
    test('Initial state is off with null points', () {
      final controller = ABRepeatController();
      expect(controller.state, equals(ABRepeatState.off));
      expect(controller.pointA, isNull);
      expect(controller.pointB, isNull);
      expect(controller.isLoopSeeking, isFalse);
      expect(controller.seekCount, equals(0));
    });

    test('Cycle 1 sets Point A', () {
      final controller = ABRepeatController();
      String? msg;
      final ok = controller.cycle(
        const Duration(seconds: 10),
        onMessage: (m) => msg = m,
      );
      expect(ok, isTrue);
      expect(controller.state, equals(ABRepeatState.pointA));
      expect(controller.pointA, equals(const Duration(seconds: 10)));
      expect(controller.pointB, isNull);
      expect(msg, contains('Point A set'));
    });

    test('Cycle 2 with invalid Point B <= Point A is rejected', () {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 20));

      String? msg;
      final ok = controller.cycle(
        const Duration(seconds: 15),
        onMessage: (m) => msg = m,
      );
      expect(ok, isFalse);
      expect(controller.state, equals(ABRepeatState.pointA));
      expect(msg, contains('Point B cannot be earlier'));
    });

    test('Cycle 2 with valid Point B activates looping', () {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 10));

      String? msg;
      final ok = controller.cycle(
        const Duration(seconds: 25),
        onMessage: (m) => msg = m,
      );
      expect(ok, isTrue);
      expect(controller.state, equals(ABRepeatState.looping));
      expect(controller.pointA, equals(const Duration(seconds: 10)));
      expect(controller.pointB, equals(const Duration(seconds: 25)));
      expect(msg, contains('Active'));
    });

    test('Cycle 3 clears loop and resets to off', () {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 10));
      controller.cycle(const Duration(seconds: 25));

      String? msg;
      final ok = controller.cycle(
        const Duration(seconds: 30),
        onMessage: (m) => msg = m,
      );
      expect(ok, isTrue);
      expect(controller.state, equals(ABRepeatState.off));
      expect(controller.pointA, isNull);
      expect(controller.pointB, isNull);
      expect(msg, contains('Cleared'));
    });

    test('checkPosition triggers seek on reaching Point B with debounce', () async {
      final controller = ABRepeatController();
      controller.cycle(const Duration(seconds: 5));
      controller.cycle(const Duration(seconds: 15));

      Duration? target;
      await controller.checkPosition(
        const Duration(seconds: 15),
        onSeek: (t) async => target = t,
      );

      expect(target, equals(const Duration(seconds: 5)));
      expect(controller.seekCount, equals(1));
      expect(controller.isLoopSeeking, isTrue);

      // Subsequent check throttled
      target = null;
      await controller.checkPosition(
        const Duration(milliseconds: 15100),
        onSeek: (t) async => target = t,
      );
      expect(target, isNull);
      expect(controller.seekCount, equals(1));
    });
  });

  group('AspectCropController Unit Tests', () {
    test('Default preset is Reset', () {
      final fake = FakeMpvPlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      expect(controller.current, equals(CropPreset.reset));
      expect(controller.currentIndex, equals(5));
      player.dispose();
    });

    test('Cycle next walks through all presets and sets vf property', () async {
      final fake = FakeMpvPlatformPlayer();
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
      player.dispose();
    });

    test('setPreset sets specific crop filter', () async {
      final fake = FakeMpvPlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = AspectCropController(player);

      await controller.setPreset(CropPreset.ratio2_35_1);
      expect(controller.current, equals(CropPreset.ratio2_35_1));
      expect(fake.properties['vf'], equals('crop=ih*2.35:ih'));
      player.dispose();
    });
  });

  group('BufferCachingSettingsController Unit Tests', () {
    test('Default values: 1000ms network caching, 32MB demuxer cache', () {
      final controller = BufferCachingSettingsController();
      expect(controller.networkCachingMs, equals(1000));
      expect(controller.demuxerCacheMb, equals(32));
    });

    test('setNetworkCachingMs clamps values between 500 and 10000ms and updates mpv', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakeMpvPlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = BufferCachingSettingsController();

      await controller.setNetworkCachingMs(200, prefs, player: player);
      expect(controller.networkCachingMs, equals(500));
      expect(fake.properties['cache-secs'], equals('0.50'));

      await controller.setNetworkCachingMs(15000, prefs, player: player);
      expect(controller.networkCachingMs, equals(10000));
      expect(fake.properties['cache-secs'], equals('10.00'));

      await controller.setNetworkCachingMs(2500, prefs, player: player);
      expect(controller.networkCachingMs, equals(2500));
      expect(fake.properties['cache-secs'], equals('2.50'));
      player.dispose();
    });

    test('setDemuxerCacheMb selects valid sizes and updates demuxer byte limits', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakeMpvPlatformPlayer();
      final player = Player(platformPlayer: fake);
      final controller = BufferCachingSettingsController();

      await controller.setDemuxerCacheMb(64, prefs, player: player);
      expect(controller.demuxerCacheMb, equals(64));
      final expectedBytes = (64 * 1024 * 1024).toString();
      expect(fake.properties['demuxer-max-bytes'], equals(expectedBytes));
      expect(fake.properties['demuxer-max-back-bytes'], equals(expectedBytes));
      player.dispose();
    });

    test('loadFromPrefs restores previously persisted buffer settings', () async {
      SharedPreferences.setMockInitialValues({
        'networkCachingMs': 3000,
        'demuxerCacheMb': 128,
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = BufferCachingSettingsController();

      await controller.loadFromPrefs(prefs);
      expect(controller.networkCachingMs, equals(3000));
      expect(controller.demuxerCacheMb, equals(128));
    });
  });
}
