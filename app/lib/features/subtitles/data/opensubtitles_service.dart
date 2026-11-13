import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/subtitle_result.dart';

/// Abstract HTTP client interface for OpenSubtitles REST operations.
abstract class SubtitlesHttpClient {
  Future<SubtitlesHttpResponse> get(Uri uri, {Map<String, String>? headers});
  Future<SubtitlesHttpResponse> post(Uri uri, {Map<String, String>? headers, String? body});
}

/// Standard response wrapper for OpenSubtitles HTTP calls.
class SubtitlesHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const SubtitlesHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Default production HTTP client using dart:io HttpClient.
class DefaultSubtitlesHttpClient implements SubtitlesHttpClient {
  final HttpClient _client;

  DefaultSubtitlesHttpClient({HttpClient? client}) : _client = client ?? HttpClient();

  @override
  Future<SubtitlesHttpResponse> get(Uri uri, {Map<String, String>? headers}) async {
    final request = await _client.getUrl(uri);
    headers?.forEach((key, value) {
      request.headers.set(key, value);
    });

    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name] = values.join(', ');
    });

    return SubtitlesHttpResponse(
      statusCode: response.statusCode,
      body: body,
      headers: responseHeaders,
    );
  }

  @override
  Future<SubtitlesHttpResponse> post(Uri uri, {Map<String, String>? headers, String? body}) async {
    final request = await _client.postUrl(uri);
    headers?.forEach((key, value) {
      request.headers.set(key, value);
    });

    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }

    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();

    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name] = values.join(', ');
    });

    return SubtitlesHttpResponse(
      statusCode: response.statusCode,
      body: responseBody,
      headers: responseHeaders,
    );
  }
}

/// Production OpenSubtitles REST Client & VLSub-parity Hash Search Service.
class OpenSubtitlesService {
  static const int kChunkSize = 65536; // 64 KB
  static const String kDefaultBaseUrl = 'https://api.opensubtitles.com/api/v1';
  static const String kDefaultUserAgent = 'E-Player v1.0.0';

  final String baseUrl;
  final String? apiKey;
  final String userAgent;
  final SubtitlesHttpClient httpClient;

  OpenSubtitlesService({
    this.baseUrl = kDefaultBaseUrl,
    this.apiKey,
    this.userAgent = kDefaultUserAgent,
    SubtitlesHttpClient? httpClient,
  }) : httpClient = httpClient ?? DefaultSubtitlesHttpClient();

  /// Computes the genuine OpenSubtitles 64-bit MovieHash from a video [File].
  ///
  /// The algorithm computes:
  /// Hash = FileSize + Sum(64-bit Little-Endian integers from the first 64KB)
  ///                 + Sum(64-bit Little-Endian integers from the last 64KB)
  /// with arithmetic wrapping at 2^64 (unsigned 64-bit integer), returned as
  /// a 16-character lowercase hexadecimal string.
  Future<MovieHashResult> computeMovieHash(File file) async {
    if (!file.existsSync()) {
      throw FileSystemException('Video file does not exist', file.path);
    }

    final raf = file.openSync(mode: FileMode.read);
    try {
      final fileSize = raf.lengthSync();
      if (fileSize == 0) {
        return const MovieHashResult(hash: '0000000000000000', byteSize: 0);
      }

      final mask64 = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);
      var hash = BigInt.from(fileSize).toUnsigned(64);

      if (fileSize < kChunkSize) {
        // For small files less than 64KB, read available bytes
        final buffer = Uint8List(fileSize);
        raf.setPositionSync(0);
        raf.readIntoSync(buffer);
        hash = _accumulateWords(hash, buffer, mask64);
      } else {
        // Read first 64 KB
        final headBuffer = Uint8List(kChunkSize);
        raf.setPositionSync(0);
        raf.readIntoSync(headBuffer);
        hash = _accumulateWords(hash, headBuffer, mask64);

        // Read last 64 KB
        final tailOffset = fileSize > kChunkSize ? fileSize - kChunkSize : 0;
        final tailBuffer = Uint8List(kChunkSize);
        raf.setPositionSync(tailOffset);
        raf.readIntoSync(tailBuffer);
        hash = _accumulateWords(hash, tailBuffer, mask64);
      }

      final hashHex = hash.toRadixString(16).padLeft(16, '0').toLowerCase();
      return MovieHashResult(hash: hashHex, byteSize: fileSize);
    } finally {
      raf.closeSync();
    }
  }

  /// Computes the OpenSubtitles MovieHash directly from a [Uint8List] memory buffer.
  MovieHashResult computeMovieHashFromBytes(Uint8List bytes) {
    final fileSize = bytes.length;
    if (fileSize == 0) {
      return const MovieHashResult(hash: '0000000000000000', byteSize: 0);
    }

    final mask64 = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);
    var hash = BigInt.from(fileSize).toUnsigned(64);

    if (fileSize < kChunkSize) {
      hash = _accumulateWords(hash, bytes, mask64);
    } else {
      // First 64 KB
      final head = Uint8List.view(bytes.buffer, bytes.offsetInBytes, kChunkSize);
      hash = _accumulateWords(hash, head, mask64);

      // Last 64 KB
      final tailOffset = fileSize - kChunkSize;
      final tail = Uint8List.view(bytes.buffer, bytes.offsetInBytes + tailOffset, kChunkSize);
      hash = _accumulateWords(hash, tail, mask64);
    }

    final hashHex = hash.toRadixString(16).padLeft(16, '0').toLowerCase();
    return MovieHashResult(hash: hashHex, byteSize: fileSize);
  }

  /// Helper to accumulate 64-bit little-endian integer words into [hash].
  static BigInt _accumulateWords(BigInt currentHash, Uint8List buffer, BigInt mask64) {
    final byteData = ByteData.view(buffer.buffer, buffer.offsetInBytes, buffer.lengthInBytes);
    var hash = currentHash;
    final count = buffer.lengthInBytes ~/ 8;

    for (var i = 0; i < count; i++) {
      final wordSigned = byteData.getInt64(i * 8, Endian.little);
      final wordUnsigned = BigInt.from(wordSigned).toUnsigned(64);
      hash = (hash + wordUnsigned) & mask64;
    }

    return hash;
  }

  /// Search for subtitles matching [movieHash] and [byteSize] (VLSub hash-matching mode).
  Future<List<SubtitleResult>> searchByHash({
    required String movieHash,
    required int byteSize,
    String? language,
  }) async {
    final queryParams = <String, String>{
      'moviehash': movieHash,
      if (byteSize > 0) 'moviebytesize': byteSize.toString(),
      if (language != null && language.isNotEmpty) 'languages': language,
    };

    final uri = Uri.parse('$baseUrl/subtitles').replace(queryParameters: queryParams);
    final response = await httpClient.get(uri, headers: _buildHeaders());

    if (!response.isSuccess) {
      throw HttpException(
        'OpenSubtitles searchByHash failed with status ${response.statusCode}: ${response.body}',
        uri: uri,
      );
    }

    return _parseSubtitlesList(response.body, matchedBy: 'hash');
  }

  /// Search for subtitles by text [query] (e.g. movie or show title).
  Future<List<SubtitleResult>> searchByQuery({
    required String query,
    String? language,
    int? seasonNumber,
    int? episodeNumber,
    int? year,
  }) async {
    final queryParams = <String, String>{
      'query': query,
      if (language != null && language.isNotEmpty) 'languages': language,
      if (seasonNumber != null) 'season_number': seasonNumber.toString(),
      if (episodeNumber != null) 'episode_number': episodeNumber.toString(),
      if (year != null) 'year': year.toString(),
    };

    final uri = Uri.parse('$baseUrl/subtitles').replace(queryParameters: queryParams);
    final response = await httpClient.get(uri, headers: _buildHeaders());

    if (!response.isSuccess) {
      throw HttpException(
        'OpenSubtitles searchByQuery failed with status ${response.statusCode}: ${response.body}',
        uri: uri,
      );
    }

    return _parseSubtitlesList(response.body, matchedBy: 'title');
  }

  /// Requests a secure download link for [fileId].
  Future<String> requestDownloadUrl(int fileId) async {
    final uri = Uri.parse('$baseUrl/download');
    final payload = jsonEncode({'file_id': fileId});

    final response = await httpClient.post(
      uri,
      headers: _buildHeaders(contentTypeJson: true),
      body: payload,
    );

    if (!response.isSuccess) {
      throw HttpException(
        'OpenSubtitles requestDownloadUrl failed with status ${response.statusCode}: ${response.body}',
        uri: uri,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final downloadLink = decoded['link']?.toString() ?? decoded['url']?.toString() ?? '';
    if (downloadLink.isEmpty) {
      throw const FormatException('OpenSubtitles download response did not contain a valid URL');
    }

    return downloadLink;
  }

  /// Downloads the subtitle content as a UTF-8 decoded String.
  Future<String> downloadSubtitleContent(SubtitleResult subtitle, {String? directUrl}) async {
    var targetUrl = directUrl ?? subtitle.downloadUrl;

    if (targetUrl.isEmpty && subtitle.fileId != null) {
      targetUrl = await requestDownloadUrl(subtitle.fileId!);
    }

    if (targetUrl.isEmpty) {
      throw ArgumentError('SubtitleResult has no downloadUrl and no fileId');
    }

    final uri = Uri.parse(targetUrl);
    final response = await httpClient.get(uri, headers: _buildHeaders());

    if (!response.isSuccess) {
      throw HttpException(
        'Failed to download subtitle content: status ${response.statusCode}',
        uri: uri,
      );
    }

    return response.body;
  }

  /// Downloads and saves the subtitle to [targetFile].
  Future<File> downloadSubtitleToFile({
    required SubtitleResult subtitle,
    required File targetFile,
    String? directUrl,
  }) async {
    final content = await downloadSubtitleContent(subtitle, directUrl: directUrl);
    if (!targetFile.parent.existsSync()) {
      targetFile.parent.createSync(recursive: true);
    }
    targetFile.writeAsStringSync(content, encoding: utf8, flush: true);
    return targetFile;
  }

  Map<String, String> _buildHeaders({bool contentTypeJson = false}) {
    return {
      'User-Agent': userAgent,
      'Accept': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'Api-Key': apiKey!,
      if (contentTypeJson) 'Content-Type': 'application/json',
    };
  }

  List<SubtitleResult> _parseSubtitlesList(String responseBody, {String? matchedBy}) {
    final dynamic decoded = jsonDecode(responseBody);
    final results = <SubtitleResult>[];

    if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      final dataList = decoded['data'] as List;
      for (final item in dataList) {
        if (item is Map<String, dynamic>) {
          final res = SubtitleResult.fromJson(item);
          results.add(matchedBy != null && res.matchedBy == null
              ? res.copyWith(matchedBy: matchedBy)
              : res);
        }
      }
    } else if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final res = SubtitleResult.fromJson(item);
          results.add(matchedBy != null && res.matchedBy == null
              ? res.copyWith(matchedBy: matchedBy)
              : res);
        }
      }
    }

    return results;
  }
}
