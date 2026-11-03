import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;

import 'cast_models.dart';

/// Phase 11: Tokenized Wireless Casting & Local Streaming Daemon.
/// Binds an ephemeral HTTP server to a private LAN or loopback interface,
/// enforcing tokenized security, path traversal prevention, HTTP 206 Partial
/// Content Range serving, WebVTT subtitle sidecar delivery, and telemetry streaming.
class LocalStreamingDaemon {
  HttpServer? _server;
  String? _sessionToken;
  String? _filePath;
  String? _subtitlePath;
  String? _convertedVttContent;
  InternetAddress? _boundAddress;
  int? _boundPort;

  final StreamController<StreamingClientTelemetry> _telemetryController =
      StreamController<StreamingClientTelemetry>.broadcast();

  bool get isRunning => _server != null;
  String? get sessionToken => _sessionToken;
  int? get port => _boundPort;
  String? get host => _boundAddress?.address;
  InternetAddress? get address => _boundAddress;
  String? get filePath => _filePath;
  String? get subtitlePath => _subtitlePath;

  String? get baseUrl => isRunning
      ? 'http://${_boundAddress!.address}:$_boundPort/cast/$_sessionToken/'
      : null;

  String? get streamUrl => isRunning
      ? 'http://${_boundAddress!.address}:$_boundPort/cast/$_sessionToken/stream'
      : null;

  String? get subtitleUrl => isRunning
      ? 'http://${_boundAddress!.address}:$_boundPort/cast/$_sessionToken/subtitles/track_0.vtt'
      : null;

  Stream<StreamingClientTelemetry> get telemetryStream =>
      _telemetryController.stream;

  Stream<StreamingClientTelemetry> get telemetry =>
      _telemetryController.stream;

  /// Generate a cryptographically secure 32-character hexadecimal token.
  static String generateSessionToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Validates whether an IP address belongs to an offline private LAN or loopback subnet.
  static bool isPrivateLanIp(String ip) {
    final clean = ip.trim().toLowerCase();
    if (clean == '127.0.0.1' || clean == 'localhost' || clean == '::1') {
      return true;
    }
    if (clean.startsWith('192.168.')) return true;
    if (clean.startsWith('10.')) return true;
    if (clean.startsWith('172.')) {
      final parts = clean.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]) ?? 0;
        if (second >= 16 && second <= 31) return true;
      }
    }
    return false;
  }

  /// Converts SubRip (.srt) subtitle text to standard WebVTT format on-the-fly.
  static String convertSrtToVtt(String srtContent) {
    final trimmed = srtContent.trimLeft();
    if (trimmed.startsWith('WEBVTT')) {
      return srtContent;
    }
    final normalized = srtContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final buffer = StringBuffer('WEBVTT\n\n');
    final timecodeRegex = RegExp(
      r'(\d{2}:\d{2}:\d{2}),(\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}),(\d{3})',
    );

    for (final line in lines) {
      final match = timecodeRegex.firstMatch(line);
      if (match != null) {
        buffer.writeln(
          '${match.group(1)}.${match.group(2)} --> ${match.group(3)}.${match.group(4)}',
        );
      } else {
        buffer.writeln(line);
      }
    }
    return buffer.toString();
  }

  /// Resolves the optimal offline private network interface or falls back to loopback.
  static Future<InternetAddress> resolveBindAddress({
    InternetAddress? preferredAddress,
  }) async {
    if (preferredAddress != null) {
      if (preferredAddress.isLoopback || isPrivateLanIp(preferredAddress.address)) {
        return preferredAddress;
      }
    }

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && isPrivateLanIp(addr.address)) {
            return addr;
          }
        }
      }
    } catch (_) {
      // Sandboxed or offline environments without active network interfaces
    }

    return InternetAddress.loopbackIPv4;
  }

  static ContentType _resolveContentType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.mp4':
      case '.m4v':
        return ContentType('video', 'mp4');
      case '.mkv':
        return ContentType('video', 'x-matroska');
      case '.webm':
        return ContentType('video', 'webm');
      case '.avi':
        return ContentType('video', 'x-msvideo');
      case '.mov':
        return ContentType('video', 'quicktime');
      case '.ts':
        return ContentType('video', 'mp2t');
      default:
        return ContentType('video', 'mp4');
    }
  }

  /// Start a new tokenized streaming session.
  /// Binds HttpServer to local interface and returns the base URL:
  /// `http://{local_ip}:{port}/cast/{session_token}/`
  Future<String> startSession({
    required String filePath,
    String? subtitlePath,
    InternetAddress? bindAddress,
    int port = 0,
    String? customToken,
  }) async {
    if (isRunning) {
      await stopSession();
    }

    final targetAddress = await resolveBindAddress(preferredAddress: bindAddress);
    _sessionToken = customToken ?? generateSessionToken();
    _filePath = filePath;
    _subtitlePath = subtitlePath;

    // Load and convert subtitle sidecar if present
    if (subtitlePath != null && subtitlePath.isNotEmpty) {
      final subFile = File(subtitlePath);
      if (await subFile.exists()) {
        try {
          final raw = await subFile.readAsString();
          _convertedVttContent = convertSrtToVtt(raw);
        } catch (_) {
          final rawBytes = await subFile.readAsBytes();
          final raw = utf8.decode(rawBytes, allowMalformed: true);
          _convertedVttContent = convertSrtToVtt(raw);
        }
      } else {
        _convertedVttContent = "WEBVTT\n\n";
      }
    } else {
      _convertedVttContent = "WEBVTT\n\n";
    }

    _server = await HttpServer.bind(targetAddress, port);
    _boundAddress = _server!.address;
    _boundPort = _server!.port;

    _server!.listen(_handleRequest);

    return baseUrl!;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final stopwatch = Stopwatch()..start();
    int bytesSent = 0;
    int responseStatus = HttpStatus.ok;
    final path = request.uri.path;
    final decodedPath = Uri.decodeComponent(path);
    final segments = request.uri.pathSegments;
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    final clientIp = request.connectionInfo?.remoteAddress.address ?? '127.0.0.1';

    void recordTelemetry() {
      stopwatch.stop();
      if (!_telemetryController.isClosed) {
        _telemetryController.add(StreamingClientTelemetry(
          clientIp: clientIp,
          path: path,
          statusCode: responseStatus,
          bytesTransferred: bytesSent,
          duration: stopwatch.elapsed,
          timestamp: DateTime.now(),
          rangeHeader: rangeHeader,
        ));
      }
    }

    try {
      // 1. Path traversal check: reject any attempt to traverse directories
      if (path.contains('..') ||
          decodedPath.contains('..') ||
          request.requestedUri.toString().contains('..')) {
        responseStatus = HttpStatus.badRequest;
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType =
            ContentType('text', 'plain', charset: 'utf-8');
        request.response.write('400 Bad Request: Path traversal rejected');
        await request.response.close();
        recordTelemetry();
        return;
      }

      // 2. Token validation: must match /cast/{sessionToken}/...
      if (segments.length < 2 ||
          segments[0] != 'cast' ||
          segments[1] != _sessionToken) {
        responseStatus = HttpStatus.forbidden;
        request.response.statusCode = HttpStatus.forbidden;
        request.response.headers.contentType =
            ContentType('text', 'plain', charset: 'utf-8');
        request.response.write('403 Forbidden: Invalid or missing session token');
        await request.response.close();
        recordTelemetry();
        return;
      }

      // 3. Subtitles endpoint: /cast/{token}/subtitles/{track_id}.vtt
      if (segments.length >= 3 && segments[2] == 'subtitles') {
        responseStatus = HttpStatus.ok;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType =
            ContentType('text', 'vtt', charset: 'utf-8');
        request.response.headers.set('Cache-Control', 'no-cache');
        final body = _convertedVttContent ?? "WEBVTT\n\n";
        final encoded = utf8.encode(body);
        bytesSent = encoded.length;
        request.response.add(encoded);
        await request.response.close();
        recordTelemetry();
        return;
      }

      // 4. Video stream endpoint with HTTP 206 Partial Content Range: /cast/{token}/stream
      if (segments.length >= 3 && segments[2] == 'stream') {
        if (_filePath == null) {
          responseStatus = HttpStatus.notFound;
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          recordTelemetry();
          return;
        }

        final file = File(_filePath!);
        if (!await file.exists()) {
          responseStatus = HttpStatus.notFound;
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          recordTelemetry();
          return;
        }

        final totalSize = await file.length();
        final contentType = _resolveContentType(_filePath!);
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
              end = int.tryParse(parts[1]) ?? (totalSize - 1);
            }
          }

          if (start > end || start >= totalSize || end >= totalSize || start < 0) {
            responseStatus = HttpStatus.requestedRangeNotSatisfiable;
            request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
            request.response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes */$totalSize',
            );
            await request.response.close();
            recordTelemetry();
            return;
          }

          final contentLength = end - start + 1;
          responseStatus = HttpStatus.partialContent;
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/$totalSize',
          );
          request.response.headers.contentLength = contentLength;
          request.response.headers.contentType = contentType;

          bytesSent = contentLength;
          await request.response.addStream(file.openRead(start, end + 1));
          await request.response.close();
          recordTelemetry();
          return;
        } else {
          // Full content (200 OK)
          responseStatus = HttpStatus.ok;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentLength = totalSize;
          request.response.headers.contentType = contentType;
          bytesSent = totalSize;
          await request.response.addStream(file.openRead());
          await request.response.close();
          recordTelemetry();
          return;
        }
      }

      // Default: Not found
      responseStatus = HttpStatus.notFound;
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      recordTelemetry();
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
      recordTelemetry();
    }
  }

  /// Terminates HTTP server, closes file streams, and clears session state.
  Future<void> stopSession() async {
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (_) {}
      _server = null;
    }
    _filePath = null;
    _subtitlePath = null;
    _convertedVttContent = null;
    _sessionToken = null;
    _boundAddress = null;
    _boundPort = null;
  }

  /// Cleanly disposes daemon resources and telemetry controller.
  Future<void> dispose() async {
    await stopSession();
    if (!_telemetryController.isClosed) {
      await _telemetryController.close();
    }
  }
}
