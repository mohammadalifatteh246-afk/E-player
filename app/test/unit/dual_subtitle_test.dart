import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app/features/subtitles/domain/dual_subtitle_controller.dart';

class MockMpvPropertyDispatcher implements MpvSubtitlePropertyDispatcher {
  final Map<String, String> properties = {};
  SubtitleTrack? lastPrimaryTrack;

  @override
  Future<void> setProperty(String name, String value) async {
    properties[name] = value;
  }

  @override
  Future<void> setPrimaryTrack(SubtitleTrack track) async {
    lastPrimaryTrack = track;
  }
}

void main() {
  group('DualSubtitleController Unit Tests', () {
    late MockMpvPropertyDispatcher dispatcher;
    late DualSubtitleController controller;

    setUp(() {
      dispatcher = MockMpvPropertyDispatcher();
      controller = DualSubtitleController(dispatcher: dispatcher);
    });

    test('1. Initializes with default disabled state', () {
      expect(controller.isEnabled, isFalse);
      expect(controller.isDualActive, isFalse);
      expect(controller.primaryTrack.id, 'no');
      expect(controller.secondaryTrack.id, 'no');
      expect(controller.secondaryDelay, 0.0);
      expect(controller.secondaryPosition, 10.0);
      expect(controller.isSecondaryVisible, isTrue);
    });

    test('2. Setting primary track dispatches to primary setter', () {
      final track = SubtitleTrack.uri('file:///sub_en.srt', title: 'English');
      controller.setPrimaryTrack(track);

      expect(controller.primaryTrack.id, track.id);
      expect(dispatcher.lastPrimaryTrack?.id, track.id);
    });

    test('3. Setting secondary track auto-enables dual mode and sets mpv properties', () {
      final secTrack = SubtitleTrack.uri('file:///sub_hi.srt', title: 'Hindi');
      controller.setSecondaryTrack(secTrack);

      expect(controller.isEnabled, isTrue);
      expect(controller.isDualActive, isTrue);
      expect(controller.secondaryTrack.id, secTrack.id);
      expect(dispatcher.properties['secondary-sid'], secTrack.id);
      expect(dispatcher.properties['secondary-sub-pos'], '10');
      expect(dispatcher.properties['secondary-sub-visibility'], 'yes');
      expect(dispatcher.properties['sub-pos'], '92');
    });

    test('4. swapTracks successfully exchanges primary and secondary subtitles', () {
      final enTrack = SubtitleTrack.uri('file:///sub_en.srt', title: 'English');
      final hiTrack = SubtitleTrack.uri('file:///sub_hi.srt', title: 'Hindi');

      controller.setPrimaryTrack(enTrack);
      controller.setSecondaryTrack(hiTrack);

      expect(controller.primaryTrack.id, enTrack.id);
      expect(controller.secondaryTrack.id, hiTrack.id);

      // Perform 1-tap swap
      controller.swapTracks();

      expect(controller.primaryTrack.id, hiTrack.id);
      expect(controller.secondaryTrack.id, enTrack.id);
      expect(dispatcher.lastPrimaryTrack?.id, hiTrack.id);
      expect(dispatcher.properties['secondary-sid'], enTrack.id);
    });

    test('5. Secondary delay adjustment and nudging clamp between -30s and +30s', () {
      controller.setSecondaryDelay(1.5);
      expect(controller.secondaryDelay, 1.5);
      expect(dispatcher.properties['secondary-sub-delay'], '1.50');

      controller.nudgeSecondaryDelay(-0.5);
      expect(controller.secondaryDelay, 1.0);
      expect(dispatcher.properties['secondary-sub-delay'], '1.00');

      // Clamping test
      controller.setSecondaryDelay(50.0);
      expect(controller.secondaryDelay, 30.0);

      controller.setSecondaryDelay(-45.0);
      expect(controller.secondaryDelay, -30.0);
    });

    test('6. Secondary position updates', () {
      controller.setSecondaryPosition(SecondarySubtitlePosition.upperThird.posValue);
      expect(controller.secondaryPosition, 25.0);
      expect(dispatcher.properties['secondary-sub-pos'], '25');

      controller.setSecondaryPosition(SecondarySubtitlePosition.center.posValue);
      expect(controller.secondaryPosition, 50.0);
      expect(dispatcher.properties['secondary-sub-pos'], '50');
    });

    test('7. Toggle secondary visibility', () {
      expect(controller.isSecondaryVisible, isTrue);
      controller.toggleSecondaryVisibility();
      expect(controller.isSecondaryVisible, isFalse);
      expect(dispatcher.properties['secondary-sub-visibility'], 'no');

      controller.toggleSecondaryVisibility();
      expect(controller.isSecondaryVisible, isTrue);
      expect(dispatcher.properties['secondary-sub-visibility'], 'yes');
    });

    test('8. Disabling dual subtitles sets secondary-sid to no', () {
      final secTrack = SubtitleTrack.uri('file:///sub_hi.srt', title: 'Hindi');
      controller.setSecondaryTrack(secTrack);
      expect(dispatcher.properties['secondary-sid'], secTrack.id);

      controller.toggleDualSubtitles(false);
      expect(controller.isEnabled, isFalse);
      expect(controller.isDualActive, isFalse);
      expect(dispatcher.properties['secondary-sid'], 'no');
    });
  });
}
