/// Represents a subtitle search result returned from OpenSubtitles or a local/remote provider.
class SubtitleResult {
  final String id;
  final String fileName;
  final String language;
  final String languageName;
  final int downloadCount;
  final double rating;
  final String format;
  final String downloadUrl;
  final int? fileId;
  final bool hearingImpaired;
  final double? fps;
  final String? movieTitle;
  final int? movieYear;
  final String? matchedBy; // e.g. 'hash', 'tag', 'title'

  const SubtitleResult({
    required this.id,
    required this.fileName,
    required this.language,
    required this.languageName,
    required this.downloadCount,
    required this.rating,
    required this.format,
    required this.downloadUrl,
    this.fileId,
    this.hearingImpaired = false,
    this.fps,
    this.movieTitle,
    this.movieYear,
    this.matchedBy,
  });

  /// Factory constructor to parse an OpenSubtitles v1 REST API result JSON object.
  factory SubtitleResult.fromJson(Map<String, dynamic> json) {
    // OpenSubtitles v1 API structure:
    // {
    //   "id": "12345",
    //   "type": "subtitle",
    //   "attributes": {
    //     "subtitle_id": "12345",
    //     "language": "en",
    //     "download_count": 4200,
    //     "ratings": 8.4,
    //     "format": "srt",
    //     "hearing_impaired": false,
    //     "fps": 23.976,
    //     "feature_details": {
    //       "title": "Inception",
    //       "year": 2010
    //     },
    //     "url": "https://api.opensubtitles.com/api/v1/download",
    //     "files": [
    //       {"file_id": 9999, "file_name": "Inception.2010.en.srt"}
    //     ]
    //   }
    // }
    final attributes = json['attributes'] as Map<String, dynamic>? ?? json;

    String id = json['id']?.toString() ?? attributes['subtitle_id']?.toString() ?? '';
    
    // File list & file name extraction
    String fileName = '';
    int? fileId;
    if (attributes['files'] is List && (attributes['files'] as List).isNotEmpty) {
      final firstFile = (attributes['files'] as List).first as Map<String, dynamic>;
      fileName = firstFile['file_name']?.toString() ?? '';
      fileId = firstFile['file_id'] is int ? firstFile['file_id'] as int : int.tryParse(firstFile['file_id']?.toString() ?? '');
    }
    if (fileName.isEmpty) {
      fileName = attributes['file_name']?.toString() ?? 'subtitle.srt';
    }

    // Language
    final lang = attributes['language']?.toString() ?? 'en';
    final langName = attributes['language_name']?.toString() ?? _resolveLanguageName(lang);

    // Rating
    double rating = 0.0;
    final rawRating = attributes['ratings'] ?? attributes['rating'];
    if (rawRating is num) {
      rating = rawRating.toDouble();
    } else if (rawRating is String) {
      rating = double.tryParse(rawRating) ?? 0.0;
    }

    // Download count
    int downloadCount = 0;
    final rawDownloads = attributes['download_count'] ?? attributes['downloads'];
    if (rawDownloads is int) {
      downloadCount = rawDownloads;
    } else if (rawDownloads is String) {
      downloadCount = int.tryParse(rawDownloads) ?? 0;
    }

    // Format
    final format = attributes['format']?.toString().toLowerCase() ?? 'srt';

    // Download URL
    final downloadUrl = attributes['url']?.toString() ?? attributes['download_url']?.toString() ?? '';

    // Hearing impaired
    final hearingImpaired = attributes['hearing_impaired'] == true;

    // FPS
    double? fps;
    final rawFps = attributes['fps'];
    if (rawFps is num) {
      fps = rawFps.toDouble();
    } else if (rawFps is String) {
      fps = double.tryParse(rawFps);
    }

    // Movie details
    String? movieTitle;
    int? movieYear;
    if (attributes['feature_details'] is Map<String, dynamic>) {
      final feature = attributes['feature_details'] as Map<String, dynamic>;
      movieTitle = feature['title']?.toString();
      final rawYear = feature['year'];
      if (rawYear is int) {
        movieYear = rawYear;
      } else if (rawYear is String) {
        movieYear = int.tryParse(rawYear);
      }
    } else {
      movieTitle = attributes['movie_name']?.toString();
    }

    final matchedBy = attributes['matched_by']?.toString();

    return SubtitleResult(
      id: id,
      fileName: fileName,
      language: lang,
      languageName: langName,
      downloadCount: downloadCount,
      rating: rating,
      format: format,
      downloadUrl: downloadUrl,
      fileId: fileId,
      hearingImpaired: hearingImpaired,
      fps: fps,
      movieTitle: movieTitle,
      movieYear: movieYear,
      matchedBy: matchedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'language': language,
      'languageName': languageName,
      'downloadCount': downloadCount,
      'rating': rating,
      'format': format,
      'downloadUrl': downloadUrl,
      if (fileId != null) 'fileId': fileId,
      'hearingImpaired': hearingImpaired,
      if (fps != null) 'fps': fps,
      if (movieTitle != null) 'movieTitle': movieTitle,
      if (movieYear != null) 'movieYear': movieYear,
      if (matchedBy != null) 'matchedBy': matchedBy,
    };
  }

  SubtitleResult copyWith({
    String? id,
    String? fileName,
    String? language,
    String? languageName,
    int? downloadCount,
    double? rating,
    String? format,
    String? downloadUrl,
    int? fileId,
    bool? hearingImpaired,
    double? fps,
    String? movieTitle,
    int? movieYear,
    String? matchedBy,
  }) {
    return SubtitleResult(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      language: language ?? this.language,
      languageName: languageName ?? this.languageName,
      downloadCount: downloadCount ?? this.downloadCount,
      rating: rating ?? this.rating,
      format: format ?? this.format,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileId: fileId ?? this.fileId,
      hearingImpaired: hearingImpaired ?? this.hearingImpaired,
      fps: fps ?? this.fps,
      movieTitle: movieTitle ?? this.movieTitle,
      movieYear: movieYear ?? this.movieYear,
      matchedBy: matchedBy ?? this.matchedBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubtitleResult &&
        other.id == id &&
        other.fileName == fileName &&
        other.language == language &&
        other.downloadUrl == downloadUrl;
  }

  @override
  int get hashCode => Object.hash(id, fileName, language, downloadUrl);

  @override
  String toString() {
    return 'SubtitleResult(id: $id, fileName: $fileName, lang: $language, rating: $rating, downloads: $downloadCount)';
  }

  static String _resolveLanguageName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return 'English';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      case 'ru':
        return 'Russian';
      case 'ja':
        return 'Japanese';
      case 'zh':
        return 'Chinese';
      case 'ko':
        return 'Korean';
      case 'ar':
        return 'Arabic';
      case 'hi':
        return 'Hindi';
      default:
        return code.toUpperCase();
    }
  }
}

/// Represents the cryptographic MovieHash and byte size result for OpenSubtitles matching.
class MovieHashResult {
  final String hash;
  final int byteSize;

  const MovieHashResult({
    required this.hash,
    required this.byteSize,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MovieHashResult &&
        other.hash == hash &&
        other.byteSize == byteSize;
  }

  @override
  int get hashCode => Object.hash(hash, byteSize);

  @override
  String toString() => 'MovieHashResult(hash: $hash, byteSize: $byteSize)';
}
