import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:app/theme/e_player_theme.dart';
import 'package:app/features/library/domain/library_provider.dart';
import 'package:app/features/settings/domain/settings_provider.dart';
import 'package:app/features/casting/domain/cast_service.dart';
import 'package:app/features/home/domain/media_group_service.dart';
import 'package:app/features/export/domain/export_service.dart';
import 'package:app/features/vault/domain/vault_service.dart';
import 'package:app/features/trash/domain/trash_service.dart';

/// Ephemeral HTTP Range Server for testing Phase 11 tokenized casting,
/// byte range seeking (HTTP 206), and WebVTT subtitle delivery.
class EphemeralCastServer {
  final HttpServer server;
  final String sessionToken;
  final List<int> mediaBytes;
  final String vttContent;
  final List<String> requestLog = [];

  EphemeralCastServer({
    required this.server,
    required this.sessionToken,
    required this.mediaBytes,
    required this.vttContent,
  });

  String get host => server.address.address;
  int get port => server.port;
  String get streamUrl => 'http://$host:$port/cast/$sessionToken/stream';
  String get subtitleUrl => 'http://$host:$port/cast/$sessionToken/subtitles/track_1.vtt';

  Future<void> close() async {
    await server.close(force: true);
  }
}

class RealLoopbackHttpOverrides extends HttpOverrides {}

/// Shared Mock-Free Test Harness for E-Player E2E and Integration Verification.
///
/// Features:
/// 1. In-memory SQLite FFI initialization and clean teardown.
/// 2. Isolated temporary media and subtitle fixture generation in OS temp.
/// 3. Platform channel interception using TestDefaultBinaryMessengerBinding.
/// 4. Live local HTTP server for casting and range request verification.
/// 5. Pure mathematical validators for gesture dead-zones, zoom pan bounds,
///    PiP aspect ratios, and decoder fallback cascades.
class EPlayerTestHarness {
  final List<MethodCall> platformCalls = [];
  final List<Directory> _tempDirs = [];
  final List<EphemeralCastServer> _servers = [];

  bool isPipSupported = true;
  bool isInPipMode = false;
  bool autoEnterPipEnabled = false;
  double systemBrightness = 0.5;

  static const MethodChannel pipChannel = MethodChannel('com.example.app/pip');
  static const MethodChannel brightnessChannel = MethodChannel('com.example.app/system_brightness');
  static const MethodChannel scannerChannel = MethodChannel('com.example.app/media_scanner');
  static bool _sqfliteInitialized = false;

  /// Set up in-memory SQLite FFI, mock SharedPreferences, and native platform bindings.
  Future<void> setUp() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = RealLoopbackHttpOverrides();

    // 1. In-Memory SQLite FFI
    if (!_sqfliteInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _sqfliteInitialized = true;
    }

    // 2. In-Memory SharedPreferences
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'hardware_acceleration': true,
      'default_subtitle_size': 18.0,
      'resume_playback': true,
      'volume_level': 80.0,
      'brightness_level': 0.65,
    });

    // 3. Platform Channel Interception
    platformCalls.clear();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      platformCalls.add(call);
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        return null;
      }
      return null;
    });

    messenger.setMockMethodCallHandler(brightnessChannel, (MethodCall call) async {
      platformCalls.add(call);
      if (call.method == 'setBrightness') {
        final val = (call.arguments as num).toDouble();
        systemBrightness = val.clamp(0.0, 1.0);
        return true;
      } else if (call.method == 'getBrightness') {
        return systemBrightness;
      }
      return null;
    });

    messenger.setMockMethodCallHandler(pipChannel, (MethodCall call) async {
      platformCalls.add(call);
      switch (call.method) {
        case 'isPipSupported':
          return isPipSupported;
        case 'enterPictureInPictureMode':
          isInPipMode = true;
          return true;
        case 'setAutoEnterEnabled':
          autoEnterPipEnabled = call.arguments?['enabled'] == true;
          return true;
        case 'toggleDesktopOverlay':
          isInPipMode = call.arguments?['enabled'] == true;
          return true;
        default:
          return null;
      }
    });

    messenger.setMockMethodCallHandler(scannerChannel, (MethodCall call) async {
      platformCalls.add(call);
      return <String>[];
    });
  }

  /// Create an isolated temporary directory within OS temp and track for disposal.
  Directory createTempDirectory([String prefix = 'eplayer_test_']) {
    final dir = Directory.systemTemp.createTempSync(prefix);
    _tempDirs.add(dir);
    return dir;
  }

  /// Synthesize a binary media fixture with valid container magic headers.
  Future<File> createMockVideoFile(
    Directory dir,
    String filename, {
    int sizeBytes = 64 * 1024,
    String format = 'mp4',
  }) async {
    final file = File('${dir.path}/$filename');
    final bytes = BytesBuilder();

    if (format.toLowerCase() == 'mp4') {
      // Standard ISO Base Media File ftyp atom header
      bytes.add([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D]);
    } else if (format.toLowerCase() == 'mkv') {
      // Matroska EBML header [0x1A, 0x45, 0xDF, 0xA3]
      bytes.add([0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42, 0x86, 0x81, 0x01, 0x42, 0xF7, 0x81, 0x01]);
    } else if (format.toLowerCase() == 'avi') {
      // RIFF AVI header
      bytes.add(utf8.encode('RIFF....AVI LIST'));
    } else {
      bytes.add([0x00, 0x00, 0x00, 0x01]);
    }

    // Pad remainder with test pattern
    final remaining = sizeBytes - bytes.length;
    if (remaining > 0) {
      final chunk = List<int>.generate(
        math.min(remaining, 4096),
        (i) => (i * 31) % 256,
      );
      var written = 0;
      while (written < remaining) {
        final toWrite = math.min(chunk.length, remaining - written);
        bytes.add(chunk.sublist(0, toWrite));
        written += toWrite;
      }
    }

    await file.writeAsBytes(bytes.toBytes(), flush: true);
    return file;
  }

  /// Synthesize a SubRip (.srt) subtitle fixture with timestamped cues.
  Future<File> createMockSubtitleSrt(
    Directory dir,
    String filename, {
    List<Map<String, String>>? cues,
  }) async {
    final file = File('${dir.path}/$filename');
    final buffer = StringBuffer();

    final actualCues = cues ?? [
      {
        'index': '1',
        'start': '00:00:01,000',
        'end': '00:00:04,500',
        'text': 'Welcome to E-Player Offline Engine.',
      },
      {
        'index': '2',
        'start': '00:00:05,000',
        'end': '00:00:09,000',
        'text': 'Hardware-accelerated zero-copy playback.',
      },
    ];

    for (final cue in actualCues) {
      buffer.writeln(cue['index']);
      buffer.writeln('${cue['start']} --> ${cue['end']}');
      buffer.writeln(cue['text']);
      buffer.writeln();
    }

    await file.writeAsString(buffer.toString(), flush: true);
    return file;
  }

  /// Synthesize a WebVTT (.vtt) subtitle fixture with timestamped cues.
  Future<File> createMockSubtitleVtt(
    Directory dir,
    String filename, {
    List<Map<String, String>>? cues,
  }) async {
    final file = File('${dir.path}/$filename');
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();

    final actualCues = cues ?? [
      {
        'start': '00:00:01.000',
        'end': '00:00:04.500',
        'text': 'E-Player Tokenized WebVTT Sidecar.',
      },
      {
        'start': '00:00:05.000',
        'end': '00:00:09.000',
        'text': 'High-fidelity offline subtitle streaming.',
      },
    ];

    for (var i = 0; i < actualCues.length; i++) {
      final cue = actualCues[i];
      buffer.writeln('${i + 1}');
      buffer.writeln('${cue['start']} --> ${cue['end']}');
      buffer.writeln(cue['text']);
      buffer.writeln();
    }

    await file.writeAsString(buffer.toString(), flush: true);
    return file;
  }

  /// Spawn an ephemeral mock-free HTTP Range Server on loopback for casting tests.
  Future<EphemeralCastServer> startEphemeralCastServer({
    String sessionToken = 'ep_token_a1b2c3d4e5f60718293a4b5c6d7e8f90',
    List<int>? mediaBytes,
    String? vttContent,
  }) async {
    final actualMedia = mediaBytes ?? List<int>.generate(128 * 1024, (i) => i % 256);
    final actualVtt = vttContent ?? "WEBVTT\n\n00:00:01.000 --> 00:00:04.000\nCast Subtitle Track\n";

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    final castServer = EphemeralCastServer(
      server: server,
      sessionToken: sessionToken,
      mediaBytes: actualMedia,
      vttContent: actualVtt,
    );

    server.listen((HttpRequest request) async {
      castServer.requestLog.add('${request.method} ${request.uri.path}');

      final path = request.uri.path;
      final segments = request.uri.pathSegments;

      // 1. Token validation: must match /cast/{sessionToken}/...
      if (segments.length < 2 || segments[0] != 'cast' || segments[1] != sessionToken) {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.write('403 Forbidden: Invalid or missing session token');
        await request.response.close();
        return;
      }

      // 2. Reject path traversal
      if (path.contains('..')) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('400 Bad Request');
        await request.response.close();
        return;
      }

      // 3. Subtitles endpoint: /cast/{token}/subtitles/{id}.vtt
      if (segments.length >= 4 && segments[2] == 'subtitles') {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType('text', 'vtt', charset: 'utf-8');
        request.response.headers.set('Cache-Control', 'no-cache');
        request.response.write(actualVtt);
        await request.response.close();
        return;
      }

      // 4. Video stream endpoint with HTTP 206 Range support: /cast/{token}/stream
      if (segments.length >= 3 && segments[2] == 'stream') {
        final totalSize = actualMedia.length;
        final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

        if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
          final rangeSpec = rangeHeader.substring(6).trim();
          final parts = rangeSpec.split('-');
          int start = 0;
          int end = totalSize - 1;

          if (parts.length == 2) {
            if (parts[0].isNotEmpty) {
              start = int.tryParse(parts[0]) ?? 0;
            }
            if (parts[1].isNotEmpty) {
              end = int.tryParse(parts[1]) ?? totalSize - 1;
            }
          }

          if (start > end || start >= totalSize || end >= totalSize) {
            request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
            request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$totalSize');
            await request.response.close();
            return;
          }

          final contentLength = end - start + 1;
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalSize');
          request.response.headers.contentLength = contentLength;
          request.response.headers.contentType = ContentType('video', 'mp4');

          final slice = actualMedia.sublist(start, end + 1);
          request.response.add(slice);
          await request.response.close();
          return;
        } else {
          // Full content (200 OK)
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentLength = totalSize;
          request.response.headers.contentType = ContentType('video', 'mp4');
          request.response.add(actualMedia);
          await request.response.close();
          return;
        }
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    _servers.add(castServer);
    return castServer;
  }

  /// Wrap child widget in comprehensive application providers with EPlayerTheme.
  Widget wrapWithAppProviders(
    Widget child, {
    LibraryProvider? libraryProvider,
    SettingsProvider? settingsProvider,
    CastService? castService,
    MediaGroupService? mediaGroupService,
    ExportService? exportService,
    VaultService? vaultService,
    TrashService? trashService,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LibraryProvider>(create: (_) => libraryProvider ?? LibraryProvider()),
        ChangeNotifierProvider<SettingsProvider>(create: (_) => settingsProvider ?? SettingsProvider()),
        ChangeNotifierProvider<CastService>(create: (_) => castService ?? CastService()),
        ChangeNotifierProvider<MediaGroupService>(create: (_) => mediaGroupService ?? MediaGroupService()),
        ChangeNotifierProvider<ExportService>(create: (_) => exportService ?? ExportService()),
        ChangeNotifierProvider<VaultService>(create: (_) => vaultService ?? VaultService()),
        ChangeNotifierProvider<TrashService>(create: (_) => trashService ?? TrashService()),
      ],
      child: MaterialApp(
        theme: EPlayerTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: child),
      ),
    );
  }

  /// Clean up all temporary files and close servers.
  Future<void> tearDown() async {
    for (final s in _servers) {
      await s.close();
    }
    _servers.clear();

    for (final dir in _tempDirs) {
      if (dir.existsSync()) {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
    _tempDirs.clear();
  }

  /// Full teardown unbinding platform mock handlers.
  Future<void> tearDownAll() async {
    await tearDown();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(brightnessChannel, null);
    messenger.setMockMethodCallHandler(pipChannel, null);
    messenger.setMockMethodCallHandler(scannerChannel, null);
    platformCalls.clear();
  }
}

/// Pure mathematical and invariant validators for opaque-box test evaluation.
class GestureArbitratorMath {
  static const double deadZoneThreshold = 12.0;
  static const double dominantRatio = 1.5;

  static bool hasExceededDeadZone(double dx, double dy) {
    return math.sqrt(dx * dx + dy * dy) >= deadZoneThreshold;
  }

  static bool isHorizontalDominant(double dx, double dy) {
    return dx.abs() >= (dominantRatio * dy.abs());
  }

  static bool isVerticalDominant(double dx, double dy) {
    return dy.abs() >= (dominantRatio * dx.abs());
  }

  static double clampScale(double scale) {
    return scale.clamp(1.0, 4.0);
  }

  static Offset clampPanOffset(Offset offset, double scale, Size viewportSize) {
    if (scale <= 1.0) return Offset.zero;
    final maxTx = (scale - 1.0) * viewportSize.width / 2.0;
    final maxTy = (scale - 1.0) * viewportSize.height / 2.0;
    return Offset(
      offset.dx.clamp(-maxTx, maxTx),
      offset.dy.clamp(-maxTy, maxTy),
    );
  }

  static double clampVolume(double volume) {
    return volume.clamp(0.0, 100.0);
  }

  static double clampBrightness(double brightness) {
    return brightness.clamp(0.0, 1.0);
  }

  static Duration clampDuration(Duration target, Duration total) {
    if (target < Duration.zero) return Duration.zero;
    if (target > total) return total;
    return target;
  }
}

/// Pure mathematical and rational bounds validators for Picture-in-Picture.
class PipMath {
  static const double minAspectRatio = 1.0 / 2.39; // ~0.4184
  static const double maxAspectRatio = 2.39 / 1.0; // 2.39

  static double calculateAspectRatio(int width, int height) {
    if (height <= 0 || width <= 0) return 16.0 / 9.0;
    final rawRatio = width / height;
    return rawRatio.clamp(minAspectRatio, maxAspectRatio);
  }

  static bool canAutoEnter(bool isPlaying) {
    return isPlaying;
  }
}

/// Pure mode mapping and fallback cascade validators for Phase 1 Hardware Decoders.
class DecoderModeValidator {
  static String mapModeToHwdec(String mode) {
    switch (mode) {
      case 'HW':
        return 'yes';
      case 'HW+':
        return 'auto-copy';
      case 'SW':
        return 'no';
      case 'Auto':
      default:
        return 'auto';
    }
  }

  static bool shouldTriggerFallback({required int droppedFrames, required Duration window}) {
    return droppedFrames > 10 && window <= const Duration(seconds: 2);
  }

  static String getNextFallbackMode(String currentMode) {
    switch (currentMode) {
      case 'HW':
        return 'HW+';
      case 'HW+':
        return 'SW';
      case 'SW':
        return 'SW';
      case 'Auto':
      default:
        return 'HW+';
    }
  }
}

/// Pure offline and security validators for Phase 11 Tokenized Wireless Casting.
class OfflineSecurityValidator {
  static bool isStrictlyOfflineUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1') return true;
    if (host.startsWith('192.168.')) return true;
    if (host.startsWith('10.')) return true;
    if (host.startsWith('172.')) {
      final parts = host.split('.');
      if (parts.length >= 2) {
        final secondOctet = int.tryParse(parts[1]) ?? 0;
        if (secondOctet >= 16 && secondOctet <= 31) return true;
      }
    }
    return false;
  }

  static bool isSessionTokenValid(String token) {
    if (token.length != 32) return false;
    final validChars = RegExp(r'^[a-zA-Z0-9_-]+$');
    return validChars.hasMatch(token);
  }
}
