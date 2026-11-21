import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/models/media_item.dart';

/// Pure Dart serializer and parser for VLC-compatible playlist files (.m3u, .m3u8, .xspf).
/// Implements RFC 8216 Extended M3U and XSPF XML Shareable Playlist Format specifications.
class PlaylistSerializer {
  /// Serializes a list of [MediaItem] objects into Extended M3U/M3U8 format.
  static String serializeM3u8(List<MediaItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    for (final item in items) {
      final seconds = item.durationMs > 0 ? (item.durationMs / 1000).round() : -1;
      buffer.writeln('#EXTINF:$seconds,${item.name}');
      buffer.writeln(item.path);
    }
    return buffer.toString();
  }

  /// Serializes a list of [MediaItem] objects into XSPF XML format.
  static String serializeXspf(
    List<MediaItem> items, {
    String title = 'E-Player Playlist',
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<playlist version="1" xmlns="http://xspf.org/ns/0/">');
    buffer.writeln('  <title>${_escapeXml(title)}</title>');
    buffer.writeln('  <trackList>');
    for (final item in items) {
      buffer.writeln('    <track>');
      final loc = item.path.startsWith('http') || item.path.startsWith('file:')
          ? item.path
          : Uri.file(item.path).toString();
      buffer.writeln('      <location>${_escapeXml(loc)}</location>');
      buffer.writeln('      <title>${_escapeXml(item.name)}</title>');
      if (item.durationMs > 0) {
        buffer.writeln('      <duration>${item.durationMs}</duration>');
      }
      buffer.writeln('    </track>');
    }
    buffer.writeln('  </trackList>');
    buffer.writeln('</playlist>');
    return buffer.toString();
  }

  /// Parses an M3U or M3U8 string into a list of [MediaItem] objects.
  /// Resolves relative paths using [baseDir] when provided.
  static List<MediaItem> parseM3u(String content, {String? baseDir}) {
    final items = <MediaItem>[];
    final lines = content.split(RegExp(r'\r?\n'));
    String? currentTitle;
    int currentDurationMs = 0;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final colonIdx = line.indexOf(':');
        final commaIdx = line.indexOf(',');
        if (commaIdx > colonIdx) {
          final durStr = line.substring(colonIdx + 1, commaIdx).trim();
          final titleStr = line.substring(commaIdx + 1).trim();
          final seconds = int.tryParse(durStr) ?? 0;
          currentDurationMs = seconds > 0 ? seconds * 1000 : 0;
          currentTitle = titleStr.isNotEmpty ? titleStr : null;
        }
        continue;
      }

      if (line.startsWith('#')) {
        // Skip comment directives like #EXTM3U, #EXTVLCOPT
        continue;
      }

      // Media line (file path or URL)
      String resolvedPath = line;
      if (!line.startsWith('http') && !line.startsWith('file:') && baseDir != null) {
        if (!p.isAbsolute(line)) {
          resolvedPath = p.normalize(p.join(baseDir, line));
        }
      }

      final fileName = p.basename(resolvedPath);
      final itemName = currentTitle ?? (fileName.isNotEmpty ? fileName : resolvedPath);
      final parentFolder = p.dirname(resolvedPath);

      items.add(MediaItem(
        path: resolvedPath,
        name: itemName,
        parentFolder: parentFolder,
        durationMs: currentDurationMs,
        lastPlayed: DateTime.now(),
      ));

      currentTitle = null;
      currentDurationMs = 0;
    }
    return items;
  }

  /// Parses an XSPF XML playlist string into a list of [MediaItem] objects.
  static List<MediaItem> parseXspf(String xmlContent) {
    final items = <MediaItem>[];
    final trackRegex = RegExp(r'<track>(.*?)</track>', caseSensitive: false, dotAll: true);

    String extractTag(String block, String tag) {
      final match = RegExp(
        '<$tag(?:\\s+[^>]*)?>(.*?)</$tag>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(block);
      return match?.group(1)?.trim() ?? '';
    }

    for (final match in trackRegex.allMatches(xmlContent)) {
      final block = match.group(1) ?? '';
      final rawLocation = _unescapeXml(extractTag(block, 'location'));
      final rawTitle = _unescapeXml(extractTag(block, 'title'));
      final rawDuration = extractTag(block, 'duration');

      if (rawLocation.isEmpty) continue;

      String path = rawLocation;
      if (rawLocation.startsWith('file://')) {
        try {
          final uri = Uri.parse(rawLocation);
          path = uri.toFilePath(windows: Platform.isWindows);
        } catch (_) {}
      }

      final fileName = p.basename(path);
      final name = rawTitle.isNotEmpty ? rawTitle : (fileName.isNotEmpty ? fileName : path);
      final durationMs = int.tryParse(rawDuration) ?? 0;

      items.add(MediaItem(
        path: path,
        name: name,
        parentFolder: p.dirname(path),
        durationMs: durationMs,
        lastPlayed: DateTime.now(),
      ));
    }
    return items;
  }

  /// Loads and parses a playlist file from disk based on file extension.
  static Future<List<MediaItem>> loadFromFile(File file) async {
    if (!file.existsSync()) return [];
    final content = await file.readAsString(encoding: utf8);
    final ext = p.extension(file.path).toLowerCase();

    if (ext == '.xspf') {
      return parseXspf(content);
    }
    return parseM3u(content, baseDir: file.parent.path);
  }

  /// Saves [items] to [targetPath] in M3U8 or XSPF format based on extension.
  static Future<File> saveToFile(
    List<MediaItem> items,
    String targetPath, {
    String title = 'E-Player Playlist',
  }) async {
    final file = File(targetPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final ext = p.extension(targetPath).toLowerCase();
    final serialized = ext == '.xspf'
        ? serializeXspf(items, title: title)
        : serializeM3u8(items);

    return file.writeAsString(serialized, encoding: utf8);
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _unescapeXml(String input) {
    return input
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }
}
