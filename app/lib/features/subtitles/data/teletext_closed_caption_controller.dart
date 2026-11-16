import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../models/teletext_closed_caption_models.dart';

/// Controller coordinating Teletext (zvbi.c) and Closed-Captions (cc.c) states and libmpv bindings.
class TeletextClosedCaptionController extends ChangeNotifier {
  ClosedCaptionConfig _captionConfig;
  TeletextConfig _teletextConfig;
  String _keypadBuffer = '';
  Player? _player;

  ClosedCaptionConfig get captionConfig => _captionConfig;
  TeletextConfig get teletextConfig => _teletextConfig;
  String get keypadBuffer => _keypadBuffer;
  bool get hasKeypadInput => _keypadBuffer.isNotEmpty;

  TeletextClosedCaptionController({
    ClosedCaptionConfig? captionConfig,
    TeletextConfig? teletextConfig,
    Player? player,
  })  : _captionConfig = captionConfig ?? ClosedCaptionConfig(),
        _teletextConfig = teletextConfig ?? TeletextConfig() {
    _player = player;
  }

  void attachPlayer(Player? player) {
    _player = player;
    _applyToPlayer();
  }

  // --- Closed Captions (cc.c Parity) ---

  void setClosedCaptionChannel(ClosedCaptionChannel channel) {
    _captionConfig = _captionConfig.copyWith(channel: channel);
    _applyToPlayer();
    notifyListeners();
  }

  void cycleClosedCaptionChannel() {
    const sequence = [
      ClosedCaptionChannel.off,
      ClosedCaptionChannel.cc1,
      ClosedCaptionChannel.cc2,
      ClosedCaptionChannel.cc3,
      ClosedCaptionChannel.cc4,
      ClosedCaptionChannel.service1,
      ClosedCaptionChannel.service2,
    ];
    final currentIndex = sequence.indexOf(_captionConfig.channel);
    final nextIndex = (currentIndex + 1) % sequence.length;
    setClosedCaptionChannel(sequence[nextIndex]);
  }

  void updateCaptionConfig(ClosedCaptionConfig config) {
    _captionConfig = config;
    _applyToPlayer();
    notifyListeners();
  }

  // --- Teletext (zvbi.c Parity) ---

  void toggleTeletext([bool? enabled]) {
    final next = enabled ?? !_teletextConfig.enabled;
    _teletextConfig = _teletextConfig.copyWith(enabled: next);
    _applyToPlayer();
    notifyListeners();
  }

  void setTeletextPage(int page) {
    final clamped = page.clamp(100, 899);
    _keypadBuffer = '';

    // Dynamically adjust fastext shortcuts based on genre
    int red = (clamped + 1 > 899) ? 100 : clamped + 1;
    int green = (clamped - 1 < 100) ? 899 : clamped - 1;
    int yellow = 100; // Always Index
    int blue = 888; // Always Subtitles

    if (clamped == 100) {
      red = 101;
      green = 200;
      yellow = 777;
      blue = 888;
    } else if (clamped == 888) {
      red = 100;
      green = 777;
      yellow = 333;
      blue = 888;
    }

    _teletextConfig = _teletextConfig.copyWith(
      page: clamped,
      fastTextRed: red,
      fastTextGreen: green,
      fastTextYellow: yellow,
      fastTextBlue: blue,
    );
    _applyToPlayer();
    notifyListeners();
  }

  void nextSubpage() {
    final next = (_teletextConfig.subpage + 1).clamp(0, 99);
    _teletextConfig = _teletextConfig.copyWith(subpage: next);
    notifyListeners();
  }

  void prevSubpage() {
    final prev = (_teletextConfig.subpage - 1).clamp(0, 99);
    _teletextConfig = _teletextConfig.copyWith(subpage: prev);
    notifyListeners();
  }

  void updateTeletextConfig(TeletextConfig config) {
    _teletextConfig = config;
    _applyToPlayer();
    notifyListeners();
  }

  // --- Numeric Keypad 3-Digit Page Entry ---

  void inputDigit(int digit) {
    if (digit < 0 || digit > 9) return;
    _keypadBuffer += digit.toString();

    if (_keypadBuffer.length >= 3) {
      final page = int.tryParse(_keypadBuffer);
      _keypadBuffer = '';
      if (page != null && page >= 100 && page <= 899) {
        setTeletextPage(page);
        return;
      }
    }
    notifyListeners();
  }

  void clearKeypad() {
    _keypadBuffer = '';
    notifyListeners();
  }

  // --- Fastext Quick Navigation Buttons ---

  void pressRed() => setTeletextPage(_teletextConfig.fastTextRed);
  void pressGreen() => setTeletextPage(_teletextConfig.fastTextGreen);
  void pressYellow() => setTeletextPage(_teletextConfig.fastTextYellow);
  void pressBlue() => setTeletextPage(_teletextConfig.fastTextBlue);

  // --- libmpv Synchronization ---

  void _applyToPlayer() {
    if (_player == null) return;
    try {
      final platform = _player!.platform as dynamic;

      // Closed-Captions libmpv options
      if (_captionConfig.isEnabled) {
        platform.setProperty('sub-create-cc-track', 'yes');
        final hexFont = _colorToHex(_captionConfig.fontColor);
        final hexBg = _colorToHex(_captionConfig.backgroundColor.withValues(
          alpha: _captionConfig.backgroundOpacity,
        ));
        platform.setProperty('sub-color', hexFont);
        platform.setProperty('sub-back-color', hexBg);
        platform.setProperty('sub-font-size', _captionConfig.fontSize.round().toString());
      }

      // Teletext libmpv options
      if (_teletextConfig.enabled) {
        platform.setProperty('teletext-page', _teletextConfig.page.toString());
      }
    } catch (e) {
      debugPrint('[TeletextClosedCaptionController] libmpv property error: $e');
    }
  }

  static String _colorToHex(Color c) {
    final r = ((c.r * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
    final g = ((c.g * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
    final b = ((c.b * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }
}
