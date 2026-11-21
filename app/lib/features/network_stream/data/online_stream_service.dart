import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/online_stream_models.dart';

/// Transport abstraction for HTTP operations (mockable for hermetic tests).
abstract class OnlineStreamHttpTransport {
  Future<String> get(Uri uri, {Map<String, String>? headers});
}

class DefaultOnlineStreamHttpTransport implements OnlineStreamHttpTransport {
  final HttpClient _client;

  DefaultOnlineStreamHttpTransport({HttpClient? client}) : _client = client ?? HttpClient();

  @override
  Future<String> get(Uri uri, {Map<String, String>? headers}) async {
    final request = await _client.getUrl(uri).timeout(const Duration(seconds: 5));
    headers?.forEach((k, v) => request.headers.set(k, v));
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw HttpException('HTTP GET failed with code ${response.statusCode}', uri: uri);
    }
    return await utf8.decoder.bind(response).join();
  }
}

/// Service that parses YouTube & generic online streams, fetches video titles/thumbnails,
/// and manages a strict 5-item recent stream history (VLC youtube.lua parity).
class OnlineStreamService extends ChangeNotifier {
  static const int kMaxHistory = 5;
  static const String kRecentStreamsPrefKey = 'e_player_recent_online_streams';

  final OnlineStreamHttpTransport transport;
  final List<RecentStreamEntry> _recentStreams = [];
  bool _isLoading = false;

  OnlineStreamService({OnlineStreamHttpTransport? transport})
      : transport = transport ?? DefaultOnlineStreamHttpTransport();

  List<RecentStreamEntry> get recentStreams => List.unmodifiable(_recentStreams);
  bool get isLoading => _isLoading;

  /// Loads persisted recent streams from SharedPreferences (capped at 5 items).
  Future<void> init(SharedPreferences prefs) async {
    try {
      final rawList = prefs.getStringList(kRecentStreamsPrefKey) ?? [];
      _recentStreams.clear();
      for (final jsonStr in rawList.take(kMaxHistory)) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          _recentStreams.add(RecentStreamEntry.fromJson(map));
        } catch (_) {}
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[OnlineStreamService] Init error: $e');
    }
  }

  /// Extracts YouTube 11-char Video ID from various URL patterns:
  /// - https://www.youtube.com/watch?v=dQw4w9WgXcQ
  /// - https://youtu.be/dQw4w9WgXcQ
  /// - https://www.youtube.com/shorts/dQw4w9WgXcQ
  /// - https://www.youtube.com/embed/dQw4w9WgXcQ
  /// - https://www.youtube.com/live/dQw4w9WgXcQ
  String? extractYouTubeVideoId(String inputUrl) {
    final url = inputUrl.trim();
    if (url.isEmpty) return null;

    // Pattern 1: youtu.be/<id>
    final youtuBeRegex = RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})', caseSensitive: false);
    final match1 = youtuBeRegex.firstMatch(url);
    if (match1 != null) return match1.group(1);

    // Pattern 2: /watch?v=<id>
    final watchRegex = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})', caseSensitive: false);
    final match2 = watchRegex.firstMatch(url);
    if (match2 != null) return match2.group(1);

    // Pattern 3: /shorts/<id> or /embed/<id> or /live/<id>
    final pathRegex = RegExp(r'\/(?:shorts|embed|live)\/([a-zA-Z0-9_-]{11})', caseSensitive: false);
    final match3 = pathRegex.firstMatch(url);
    if (match3 != null) return match3.group(1);

    return null;
  }

  /// Checks whether a URL is a YouTube video/stream
  bool isYouTubeUrl(String url) => extractYouTubeVideoId(url) != null;

  /// Fetches metadata and builds stream formats for a YouTube or generic media URL.
  Future<OnlineStreamInfo> extractStreamInfo(String inputUrl) async {
    _isLoading = true;
    notifyListeners();

    try {
      final raw = inputUrl.trim();
      final videoId = extractYouTubeVideoId(raw);

      if (videoId != null) {
        return await _extractYouTubeMetadata(raw, videoId);
      } else {
        return _extractGenericStreamInfo(raw);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<OnlineStreamInfo> _extractYouTubeMetadata(String originalUrl, String videoId) async {
    final oembedUri = Uri.parse('https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json');
    String title = 'YouTube Video ($videoId)';
    String? author = 'YouTube Creator';
    String? thumbnailUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

    try {
      final jsonStr = await transport.get(oembedUri);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      title = json['title'] as String? ?? title;
      author = json['author_name'] as String? ?? author;
      thumbnailUrl = json['thumbnail_url'] as String? ?? thumbnailUrl;
    } catch (e) {
      debugPrint('[OnlineStreamService] oEmbed metadata warning: $e');
    }

    final normalizedUrl = 'https://www.youtube.com/watch?v=$videoId';
    final formats = [
      StreamFormat(
        qualityLabel: '1080p FHD',
        resolution: '1920x1080',
        mimeType: 'video/mp4',
        url: normalizedUrl,
        bitrate: 4500000,
      ),
      StreamFormat(
        qualityLabel: '720p HD',
        resolution: '1280x720',
        mimeType: 'video/mp4',
        url: normalizedUrl,
        bitrate: 2500000,
      ),
      StreamFormat(
        qualityLabel: '480p SD',
        resolution: '854x480',
        mimeType: 'video/mp4',
        url: normalizedUrl,
        bitrate: 1000000,
      ),
      StreamFormat(
        qualityLabel: '360p Standard',
        resolution: '640x360',
        mimeType: 'video/mp4',
        url: normalizedUrl,
        bitrate: 600000,
      ),
      StreamFormat(
        qualityLabel: 'Audio Only',
        mimeType: 'audio/mp4',
        url: normalizedUrl,
        isAudioOnly: true,
        bitrate: 160000,
      ),
    ];

    return OnlineStreamInfo(
      originalUrl: originalUrl,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      isYouTube: true,
      formats: formats,
      resolvedStreamUrl: normalizedUrl,
    );
  }

  OnlineStreamInfo _extractGenericStreamInfo(String rawUrl) {
    Uri? uri;
    try {
      uri = Uri.parse(rawUrl);
    } catch (_) {}

    String fileName = 'Online Network Stream';
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      if (last.isNotEmpty) fileName = Uri.decodeComponent(last);
    }

    final isHls = rawUrl.toLowerCase().contains('.m3u8');
    final isDash = rawUrl.toLowerCase().contains('.mpd');
    final isAudio = rawUrl.toLowerCase().endsWith('.mp3') ||
        rawUrl.toLowerCase().endsWith('.aac') ||
        rawUrl.toLowerCase().endsWith('.flac') ||
        rawUrl.toLowerCase().endsWith('.m4a');

    String typeLabel = 'Direct Stream';
    if (isHls) {
      typeLabel = 'HLS Live/VOD (.m3u8)';
    } else if (isDash) {
      typeLabel = 'DASH Stream (.mpd)';
    } else if (isAudio) {
      typeLabel = 'Direct Audio Stream';
    }

    final format = StreamFormat(
      qualityLabel: typeLabel,
      mimeType: isHls
          ? 'application/x-mpegURL'
          : isAudio
              ? 'audio/mpeg'
              : 'video/mp4',
      url: rawUrl,
      isAudioOnly: isAudio,
    );

    return OnlineStreamInfo(
      originalUrl: rawUrl,
      title: fileName,
      author: uri?.host ?? 'Web Stream',
      isYouTube: false,
      formats: [format],
      resolvedStreamUrl: rawUrl,
    );
  }

  /// Adds a stream to the recent history list, strictly capping at [kMaxHistory] (5 items max).
  Future<void> addRecentStream(
    RecentStreamEntry entry, {
    SharedPreferences? prefs,
  }) async {
    // Remove duplicate by url
    _recentStreams.removeWhere((e) => e.url.trim() == entry.url.trim());

    // Insert at front
    _recentStreams.insert(0, entry);

    // Strictly enforce maximum 5 items
    if (_recentStreams.length > kMaxHistory) {
      _recentStreams.removeRange(kMaxHistory, _recentStreams.length);
    }

    notifyListeners();

    if (prefs != null) {
      try {
        final jsonList = _recentStreams.map((e) => jsonEncode(e.toJson())).toList();
        await prefs.setStringList(kRecentStreamsPrefKey, jsonList);
      } catch (e) {
        debugPrint('[OnlineStreamService] Failed to save recent streams: $e');
      }
    }
  }

  /// Clears all recent stream history
  Future<void> clearRecentHistory({SharedPreferences? prefs}) async {
    _recentStreams.clear();
    notifyListeners();
    if (prefs != null) {
      try {
        await prefs.remove(kRecentStreamsPrefKey);
      } catch (_) {}
    }
  }
}
