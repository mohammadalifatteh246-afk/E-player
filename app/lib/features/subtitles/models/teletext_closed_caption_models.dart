import 'package:flutter/material.dart';

/// EIA-608 & CEA-708 Closed Caption Channel Types (VLC cc.c parity).
enum ClosedCaptionChannel {
  off('Off', false),
  cc1('CC1 (Primary Dialogue)', false),
  cc2('CC2 (Secondary / Spanish)', false),
  cc3('CC3 (Special / Tertiary)', false),
  cc4('CC4 (Data / Transcript)', false),
  service1('CEA-708 Service 1 (Digital HD)', true),
  service2('CEA-708 Service 2 (Secondary Digital)', true),
  service3('CEA-708 Service 3 (Special Digital)', true),
  service4('CEA-708 Service 4 (Data Digital)', true),
  service5('CEA-708 Service 5', true),
  service6('CEA-708 Service 6', true);

  final String label;
  final bool isDigital;

  const ClosedCaptionChannel(this.label, this.isDigital);

  String get shortCode {
    switch (this) {
      case ClosedCaptionChannel.off:
        return 'OFF';
      case ClosedCaptionChannel.cc1:
        return 'CC1';
      case ClosedCaptionChannel.cc2:
        return 'CC2';
      case ClosedCaptionChannel.cc3:
        return 'CC3';
      case ClosedCaptionChannel.cc4:
        return 'CC4';
      case ClosedCaptionChannel.service1:
        return 'DTVCC1';
      case ClosedCaptionChannel.service2:
        return 'DTVCC2';
      case ClosedCaptionChannel.service3:
        return 'DTVCC3';
      case ClosedCaptionChannel.service4:
        return 'DTVCC4';
      case ClosedCaptionChannel.service5:
        return 'DTVCC5';
      case ClosedCaptionChannel.service6:
        return 'DTVCC6';
    }
  }
}

/// Caption edge styling for CEA-708 broadcast rendering.
enum CaptionEdgeStyle {
  none('None'),
  dropShadow('Drop Shadow'),
  raised('Raised'),
  depressed('Depressed'),
  outline('Uniform Outline');

  final String label;
  const CaptionEdgeStyle(this.label);
}

/// Configuration model managing FCC-compliant Closed Captions (VLC cc.c parity).
class ClosedCaptionConfig {
  ClosedCaptionChannel channel;
  bool isOpaque; // Boxed text with high-contrast background (VLC cc-opaque)
  Color fontColor;
  double fontOpacity;
  Color backgroundColor;
  double backgroundOpacity;
  double fontSize;
  String fontFamily;
  CaptionEdgeStyle edgeStyle;

  ClosedCaptionConfig({
    this.channel = ClosedCaptionChannel.off,
    this.isOpaque = true,
    this.fontColor = Colors.white,
    this.fontOpacity = 1.0,
    this.backgroundColor = Colors.black,
    this.backgroundOpacity = 0.85,
    this.fontSize = 24.0,
    this.fontFamily = 'Monospace',
    this.edgeStyle = CaptionEdgeStyle.dropShadow,
  });

  bool get isEnabled => channel != ClosedCaptionChannel.off;

  ClosedCaptionConfig copyWith({
    ClosedCaptionChannel? channel,
    bool? isOpaque,
    Color? fontColor,
    double? fontOpacity,
    Color? backgroundColor,
    double? backgroundOpacity,
    double? fontSize,
    String? fontFamily,
    CaptionEdgeStyle? edgeStyle,
  }) {
    return ClosedCaptionConfig(
      channel: channel ?? this.channel,
      isOpaque: isOpaque ?? this.isOpaque,
      fontColor: fontColor ?? this.fontColor,
      fontOpacity: fontOpacity ?? this.fontOpacity,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      edgeStyle: edgeStyle ?? this.edgeStyle,
    );
  }

  Map<String, dynamic> toJson() => {
        'channel': channel.name,
        'isOpaque': isOpaque,
        'fontColor': fontColor.toARGB32(),
        'fontOpacity': fontOpacity,
        'backgroundColor': backgroundColor.toARGB32(),
        'backgroundOpacity': backgroundOpacity,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'edgeStyle': edgeStyle.name,
      };

  factory ClosedCaptionConfig.fromJson(Map<String, dynamic> json) {
    return ClosedCaptionConfig(
      channel: json['channel'] != null
          ? ClosedCaptionChannel.values.firstWhere(
              (e) => e.name == json['channel'],
              orElse: () => ClosedCaptionChannel.off,
            )
          : ClosedCaptionChannel.off,
      isOpaque: json['isOpaque'] as bool? ?? true,
      fontColor: json['fontColor'] != null
          ? Color(json['fontColor'] as int)
          : Colors.white,
      fontOpacity: (json['fontOpacity'] as num?)?.toDouble() ?? 1.0,
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'] as int)
          : Colors.black,
      backgroundOpacity: (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.85,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
      fontFamily: json['fontFamily'] as String? ?? 'Monospace',
      edgeStyle: json['edgeStyle'] != null
          ? CaptionEdgeStyle.values.firstWhere(
              (e) => e.name == json['edgeStyle'],
              orElse: () => CaptionEdgeStyle.dropShadow,
            )
          : CaptionEdgeStyle.dropShadow,
    );
  }
}

/// Teletext display position on the video screen.
enum TeletextPosition {
  fullScreen('Full Screen'),
  bottom('Bottom Bar'),
  top('Top Bar');

  final String label;
  const TeletextPosition(this.label);
}

/// Configuration model managing Teletext / VBI decoding (VLC zvbi.c parity).
class TeletextConfig {
  bool enabled;
  int page; // 100 to 899
  int subpage; // 0 to 99
  bool isOpaque; // Boxed text vs transparent overlay (VLC vbi-opaque)
  TeletextPosition position;
  int fastTextRed;
  int fastTextGreen;
  int fastTextYellow;
  int fastTextBlue;

  TeletextConfig({
    this.enabled = false,
    this.page = 100,
    this.subpage = 1,
    this.isOpaque = true,
    this.position = TeletextPosition.fullScreen,
    this.fastTextRed = 101,
    this.fastTextGreen = 200,
    this.fastTextYellow = 100,
    this.fastTextBlue = 888,
  });

  TeletextConfig copyWith({
    bool? enabled,
    int? page,
    int? subpage,
    bool? isOpaque,
    TeletextPosition? position,
    int? fastTextRed,
    int? fastTextGreen,
    int? fastTextYellow,
    int? fastTextBlue,
  }) {
    return TeletextConfig(
      enabled: enabled ?? this.enabled,
      page: page ?? this.page,
      subpage: subpage ?? this.subpage,
      isOpaque: isOpaque ?? this.isOpaque,
      position: position ?? this.position,
      fastTextRed: fastTextRed ?? this.fastTextRed,
      fastTextGreen: fastTextGreen ?? this.fastTextGreen,
      fastTextYellow: fastTextYellow ?? this.fastTextYellow,
      fastTextBlue: fastTextBlue ?? this.fastTextBlue,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'page': page,
        'subpage': subpage,
        'isOpaque': isOpaque,
        'position': position.name,
        'fastTextRed': fastTextRed,
        'fastTextGreen': fastTextGreen,
        'fastTextYellow': fastTextYellow,
        'fastTextBlue': fastTextBlue,
      };

  factory TeletextConfig.fromJson(Map<String, dynamic> json) {
    return TeletextConfig(
      enabled: json['enabled'] as bool? ?? false,
      page: (json['page'] as num?)?.toInt() ?? 100,
      subpage: (json['subpage'] as num?)?.toInt() ?? 1,
      isOpaque: json['isOpaque'] as bool? ?? true,
      position: json['position'] != null
          ? TeletextPosition.values.firstWhere(
              (e) => e.name == json['position'],
              orElse: () => TeletextPosition.fullScreen,
            )
          : TeletextPosition.fullScreen,
      fastTextRed: (json['fastTextRed'] as num?)?.toInt() ?? 101,
      fastTextGreen: (json['fastTextGreen'] as num?)?.toInt() ?? 200,
      fastTextYellow: (json['fastTextYellow'] as num?)?.toInt() ?? 100,
      fastTextBlue: (json['fastTextBlue'] as num?)?.toInt() ?? 888,
    );
  }
}

/// Simulated Teletext content generator for broadcast emulation & subtitle rendering.
class TeletextPageContent {
  final int page;
  final int subpage;
  final String title;
  final List<String> lines;
  final Color headerColor;

  TeletextPageContent({
    required this.page,
    required this.subpage,
    required this.title,
    required this.lines,
    this.headerColor = const Color(0xFF00E5FF),
  });

  factory TeletextPageContent.generate(int page, int subpage) {
    if (page == 888) {
      return TeletextPageContent(
        page: 888,
        subpage: subpage,
        title: 'SUBTITLES / CC DHH',
        headerColor: const Color(0xFFFFEB3B), // Classic Teletext Yellow
        lines: [
          'E-PLAYER CEEFAX 888  17:08:00',
          '========================================',
          'LIVE BROADCAST CLOSED CAPTIONS (DHH)',
          '========================================',
          '',
          '  [DIALOGUE IN ENGLISH]',
          '  "Welcome to E-Player Live Stream."',
          '  "Broadcasting with EIA-608 and',
          '   CEA-708 DTVCC subtitle parity."',
          '',
          '  (APPLAUSE AND AMBIENT MUSIC)',
          '',
          '  Press BLUE to refresh subtitles.',
          '  Press RED to return to Main Index.',
          '========================================',
          'PAGE 888 • SUBTITLE STREAM SYNCHRONIZED',
        ],
      );
    } else if (page == 100) {
      return TeletextPageContent(
        page: 100,
        subpage: subpage,
        title: 'MAIN INDEX / HEADLINES',
        headerColor: const Color(0xFF00E5FF),
        lines: [
          'P100  E-PLAYER CEEFAX  17:08:00',
          '========================================',
          '           E-PLAYER TELETEXT            ',
          '========================================',
          '',
          '  NEWS HEADLINES ............... 101',
          '  SPORTS ROUNDUP ............... 200',
          '  WEATHER & RADAR .............. 333',
          '  FINANCIAL MARKETS ............ 400',
          '  TV SCHEDULE & MOVIES ......... 777',
          '  SUBTITLES & CAPTIONS ......... 888',
          '',
          '  ENTER 3 DIGITS TO JUMP TO ANY PAGE',
          '========================================',
          '  RED: News   GREEN: Sport  YELLOW: Index  BLUE: Subs',
        ],
      );
    } else if (page == 777) {
      return TeletextPageContent(
        page: 777,
        subpage: subpage,
        title: 'TV SCHEDULE & GUIDE',
        headerColor: const Color(0xFF69F0AE),
        lines: [
          'P777  E-PLAYER GUIDE   17:08:00',
          '========================================',
          '         BROADCAST SCHEDULE             ',
          '========================================',
          '',
          '  18:00  EVENING GLOBAL NEWS',
          '  19:00  PLANET EARTH III (4K HDR)',
          '  20:30  BLADE RUNNER 2049 (DIRECTORS CUT)',
          '  23:15  NIGHTLINE & WEATHER',
          '',
          '  ALL PRIME SHOWS CARRY 888 SUBTITLES',
          '========================================',
        ],
      );
    } else {
      return TeletextPageContent(
        page: page,
        subpage: subpage,
        title: 'PAGE $page',
        headerColor: const Color(0xFF00E5FF),
        lines: [
          'P$page  E-PLAYER TELETEXT  17:08:00',
          '========================================',
          '         BROADCAST PAGE $page            ',
          '========================================',
          '',
          '  Content transmitted on frequency.',
          '  Subpage: $subpage / 01',
          '',
          '  Press 100 for Main Index.',
          '  Press 888 for Subtitles.',
          '========================================',
        ],
      );
    }
  }
}
