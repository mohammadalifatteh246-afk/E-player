/// DVD source type detected by E-Player (VLC dvdnav.c / dvdread.c parity).
enum DvdSourceType {
  videoTsFolder('VIDEO_TS Folder'),
  isoImage('DVD ISO Image'),
  vobSequence('VOB Title Set');

  final String label;
  const DvdSourceType(this.label);
}

/// Represents an individual chapter inside a DVD Title (PTT - Part of Title).
class DvdChapter {
  final int chapterIndex; // 1-based (Chapter 1, Chapter 2...)
  final int titleNumber; // Associated Title (1-based)
  final Duration startOffset; // Start timestamp relative to title
  final Duration? duration;
  final String label;

  const DvdChapter({
    required this.chapterIndex,
    required this.titleNumber,
    required this.startOffset,
    this.duration,
    required this.label,
  });

  String get formattedTime {
    final h = startOffset.inHours;
    final m = startOffset.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = startOffset.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'chapterIndex': chapterIndex,
        'titleNumber': titleNumber,
        'startOffsetMs': startOffset.inMilliseconds,
        'durationMs': duration?.inMilliseconds,
        'label': label,
      };

  factory DvdChapter.fromJson(Map<String, dynamic> json) => DvdChapter(
        chapterIndex: json['chapterIndex'] as int,
        titleNumber: json['titleNumber'] as int,
        startOffset: Duration(milliseconds: json['startOffsetMs'] as int),
        duration: json['durationMs'] != null ? Duration(milliseconds: json['durationMs'] as int) : null,
        label: json['label'] as String,
      );
}

/// Audio track stream inside a DVD Title (e.g. AC3 5.1, DTS, LPCM).
class DvdAudioTrackInfo {
  final int streamId;
  final String format; // 'AC3', 'DTS', 'LPCM', 'MPEG'
  final int channels; // 6 = 5.1 Surround, 2 = Stereo
  final String languageCode; // 'en', 'es', 'fr', 'hi', 'ja', etc.
  final String label;

  const DvdAudioTrackInfo({
    required this.streamId,
    required this.format,
    required this.channels,
    required this.languageCode,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'streamId': streamId,
        'format': format,
        'channels': channels,
        'languageCode': languageCode,
        'label': label,
      };

  factory DvdAudioTrackInfo.fromJson(Map<String, dynamic> json) => DvdAudioTrackInfo(
        streamId: json['streamId'] as int,
        format: json['format'] as String,
        channels: json['channels'] as int,
        languageCode: json['languageCode'] as String,
        label: json['label'] as String,
      );
}

/// Subpicture (VobSub) subtitle track inside a DVD Title.
class DvdSubtitleTrackInfo {
  final int streamId;
  final String languageCode;
  final String format; // 'VobSub'
  final String label;

  const DvdSubtitleTrackInfo({
    required this.streamId,
    required this.languageCode,
    this.format = 'VobSub',
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'streamId': streamId,
        'languageCode': languageCode,
        'format': format,
        'label': label,
      };

  factory DvdSubtitleTrackInfo.fromJson(Map<String, dynamic> json) => DvdSubtitleTrackInfo(
        streamId: json['streamId'] as int,
        languageCode: json['languageCode'] as String,
        format: json['format'] as String? ?? 'VobSub',
        label: json['label'] as String,
      );
}

/// Represents a distinct Video Title Set (VTS) on a DVD disc.
class DvdTitle {
  final int titleIndex; // 1-based (Title 1, Title 2...)
  final Duration duration;
  final List<String> vobFiles; // Ordered list of VOB file paths comprising this title
  final List<DvdChapter> chapters;
  final List<DvdAudioTrackInfo> audioTracks;
  final List<DvdSubtitleTrackInfo> subtitleTracks;
  final bool isMainFeature;

  const DvdTitle({
    required this.titleIndex,
    required this.duration,
    required this.vobFiles,
    required this.chapters,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.isMainFeature = false,
  });

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '${h}h ${m}m' : '${m}m ${s}s';
  }

  Map<String, dynamic> toJson() => {
        'titleIndex': titleIndex,
        'durationMs': duration.inMilliseconds,
        'vobFiles': vobFiles,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'audioTracks': audioTracks.map((a) => a.toJson()).toList(),
        'subtitleTracks': subtitleTracks.map((s) => s.toJson()).toList(),
        'isMainFeature': isMainFeature,
      };

  factory DvdTitle.fromJson(Map<String, dynamic> json) => DvdTitle(
        titleIndex: json['titleIndex'] as int,
        duration: Duration(milliseconds: json['durationMs'] as int),
        vobFiles: (json['vobFiles'] as List<dynamic>).cast<String>(),
        chapters: (json['chapters'] as List<dynamic>?)
                ?.map((c) => DvdChapter.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        audioTracks: (json['audioTracks'] as List<dynamic>?)
                ?.map((a) => DvdAudioTrackInfo.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        subtitleTracks: (json['subtitleTracks'] as List<dynamic>?)
                ?.map((s) => DvdSubtitleTrackInfo.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        isMainFeature: json['isMainFeature'] as bool? ?? false,
      );
}

/// Complete structural metadata for a mounted or opened DVD / ISO source.
class DvdMediaInfo {
  final String sourcePath;
  final DvdSourceType sourceType;
  final String volumeLabel;
  final List<DvdTitle> titles;
  int selectedTitleIndex; // 1-based index
  int selectedChapterIndex; // 1-based index

  DvdMediaInfo({
    required this.sourcePath,
    required this.sourceType,
    required this.volumeLabel,
    required this.titles,
    this.selectedTitleIndex = 1,
    this.selectedChapterIndex = 1,
  });

  DvdTitle? get currentTitle {
    if (titles.isEmpty) return null;
    return titles.firstWhere(
      (t) => t.titleIndex == selectedTitleIndex,
      orElse: () => titles.first,
    );
  }

  DvdChapter? get currentChapter {
    final title = currentTitle;
    if (title == null || title.chapters.isEmpty) return null;
    return title.chapters.firstWhere(
      (c) => c.chapterIndex == selectedChapterIndex,
      orElse: () => title.chapters.first,
    );
  }

  Duration get totalDuration => currentTitle?.duration ?? Duration.zero;

  String get formattedTotalDuration {
    final d = totalDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'sourcePath': sourcePath,
        'sourceType': sourceType.name,
        'volumeLabel': volumeLabel,
        'titles': titles.map((t) => t.toJson()).toList(),
        'selectedTitleIndex': selectedTitleIndex,
        'selectedChapterIndex': selectedChapterIndex,
      };

  factory DvdMediaInfo.fromJson(Map<String, dynamic> json) => DvdMediaInfo(
        sourcePath: json['sourcePath'] as String,
        sourceType: DvdSourceType.values.firstWhere(
          (e) => e.name == json['sourceType'],
          orElse: () => DvdSourceType.videoTsFolder,
        ),
        volumeLabel: json['volumeLabel'] as String,
        titles: (json['titles'] as List<dynamic>?)
                ?.map((t) => DvdTitle.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        selectedTitleIndex: json['selectedTitleIndex'] as int? ?? 1,
        selectedChapterIndex: json['selectedChapterIndex'] as int? ?? 1,
      );
}
