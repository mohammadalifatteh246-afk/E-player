library;

import 'dart:io';
import 'package:path/path.dart' as p;

/// Classification of an external launch target received via OS Intent or CLI.
enum ExternalMediaKind {
  videoAudio,
  subtitle,
  playlist,
  archive,
  networkStream,
  dvdFolder,
  unknown,
}

/// Strategy when an external video/audio file arrives while PlayerScreen is already playing.
enum WarmLaunchBehavior {
  playImmediately,
  enqueueToPlaylist,
}

/// Represents a normalized external file or URI launch request from OS shell / Android Intent.
class ExternalLaunchRequest {
  final String uri;
  final String displayName;
  final ExternalMediaKind kind;
  final String sourcePlatform;
  final List<String> extraUris;
  final String? mimeType;
  final DateTime receivedAt;

  ExternalLaunchRequest({
    required this.uri,
    required this.displayName,
    required this.kind,
    required this.sourcePlatform,
    this.extraUris = const [],
    this.mimeType,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  bool get isPlayable =>
      kind == ExternalMediaKind.videoAudio ||
      kind == ExternalMediaKind.playlist ||
      kind == ExternalMediaKind.archive ||
      kind == ExternalMediaKind.networkStream ||
      kind == ExternalMediaKind.dvdFolder;

  String get kindBadgeLabel {
    switch (kind) {
      case ExternalMediaKind.videoAudio:
        return 'MEDIA';
      case ExternalMediaKind.subtitle:
        return 'SUBTITLE';
      case ExternalMediaKind.playlist:
        return 'PLAYLIST';
      case ExternalMediaKind.archive:
        return 'ARCHIVE';
      case ExternalMediaKind.networkStream:
        return 'STREAM';
      case ExternalMediaKind.dvdFolder:
        return 'DISC';
      case ExternalMediaKind.unknown:
        return 'FILE';
    }
  }
}

/// Diagnostic snapshot shown in External Launch & OS Association Studio.
class OsIntegrationDiagnostics {
  final String platformName;
  final bool androidManifestIntentReady;
  final bool windowsCliArgsReady;
  final bool windowsSingleInstanceIpcReady;
  final bool windowsFileAssociationRegistered;
  final List<String> registeredExtensions;

  const OsIntegrationDiagnostics({
    required this.platformName,
    required this.androidManifestIntentReady,
    required this.windowsCliArgsReady,
    required this.windowsSingleInstanceIpcReady,
    required this.windowsFileAssociationRegistered,
    required this.registeredExtensions,
  });
}

/// Pure Dart parser and normalizer for Windows/Desktop CLI args and Android Intent URIs.
class ExternalLaunchParser {
  ExternalLaunchParser._();

  static const Set<String> videoAudioExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'webm', 'wmv', 'ts', 'm4v', '3gp',
    'mpg', 'mpeg', 'm2ts', 'mts', 'vob', 'divx', 'rmvb', 'asf', 'ogv',
    'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'wma', 'opus', 'alac', 'aiff',
  };

  static const Set<String> subtitleExtensions = {
    'srt', 'vtt', 'ass', 'ssa', 'sub', 'smi',
  };

  static const Set<String> playlistExtensions = {
    'm3u', 'm3u8', 'xspf', 'pls',
  };

  static const Set<String> archiveExtensions = {
    'zip', 'tar', 'gz', 'tgz',
  };

  static const Set<String> networkSchemes = {
    'http', 'https', 'rtsp', 'rtmp', 'rtsps', 'smb', 'mms', 'mmsh', 'ftp', 'udp', 'rtp',
  };

  static const List<String> associableExtensions = [
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.webm',
    '.wmv',
    '.flv',
    '.m4v',
    '.ts',
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
    '.opus',
    '.m3u',
    '.m3u8',
    '.xspf',
    '.pls',
  ];

  /// Strips quotes and converts `file://` URIs into OS filesystem paths.
  static String normalizeInputTarget(String raw, {bool? isWindowsOverride}) {
    var cleaned = raw.trim();
    if (cleaned.length >= 2 &&
        ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
            (cleaned.startsWith("'") && cleaned.endsWith("'")))) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    if (cleaned.isEmpty) return '';

    final lower = cleaned.toLowerCase();
    if (lower.startsWith('file://')) {
      try {
        final uri = Uri.parse(cleaned);
        return uri.toFilePath(windows: isWindowsOverride ?? Platform.isWindows);
      } catch (_) {
        // Fallback manual strip if malformed
        cleaned = cleaned.substring(7);
        if (RegExp(r'^/[A-Za-z]:').hasMatch(cleaned)) {
          cleaned = cleaned.substring(1);
        }
      }
    }
    return cleaned;
  }

  /// Extracts clean filename regardless of host OS path separators.
  static String extractDisplayName(String target, {String? explicitName}) {
    if (explicitName != null && explicitName.trim().isNotEmpty) {
      return explicitName.trim();
    }
    final lower = target.toLowerCase();
    if (networkSchemes.any((s) => lower.startsWith('$s://'))) {
      final parsed = Uri.tryParse(target);
      if (parsed != null && parsed.pathSegments.isNotEmpty) {
        final last = parsed.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
        if (last.isNotEmpty) return last;
      }
      return parsed?.host.isNotEmpty == true ? parsed!.host : target;
    }
    if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(target) || target.contains('\\')) {
      return p.windows.basename(target);
    }
    return p.basename(target);
  }

  /// Classifies a normalized target path or URI into an [ExternalMediaKind].
  static ExternalMediaKind classifyTarget(
    String normalizedTarget, {
    String? mimeType,
    String? displayName,
  }) {
    final trimmed = normalizedTarget.trim();
    if (trimmed.isEmpty) return ExternalMediaKind.unknown;

    final lower = trimmed.toLowerCase();

    // 1. Network stream schemes
    final colonIdx = lower.indexOf('://');
    if (colonIdx > 0) {
      final scheme = lower.substring(0, colonIdx);
      if (networkSchemes.contains(scheme)) {
        return ExternalMediaKind.networkStream;
      }
    }

    // 2. Check extension from displayName first (crucial for fdclose:// URIs), then target path
    final inspectName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : trimmed;
    final cleanInspect = inspectName.split('?').first.split('#').first;
    final dotIdx = cleanInspect.lastIndexOf('.');
    final ext = dotIdx >= 0 && dotIdx < cleanInspect.length - 1
        ? cleanInspect.substring(dotIdx + 1).toLowerCase()
        : '';

    if (cleanInspect.toLowerCase().endsWith('.tar.gz') ||
        archiveExtensions.contains(ext)) {
      return ExternalMediaKind.archive;
    }
    if (subtitleExtensions.contains(ext)) {
      return ExternalMediaKind.subtitle;
    }
    if (playlistExtensions.contains(ext)) {
      return ExternalMediaKind.playlist;
    }
    if (ext == 'iso' ||
        p.windows.basename(cleanInspect).toUpperCase() == 'VIDEO_TS' ||
        p.basename(cleanInspect).toUpperCase() == 'VIDEO_TS') {
      return ExternalMediaKind.dvdFolder;
    }
    if (videoAudioExtensions.contains(ext)) {
      return ExternalMediaKind.videoAudio;
    }

    // 3. MIME type fallback (e.g. Android scoped content:// without extension in name)
    if (mimeType != null && mimeType.isNotEmpty) {
      final m = mimeType.toLowerCase();
      if (m.startsWith('video/') || m.startsWith('audio/')) {
        return ExternalMediaKind.videoAudio;
      }
      if (m.contains('subrip') || m.contains('vtt') || m.contains('ssa') || m.contains('ass')) {
        return ExternalMediaKind.subtitle;
      }
      if (m.contains('mpegurl') || m.contains('xspf') || m.contains('scpls')) {
        return ExternalMediaKind.playlist;
      }
      if (m.contains('zip') || m.contains('tar') || m.contains('gzip')) {
        return ExternalMediaKind.archive;
      }
    }

    // 4. Android fdclose:// / content:// fallback defaults to media when dispatched by OS Intent filter
    if (lower.startsWith('fdclose://') ||
        lower.startsWith('fd://') ||
        lower.startsWith('content://')) {
      return ExternalMediaKind.videoAudio;
    }

    return ExternalMediaKind.unknown;
  }

  /// Parses CLI launch argument lists (`main(List<String> args)` or Windows `WM_COPYDATA`).
  static ExternalLaunchRequest? parseCliArgs(
    List<String> args, {
    String sourcePlatform = 'windows_cli',
    bool? isWindowsOverride,
  }) {
    if (args.isEmpty) return null;

    final candidates = <String>[];
    for (final raw in args) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      // Filter Flutter / Chromium / Dart VM flags like --enable-software-rendering, -d
      if (trimmed.startsWith('--') || trimmed.startsWith('-')) continue;
      final normalized =
          normalizeInputTarget(trimmed, isWindowsOverride: isWindowsOverride);
      if (normalized.isNotEmpty) {
        candidates.add(normalized);
      }
    }

    if (candidates.isEmpty) return null;

    // Prefer first non-subtitle playable item as primary target
    int primaryIdx = 0;
    for (int i = 0; i < candidates.length; i++) {
      final k = classifyTarget(candidates[i]);
      if (k != ExternalMediaKind.subtitle && k != ExternalMediaKind.unknown) {
        primaryIdx = i;
        break;
      }
    }

    final primary = candidates[primaryIdx];
    final extras = <String>[
      for (int i = 0; i < candidates.length; i++)
        if (i != primaryIdx) candidates[i],
    ];

    return ExternalLaunchRequest(
      uri: primary,
      displayName: extractDisplayName(primary),
      kind: classifyTarget(primary),
      sourcePlatform: sourcePlatform,
      extraUris: extras,
    );
  }

  /// Parses structured MethodChannel payloads emitted from Android `MainActivity` or Windows Runner.
  static ExternalLaunchRequest? fromPlatformPayload(
    Map<dynamic, dynamic>? payload, {
    bool? isWindowsOverride,
  }) {
    if (payload == null) return null;

    final rawArgs = payload['args'];
    if (rawArgs is List && rawArgs.isNotEmpty) {
      final strArgs = rawArgs.map((e) => e.toString()).toList();
      return parseCliArgs(
        strArgs,
        sourcePlatform:
            payload['source']?.toString() ?? 'windows_single_instance',
        isWindowsOverride: isWindowsOverride,
      );
    }

    final rawUri = payload['uri']?.toString() ?? '';
    final normalized =
        normalizeInputTarget(rawUri, isWindowsOverride: isWindowsOverride);
    if (normalized.isEmpty) return null;

    final displayName = payload['displayName']?.toString();
    final mimeType = payload['mimeType']?.toString();
    final source = payload['source']?.toString() ?? 'android_intent';
    final extraRaw = payload['extraUris'];
    final extras = extraRaw is List
        ? extraRaw
            .map((e) => normalizeInputTarget(
                  e.toString(),
                  isWindowsOverride: isWindowsOverride,
                ))
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];

    return ExternalLaunchRequest(
      uri: normalized,
      displayName: extractDisplayName(normalized, explicitName: displayName),
      kind: classifyTarget(
        normalized,
        mimeType: mimeType,
        displayName: displayName,
      ),
      sourcePlatform: source,
      extraUris: extras,
      mimeType: mimeType,
    );
  }
}
