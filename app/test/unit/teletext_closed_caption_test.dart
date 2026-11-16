import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/subtitles/models/teletext_closed_caption_models.dart';
import 'package:app/features/subtitles/data/teletext_closed_caption_controller.dart';

void main() {
  group('Teletext (zvbi.c) & Closed-Captions (cc.c) Unit Tests', () {
    test('Default ClosedCaptionConfig initializes in off state with FCC defaults', () {
      final config = ClosedCaptionConfig();

      expect(config.channel, equals(ClosedCaptionChannel.off));
      expect(config.isEnabled, isFalse);
      expect(config.isOpaque, isTrue); // VLC cc-opaque parity
      expect(config.fontSize, equals(24.0));
      expect(config.fontFamily, equals('Monospace'));
      expect(config.edgeStyle, equals(CaptionEdgeStyle.dropShadow));
    });

    test('ClosedCaptionConfig serialization round-trip retains styling parameters', () {
      final original = ClosedCaptionConfig(
        channel: ClosedCaptionChannel.service1,
        isOpaque: false,
        fontColor: const Color(0xFFFFEB3B),
        fontOpacity: 0.9,
        backgroundColor: const Color(0xFF1E293B),
        backgroundOpacity: 0.75,
        fontSize: 32.0,
        fontFamily: 'Courier',
        edgeStyle: CaptionEdgeStyle.outline,
      );

      final json = original.toJson();
      final restored = ClosedCaptionConfig.fromJson(json);

      expect(restored.channel, equals(ClosedCaptionChannel.service1));
      expect(restored.isEnabled, isTrue);
      expect(restored.isOpaque, isFalse);
      expect(restored.fontOpacity, equals(0.9));
      expect(restored.fontSize, equals(32.0));
      expect(restored.fontFamily, equals('Courier'));
      expect(restored.edgeStyle, equals(CaptionEdgeStyle.outline));
    });

    test('Default TeletextConfig initializes at Page 100 with standard fastext links', () {
      final config = TeletextConfig();

      expect(config.enabled, isFalse);
      expect(config.page, equals(100));
      expect(config.subpage, equals(1));
      expect(config.isOpaque, isTrue); // VLC vbi-opaque parity
      expect(config.fastTextRed, equals(101));
      expect(config.fastTextGreen, equals(200));
      expect(config.fastTextYellow, equals(100));
      expect(config.fastTextBlue, equals(888));
    });

    test('TeletextConfig serialization round-trip retains page & fastext parameters', () {
      final original = TeletextConfig(
        enabled: true,
        page: 888,
        subpage: 4,
        isOpaque: false,
        position: TeletextPosition.bottom,
        fastTextRed: 100,
        fastTextGreen: 777,
        fastTextYellow: 333,
        fastTextBlue: 888,
      );

      final json = original.toJson();
      final restored = TeletextConfig.fromJson(json);

      expect(restored.enabled, isTrue);
      expect(restored.page, equals(888));
      expect(restored.subpage, equals(4));
      expect(restored.isOpaque, isFalse);
      expect(restored.position, equals(TeletextPosition.bottom));
      expect(restored.fastTextRed, equals(100));
      expect(restored.fastTextBlue, equals(888));
    });

    test('TeletextClosedCaptionController cycles CC channels correctly', () {
      final controller = TeletextClosedCaptionController();

      expect(controller.captionConfig.channel, equals(ClosedCaptionChannel.off));

      controller.cycleClosedCaptionChannel();
      expect(controller.captionConfig.channel, equals(ClosedCaptionChannel.cc1));

      controller.cycleClosedCaptionChannel();
      expect(controller.captionConfig.channel, equals(ClosedCaptionChannel.cc2));

      controller.setClosedCaptionChannel(ClosedCaptionChannel.service2);
      expect(controller.captionConfig.channel, equals(ClosedCaptionChannel.service2));
    });

    test('Teletext page clamping and fastext genre updates', () {
      final controller = TeletextClosedCaptionController();

      // Page clamping
      controller.setTeletextPage(999);
      expect(controller.teletextConfig.page, equals(899));

      controller.setTeletextPage(50);
      expect(controller.teletextConfig.page, equals(100));

      // Page 888 Subtitles
      controller.setTeletextPage(888);
      expect(controller.teletextConfig.page, equals(888));
      expect(controller.teletextConfig.fastTextBlue, equals(888));
    });

    test('Numeric keypad buffer accumulates 3 digits then automatically sets page', () {
      final controller = TeletextClosedCaptionController();

      expect(controller.hasKeypadInput, isFalse);

      controller.inputDigit(8);
      expect(controller.keypadBuffer, equals('8'));
      expect(controller.hasKeypadInput, isTrue);
      expect(controller.teletextConfig.page, equals(100)); // Still old page

      controller.inputDigit(8);
      expect(controller.keypadBuffer, equals('88'));

      controller.inputDigit(8); // 3rd digit triggers page jump!
      expect(controller.keypadBuffer, isEmpty);
      expect(controller.hasKeypadInput, isFalse);
      expect(controller.teletextConfig.page, equals(888));
    });

    test('Fastext actions jump to respective color shortcuts', () {
      final controller = TeletextClosedCaptionController();
      controller.setTeletextPage(100);

      // Red is 101
      controller.pressRed();
      expect(controller.teletextConfig.page, equals(101));

      // Yellow returns to 100
      controller.pressYellow();
      expect(controller.teletextConfig.page, equals(100));

      // Blue jumps to 888 (Subtitles)
      controller.pressBlue();
      expect(controller.teletextConfig.page, equals(888));
    });

    test('Subpage navigation increments and decrements within 0..99', () {
      final controller = TeletextClosedCaptionController();
      expect(controller.teletextConfig.subpage, equals(1));

      controller.nextSubpage();
      expect(controller.teletextConfig.subpage, equals(2));

      controller.prevSubpage();
      expect(controller.teletextConfig.subpage, equals(1));
    });

    test('TeletextPageContent generates appropriate broadcast content for page 100, 888, 777', () {
      final page100 = TeletextPageContent.generate(100, 1);
      expect(page100.lines.any((l) => l.contains('E-PLAYER TELETEXT')), isTrue);
      expect(page100.lines.any((l) => l.contains('888')), isTrue);

      final page888 = TeletextPageContent.generate(888, 1);
      expect(page888.title, equals('SUBTITLES / CC DHH'));
      expect(page888.lines.any((l) => l.contains('CLOSED CAPTIONS')), isTrue);

      final page777 = TeletextPageContent.generate(777, 1);
      expect(page777.title, equals('TV SCHEDULE & GUIDE'));
    });
  });
}
