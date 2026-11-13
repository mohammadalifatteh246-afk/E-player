import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/network_share.dart';

/// Interface for custom network transport / directory fetcher.
abstract class NetworkMediaTransport {
  Future<String> fetchXml(Uri uri);
  Future<String> fetchSmbListing(NetworkShare share, String path);
}

/// Default implementation of NetworkMediaTransport using dart:io.
class DefaultNetworkMediaTransport implements NetworkMediaTransport {
  final HttpClient _httpClient;

  DefaultNetworkMediaTransport({HttpClient? client}) : _httpClient = client ?? HttpClient();

  @override
  Future<String> fetchXml(Uri uri) async {
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw HttpException('Failed to fetch UPnP XML descriptor', uri: uri);
    }
    return await utf8.decoder.bind(response).join();
  }

  @override
  Future<String> fetchSmbListing(NetworkShare share, String path) async {
    // In production desktop Flutter, SMB listings are resolved via libsmbclient FFI or smbclient CLI.
    // Default transport returns empty listing if no custom bridge is registered.
    return '';
  }
}

/// Service for discovering local network shares, parsing SMB/UPnP directories, and resolving media stream URLs.
class NetworkMediaService {
  final NetworkMediaTransport transport;
  final List<NetworkShare> _registeredShares = [];

  NetworkMediaService({NetworkMediaTransport? transport})
      : transport = transport ?? DefaultNetworkMediaTransport();

  List<NetworkShare> get registeredShares => List.unmodifiable(_registeredShares);

  void addShare(NetworkShare share) {
    if (!_registeredShares.any((s) => s.id == share.id)) {
      _registeredShares.add(share);
    }
  }

  void removeShare(String shareId) {
    _registeredShares.removeWhere((s) => s.id == shareId);
  }

  void clearShares() {
    _registeredShares.clear();
  }

  /// Parses UPnP / DLNA ContentDirectory DIDL-Lite XML into a list of [NetworkMediaItem].
  List<NetworkMediaItem> parseDidlLiteXml(
    String didlXml, {
    required String shareId,
    String parentPath = '',
    String? baseUrl,
  }) {
    final items = <NetworkMediaItem>[];
    if (didlXml.trim().isEmpty) return items;

    // Handle escaped XML within SOAP envelopes (<Result>&lt;DIDL-Lite...&gt;</Result>)
    var xml = didlXml;
    if (xml.contains('&lt;') && xml.contains('&gt;')) {
      xml = xml
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&');
    }

    // Parse <container ...> elements (folders/directories)
    final containerRegex = RegExp(
      r'<container\b([^>]*)>(.*?)</container>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in containerRegex.allMatches(xml)) {
      final attributes = match.group(1) ?? '';
      final body = match.group(2) ?? '';

      final id = _extractAttribute(attributes, 'id') ?? 'container_${items.length}';
      final title = _extractTagContent(body, 'dc:title') ?? _extractTagContent(body, 'title') ?? 'Folder';

      final cleanParent = parentPath.endsWith('/') ? parentPath : (parentPath.isEmpty ? '' : '$parentPath/');
      final path = '$cleanParent$title';

      items.add(NetworkMediaItem(
        id: id,
        shareId: shareId,
        title: title,
        path: path,
        streamUrl: '',
        isDirectory: true,
      ));
    }

    // Parse <item ...> elements (media files)
    final itemRegex = RegExp(
      r'<item\b([^>]*)>(.*?)</item>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in itemRegex.allMatches(xml)) {
      final attributes = match.group(1) ?? '';
      final body = match.group(2) ?? '';

      final id = _extractAttribute(attributes, 'id') ?? 'item_${items.length}';
      final title = _extractTagContent(body, 'dc:title') ?? _extractTagContent(body, 'title') ?? 'Media File';

      // Parse <res ...>URL</res>
      final resMatch = RegExp(r'<res\b([^>]*)>(.*?)</res>', caseSensitive: false, dotAll: true).firstMatch(body);
      String rawStreamUrl = '';
      int? sizeBytes;
      Duration? duration;
      String? mimeType;

      if (resMatch != null) {
        final resAttrs = resMatch.group(1) ?? '';
        rawStreamUrl = resMatch.group(2)?.trim() ?? '';

        final sizeStr = _extractAttribute(resAttrs, 'size');
        if (sizeStr != null) sizeBytes = int.tryParse(sizeStr);

        final durationStr = _extractAttribute(resAttrs, 'duration');
        if (durationStr != null) duration = parseUpnpDuration(durationStr);

        final protocolInfo = _extractAttribute(resAttrs, 'protocolInfo');
        if (protocolInfo != null) {
          final parts = protocolInfo.split(':');
          if (parts.length >= 3) {
            mimeType = parts[2];
          }
        }
      }

      var finalUrl = rawStreamUrl;
      if (baseUrl != null && baseUrl.isNotEmpty && !finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
        final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
        final cleanPath = finalUrl.startsWith('/') ? finalUrl : '/$finalUrl';
        finalUrl = '$cleanBase$cleanPath';
      }

      final cleanParent = parentPath.endsWith('/') ? parentPath : (parentPath.isEmpty ? '' : '$parentPath/');
      final path = '$cleanParent$title';

      items.add(NetworkMediaItem(
        id: id,
        shareId: shareId,
        title: title,
        path: path,
        streamUrl: finalUrl,
        isDirectory: false,
        sizeBytes: sizeBytes,
        duration: duration,
        mimeType: mimeType,
      ));
    }

    return items;
  }

  /// Parses SMB/CIFS directory listing lines into a list of [NetworkMediaItem].
  List<NetworkMediaItem> parseSmbDirectoryListing(
    String rawListing, {
    required NetworkShare share,
    String currentPath = '',
  }) {
    final items = <NetworkMediaItem>[];
    if (rawListing.trim().isEmpty) return items;

    final lines = LineSplitter.split(rawListing);
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      // Supported formats:
      // 1) D [DIR] FolderName
      // 2) F [1234567] Movie.mp4
      // 3) Standard smbclient listing: "  Movie.mkv                            A 104857600  Sun Nov 10 12:00:00 2026"
      if (line.startsWith('D\t') || line.startsWith('DIR:') || line.startsWith('D [DIR]')) {
        final name = line.replaceFirst(RegExp(r'^(D\t|DIR:|D \[DIR\])\s*'), '').trim();
        if (name == '.' || name == '..') continue;
        final fullPath = _combine(currentPath, name);
        items.add(NetworkMediaItem(
          id: '${share.id}:$fullPath',
          shareId: share.id,
          title: name,
          path: fullPath,
          streamUrl: '',
          isDirectory: true,
        ));
      } else if (line.startsWith('F\t') || line.startsWith('FILE:') || line.startsWith('F [')) {
        int? size;
        String name = line;
        final match = RegExp(r'^F\s*\[(?:FILE:)?(\d+)\]\s*(.*)$').firstMatch(line);
        if (match != null) {
          size = int.tryParse(match.group(1)!);
          name = match.group(2)!.trim();
        } else {
          name = line.replaceFirst(RegExp(r'^(F\t|FILE:)\s*'), '').trim();
        }

        final fullPath = _combine(currentPath, name);
        final streamUrl = resolveSmbStreamUrl(share, fullPath);

        items.add(NetworkMediaItem(
          id: '${share.id}:$fullPath',
          shareId: share.id,
          title: name,
          path: fullPath,
          streamUrl: streamUrl,
          isDirectory: false,
          sizeBytes: size,
        ));
      } else {
        // Fallback smbclient column format
        final isDir = line.contains(' D ') || line.endsWith(' D') || line.contains('<DIR>');
        final parts = line.split(RegExp(r'\s{2,}'));
        final name = parts.isNotEmpty ? parts.first.trim() : line;
        if (name == '.' || name == '..' || name.isEmpty) continue;

        int? size;
        for (final p in parts) {
          final s = int.tryParse(p);
          if (s != null && s > 0) {
            size = s;
            break;
          }
        }

        final fullPath = _combine(currentPath, name);
        items.add(NetworkMediaItem(
          id: '${share.id}:$fullPath',
          shareId: share.id,
          title: name,
          path: fullPath,
          streamUrl: isDir ? '' : resolveSmbStreamUrl(share, fullPath),
          isDirectory: isDir,
          sizeBytes: size,
        ));
      }
    }

    return items;
  }

  /// Resolves the streamable playback URL for any [NetworkMediaItem].
  String resolveStreamUrl(NetworkMediaItem item, {NetworkShare? share}) {
    if (item.streamUrl.isNotEmpty && !item.streamUrl.startsWith('smb://')) {
      return item.streamUrl;
    }

    final targetShare = share ?? _registeredShares.cast<NetworkShare?>().firstWhere(
      (s) => s?.id == item.shareId,
      orElse: () => null,
    );

    if (targetShare != null && targetShare.protocol == NetworkProtocol.smb) {
      return resolveSmbStreamUrl(targetShare, item.path);
    }

    return item.streamUrl;
  }

  /// Formats a complete authenticated SMB URL for mpv / libsmbclient.
  static String resolveSmbStreamUrl(NetworkShare share, String relativeFilePath) {
    String? userInfo;
    if (!share.isAnonymous && share.username != null && share.username!.isNotEmpty) {
      if (share.password != null && share.password!.isNotEmpty) {
        userInfo = '${Uri.encodeComponent(share.username!)}:${Uri.encodeComponent(share.password!)}';
      } else {
        userInfo = Uri.encodeComponent(share.username!);
      }
    }

    final fullPath = _combine(share.sharedPath, relativeFilePath);
    final cleanPath = fullPath.startsWith('/') ? fullPath : '/$fullPath';

    final uri = Uri(
      scheme: 'smb',
      userInfo: userInfo,
      host: share.host,
      port: share.port > 0 && share.port != 445 ? share.port : null,
      path: cleanPath,
    );

    return uri.toString();
  }

  /// Parses UPnP/DLNA duration string format `HH:MM:SS` or `HH:MM:SS.F` into [Duration].
  static Duration? parseUpnpDuration(String durationStr) {
    try {
      final parts = durationStr.trim().split(':');
      if (parts.length == 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        final secondsPart = parts[2].split('.');
        final seconds = int.tryParse(secondsPart[0]) ?? 0;
        int ms = 0;
        if (secondsPart.length > 1) {
          ms = int.tryParse(secondsPart[1].padRight(3, '0').substring(0, 3)) ?? 0;
        }
        return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: ms);
      }
    } catch (_) {}
    return null;
  }

  /// Browses a share directory at [subPath].
  Future<List<NetworkMediaItem>> browseShare(NetworkShare share, {String? subPath}) async {
    final targetPath = subPath ?? '';
    if (share.protocol == NetworkProtocol.smb) {
      final listing = await transport.fetchSmbListing(share, targetPath);
      return parseSmbDirectoryListing(listing, share: share, currentPath: targetPath);
    } else if (share.protocol == NetworkProtocol.upnpDlna) {
      final uri = share.toUri(subPath: targetPath);
      final xml = await transport.fetchXml(uri);
      return parseDidlLiteXml(
        xml,
        shareId: share.id,
        parentPath: targetPath,
        baseUrl: 'http://${share.host}:${share.port}',
      );
    } else {
      // Direct HTTP / WebDAV directory
      final uri = share.toUri(subPath: targetPath);
      return [
        NetworkMediaItem(
          id: '${share.id}:$targetPath',
          shareId: share.id,
          title: targetPath.isNotEmpty ? targetPath.split('/').last : share.name,
          path: targetPath,
          streamUrl: uri.toString(),
          isDirectory: false,
        )
      ];
    }
  }

  static String? _extractTagContent(String xml, String tagName) {
    final regex = RegExp('<$tagName\\b[^>]*>(.*?)</$tagName>', caseSensitive: false, dotAll: true);
    final match = regex.firstMatch(xml);
    return match?.group(1)?.trim();
  }

  static String? _extractAttribute(String attrString, String attrName) {
    final regex = RegExp('$attrName\\s*=\\s*["\']([^"\']*)["\']', caseSensitive: false);
    final match = regex.firstMatch(attrString);
    return match?.group(1);
  }

  static String _combine(String base, String sub) {
    if (base.isEmpty) return sub;
    if (sub.isEmpty) return base;
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanSub = sub.startsWith('/') ? sub.substring(1) : sub;
    return '$cleanBase/$cleanSub';
  }
}
