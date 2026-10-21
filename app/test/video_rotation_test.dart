import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/domain/video_rotation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRotationService Unit Tests', () {
    final List<MethodCall> log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        log.add(methodCall);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('getNextMode cycles properly through modes', () {
      expect(
        VideoRotationService.getNextMode(ScreenOrientationMode.sensor),
        equals(ScreenOrientationMode.landscape),
      );
      expect(
        VideoRotationService.getNextMode(ScreenOrientationMode.landscape),
        equals(ScreenOrientationMode.portrait),
      );
      expect(
        VideoRotationService.getNextMode(ScreenOrientationMode.portrait),
        equals(ScreenOrientationMode.sensor),
      );
      expect(
        VideoRotationService.getNextMode(ScreenOrientationMode.matchVideo),
        equals(ScreenOrientationMode.sensor),
      );
    });

    test('getModeLabel returns user-friendly display titles', () {
      expect(VideoRotationService.getModeLabel(ScreenOrientationMode.sensor), equals('Auto (Sensor)'));
      expect(VideoRotationService.getModeLabel(ScreenOrientationMode.landscape), equals('Landscape Lock'));
      expect(VideoRotationService.getModeLabel(ScreenOrientationMode.portrait), equals('Portrait Lock'));
      expect(VideoRotationService.getModeLabel(ScreenOrientationMode.matchVideo), equals('Match Video Aspect'));
    });

    test('getNextQuarterTurns cycles from 0 to 3 and wraps to 0', () {
      expect(VideoRotationService.getNextQuarterTurns(0), equals(1));
      expect(VideoRotationService.getNextQuarterTurns(1), equals(2));
      expect(VideoRotationService.getNextQuarterTurns(2), equals(3));
      expect(VideoRotationService.getNextQuarterTurns(3), equals(0));
    });

    test('getRotationDegrees returns corresponding angles in 90-degree steps', () {
      expect(VideoRotationService.getRotationDegrees(0), equals(0));
      expect(VideoRotationService.getRotationDegrees(1), equals(90));
      expect(VideoRotationService.getRotationDegrees(2), equals(180));
      expect(VideoRotationService.getRotationDegrees(3), equals(270));
      expect(VideoRotationService.getRotationDegrees(4), equals(0));
    });

    test('isPortraitVideo detects portrait vs landscape aspect ratio', () {
      // Landscape
      expect(VideoRotationService.isPortraitVideo(1920, 1080), isFalse);
      expect(VideoRotationService.isPortraitVideo(3840, 2160), isFalse);

      // Portrait
      expect(VideoRotationService.isPortraitVideo(1080, 1920), isTrue);
      expect(VideoRotationService.isPortraitVideo(720, 1280), isTrue);

      // Square & invalid
      expect(VideoRotationService.isPortraitVideo(1000, 1000), isFalse);
      expect(VideoRotationService.isPortraitVideo(null, 1080), isFalse);
      expect(VideoRotationService.isPortraitVideo(1080, null), isFalse);
      expect(VideoRotationService.isPortraitVideo(0, 1080), isFalse);
      expect(VideoRotationService.isPortraitVideo(1080, 0), isFalse);
    });

    test('applyOrientation(landscape) invokes platform channel with landscape orientations', () async {
      await VideoRotationService.applyOrientation(ScreenOrientationMode.landscape);

      expect(log.length, equals(1));
      expect(log.first.method, equals('SystemChrome.setPreferredOrientations'));
      expect(
        log.first.arguments,
        equals(['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']),
      );
    });

    test('applyOrientation(portrait) invokes platform channel with portraitUp', () async {
      await VideoRotationService.applyOrientation(ScreenOrientationMode.portrait);

      expect(log.length, equals(1));
      expect(log.first.method, equals('SystemChrome.setPreferredOrientations'));
      expect(
        log.first.arguments,
        equals(['DeviceOrientation.portraitUp']),
      );
    });

    test('applyOrientation(sensor) allows landscape and portrait orientations', () async {
      await VideoRotationService.applyOrientation(ScreenOrientationMode.sensor);

      expect(log.length, equals(1));
      expect(log.first.method, equals('SystemChrome.setPreferredOrientations'));
      expect(
        log.first.arguments,
        equals([
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
          'DeviceOrientation.portraitUp',
        ]),
      );
    });

    test('applyOrientation(matchVideo) selects landscape for wide video and portrait for vertical video', () async {
      // 1. Wide video
      await VideoRotationService.applyOrientation(
        ScreenOrientationMode.matchVideo,
        videoWidth: 1920,
        videoHeight: 1080,
      );
      expect(log.last.method, equals('SystemChrome.setPreferredOrientations'));
      expect(
        log.last.arguments,
        equals(['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']),
      );

      // 2. Vertical video
      await VideoRotationService.applyOrientation(
        ScreenOrientationMode.matchVideo,
        videoWidth: 1080,
        videoHeight: 1920,
      );
      expect(log.last.method, equals('SystemChrome.setPreferredOrientations'));
      expect(
        log.last.arguments,
        equals(['DeviceOrientation.portraitUp']),
      );
    });

    test('resetOrientation restores all DeviceOrientation values', () async {
      await VideoRotationService.resetOrientation();

      expect(log.length, equals(1));
      expect(log.first.method, equals('SystemChrome.setPreferredOrientations'));
      expect(
        log.first.arguments,
        equals([
          'DeviceOrientation.portraitUp',
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.portraitDown',
          'DeviceOrientation.landscapeRight',
        ]),
      );
    });
  });
}
