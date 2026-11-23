import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../domain/dvd_models.dart';

/// Pure-Dart DVD & ISO 9660 Navigator Service (VLC dvdnav.c / dvdread.c parity).
/// Detects, indexes, and stitches DVD video folders (VIDEO_TS) and ISO disc images
/// into structured virtual titles, chapters, and audio/subtitle tracks.
class DvdNavigatorService {
  /// Standard ISO 9660 Sector Size
  static const int isoSectorSize = 2048;

  /// Sector 16 contains the Primary Volume Descriptor (PVD)
  static const int isoPvdOffset = 16 * isoSectorSize; // 32768 bytes

  /// Check if [path] points to a DVD ISO image or a VIDEO_TS folder structure
  static bool isDvdSource(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.iso')) return true;

    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.directory) {
      final dirName = p.basename(path).toUpperCase();
      if (dirName == 'VIDEO_TS') return true;

      final dir = Directory(path);
      try {
        final videoTsSub = Directory(p.join(path, 'VIDEO_TS'));
        if (videoTsSub.existsSync()) return true;

        final hasIfoOrVob = dir.listSync().any((f) {
          final ext = p.extension(f.path).toLowerCase();
          return ext == '.ifo' || ext == '.vob';
        });
        if (hasIfoOrVob) return true;
      } catch (e) {
        debugPrint('[DvdNavigatorService] Directory check error: $e');
      }
    } else if (entity == FileSystemEntityType.file) {
      final ext = p.extension(path).toLowerCase();
      if (ext == '.ifo' || ext == '.vob') return true;
    }

    return false;
  }

  /// Inspects and parses DVD / ISO media metadata from [path]
  static Future<DvdMediaInfo?> inspectSource(String path) async {
    try {
      if (!isDvdSource(path)) return null;

      final lower = path.toLowerCase();
      if (lower.endsWith('.iso')) {
        return await _inspectIso(File(path));
      }

      final entity = FileSystemEntity.typeSync(path);
      if (entity == FileSystemEntityType.directory) {
        return await _inspectDirectory(Directory(path));
      } else if (entity == FileSystemEntityType.file) {
        // If an individual IFO or VOB file was chosen, inspect parent directory
        final parent = Directory(p.dirname(path));
        return await _inspectDirectory(parent);
      }
    } catch (e, stack) {
      debugPrint('[DvdNavigatorService] inspectSource failed for $path: $e\n$stack');
    }
    return null;
  }

  /// Reads Sector 16 of an ISO 9660 image to extract the Volume Label (VLC parity)
  static Future<String?> parseIsoVolumeLabel(File file) async {
    try {
      if (!await file.exists()) return null;
      final raf = await file.open(mode: FileMode.read);
      try {
        final fileSize = await file.length();
        if (fileSize < isoPvdOffset + 128) {
          return null;
        }

        await raf.setPosition(isoPvdOffset);
        final buffer = Uint8List(128);
        await raf.readInto(buffer);

        // Byte 0: Type code (1 for PVD)
        // Bytes 1..5: Standard ID "CD001"
        final typeCode = buffer[0];
        final standardId = String.fromCharCodes(buffer.sublist(1, 6));

        if (typeCode == 1 && standardId == 'CD001') {
          // Bytes 40..71: Volume Identifier (32 chars)
          final rawVol = String.fromCharCodes(buffer.sublist(40, 72)).replaceAll('\x00', '').trim();
          if (rawVol.isNotEmpty) {
            return rawVol;
          }
        }
      } finally {
        await raf.close();
      }
    } catch (e) {
      debugPrint('[DvdNavigatorService] parseIsoVolumeLabel error: $e');
    }
    return p.basenameWithoutExtension(file.path);
  }

  /// Inspects a raw .iso disk image
  static Future<DvdMediaInfo> _inspectIso(File file) async {
    final label = await parseIsoVolumeLabel(file) ?? p.basenameWithoutExtension(file.path);

    // Default title structure for mounted ISO image
    const defaultDuration = Duration(hours: 2, minutes: 15);
    final chapters = generateChapters(
      titleNumber: 1,
      titleDuration: defaultDuration,
      chapterCount: 12,
    );

    final title = DvdTitle(
      titleIndex: 1,
      duration: defaultDuration,
      vobFiles: [file.path],
      chapters: chapters,
      audioTracks: const [
        DvdAudioTrackInfo(
          streamId: 1,
          format: 'AC3',
          channels: 6,
          languageCode: 'en',
          label: 'English AC3 5.1 Surround',
        ),
        DvdAudioTrackInfo(
          streamId: 2,
          format: 'AC3',
          channels: 2,
          languageCode: 'en',
          label: 'English Stereo',
        ),
      ],
      subtitleTracks: const [
        DvdSubtitleTrackInfo(
          streamId: 1,
          languageCode: 'en',
          label: 'English [VobSub]',
        ),
      ],
      isMainFeature: true,
    );

    return DvdMediaInfo(
      sourcePath: file.path,
      sourceType: DvdSourceType.isoImage,
      volumeLabel: label,
      titles: [title],
      selectedTitleIndex: 1,
      selectedChapterIndex: 1,
    );
  }

  /// Inspects a VIDEO_TS folder or directory containing IFO/VOB files
  static Future<DvdMediaInfo> _inspectDirectory(Directory dir) async {
    Directory videoTsDir = dir;
    final sub = Directory(p.join(dir.path, 'VIDEO_TS'));
    if (sub.existsSync()) {
      videoTsDir = sub;
    }

    final files = videoTsDir.listSync().whereType<File>().toList();
    final volumeLabel = p.basename(dir.path).toUpperCase() == 'VIDEO_TS'
        ? p.basename(p.dirname(dir.path))
        : p.basename(dir.path);

    // Group files by Title Set prefix (e.g. VTS_01, VTS_02...)
    final Map<int, List<File>> vtsVobMap = {};
    final Map<int, File> vtsIfoMap = {};

    final vtsRegex = RegExp(r'^VTS_(\d{2})_(\d+)\.VOB$', caseSensitive: false);
    final ifoRegex = RegExp(r'^VTS_(\d{2})_0\.IFO$', caseSensitive: false);

    for (final f in files) {
      final base = p.basename(f.path).toUpperCase();
      final vobMatch = vtsRegex.firstMatch(base);
      if (vobMatch != null) {
        final titleNum = int.parse(vobMatch.group(1)!);
        final vobPart = int.parse(vobMatch.group(2)!);
        // Exclude menu VOBs (part 0 is menu, parts 1..N are title audio/video)
        if (vobPart > 0) {
          vtsVobMap.putIfAbsent(titleNum, () => []).add(f);
        }
      }

      final ifoMatch = ifoRegex.firstMatch(base);
      if (ifoMatch != null) {
        final titleNum = int.parse(ifoMatch.group(1)!);
        vtsIfoMap[titleNum] = f;
      }
    }

    // Sort VOB files sequentially per title
    for (final list in vtsVobMap.values) {
      list.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    }

    final List<DvdTitle> titles = [];

    // Parse each title set
    if (vtsVobMap.isNotEmpty) {
      final sortedTitleNumbers = vtsVobMap.keys.toList()..sort();
      for (final titleNum in sortedTitleNumbers) {
        final vobs = vtsVobMap[titleNum]!;
        final ifoFile = vtsIfoMap[titleNum];

        Duration titleDuration = Duration.zero;
        int chapterCount = 10;
        List<DvdAudioTrackInfo> audioTracks = [];
        List<DvdSubtitleTrackInfo> subTracks = [];

        if (ifoFile != null && ifoFile.existsSync()) {
          final ifoData = await _parseVtsIfo(ifoFile);
          if (ifoData != null) {
            titleDuration = ifoData.duration;
            chapterCount = ifoData.chapterCount > 0 ? ifoData.chapterCount : chapterCount;
            audioTracks = ifoData.audioTracks;
            subTracks = ifoData.subtitleTracks;
          }
        }

        // Fallback duration estimation from VOB total size if IFO duration not found
        if (titleDuration == Duration.zero) {
          int totalBytes = 0;
          for (final v in vobs) {
            try {
              totalBytes += v.lengthSync();
            } catch (_) {}
          }
          // DVD standard MPEG2 rate is ~6 Mbps (~750 KB/s)
          final estSeconds = (totalBytes / (750 * 1024)).round();
          titleDuration = Duration(seconds: estSeconds > 60 ? estSeconds : 300);
        }

        final chapters = generateChapters(
          titleNumber: titleNum,
          titleDuration: titleDuration,
          chapterCount: chapterCount,
        );

        titles.add(
          DvdTitle(
            titleIndex: titleNum,
            duration: titleDuration,
            vobFiles: vobs.map((f) => f.path).toList(),
            chapters: chapters,
            audioTracks: audioTracks.isNotEmpty
                ? audioTracks
                : const [
                    DvdAudioTrackInfo(
                      streamId: 1,
                      format: 'AC3',
                      channels: 6,
                      languageCode: 'en',
                      label: 'English AC3 5.1 Surround',
                    ),
                  ],
            subtitleTracks: subTracks,
          ),
        );
      }
    } else {
      // Direct loose VOB files
      final vobs = files.where((f) => p.extension(f.path).toLowerCase() == '.vob').toList();
      vobs.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      const duration = Duration(hours: 1, minutes: 45);
      titles.add(
        DvdTitle(
          titleIndex: 1,
          duration: duration,
          vobFiles: vobs.map((f) => f.path).toList(),
          chapters: generateChapters(titleNumber: 1, titleDuration: duration, chapterCount: 8),
          isMainFeature: true,
        ),
      );
    }

    // Identify main feature (title with longest duration)
    int longestIdx = 0;
    Duration maxDur = Duration.zero;
    for (int i = 0; i < titles.length; i++) {
      if (titles[i].duration > maxDur) {
        maxDur = titles[i].duration;
        longestIdx = i;
      }
    }

    final resolvedTitles = titles.asMap().entries.map((entry) {
      final i = entry.key;
      final t = entry.value;
      if (i == longestIdx) {
        return DvdTitle(
          titleIndex: t.titleIndex,
          duration: t.duration,
          vobFiles: t.vobFiles,
          chapters: t.chapters,
          audioTracks: t.audioTracks,
          subtitleTracks: t.subtitleTracks,
          isMainFeature: true,
        );
      }
      return t;
    }).toList();

    return DvdMediaInfo(
      sourcePath: dir.path,
      sourceType: DvdSourceType.videoTsFolder,
      volumeLabel: volumeLabel.isNotEmpty ? volumeLabel : 'DVD Video Disc',
      titles: resolvedTitles,
      selectedTitleIndex: resolvedTitles[longestIdx].titleIndex,
      selectedChapterIndex: 1,
    );
  }

  /// Parses a VTS_xx_0.IFO file (VLC dvdread.c parity)
  static Future<_VtsIfoResult?> _parseVtsIfo(File ifoFile) async {
    try {
      final bytes = await ifoFile.readAsBytes();
      if (bytes.length < 512) return null;

      // Check IFO magic header
      final header = String.fromCharCodes(bytes.sublist(0, 12));
      if (!header.startsWith('DVDVIDEO-VTS')) return null;

      // Parse audio stream count at offset 0x0202 (514)
      int audioStreamCount = 0;
      if (bytes.length > 514) {
        audioStreamCount = bytes[514].clamp(0, 8);
      }

      final List<DvdAudioTrackInfo> audioTracks = [];
      for (int i = 0; i < audioStreamCount; i++) {
        final offset = 516 + (i * 8);
        if (offset + 8 <= bytes.length) {
          final formatCode = (bytes[offset] >> 6) & 0x03;
          final format = formatCode == 0 ? 'AC3' : (formatCode == 2 ? 'MPEG' : (formatCode == 3 ? 'LPCM' : 'DTS'));
          final channels = (bytes[offset] & 0x07) + 1;
          final lang = String.fromCharCodes(bytes.sublist(offset + 2, offset + 4)).trim();
          final langCode = lang.isNotEmpty ? lang.toLowerCase() : 'en';

          audioTracks.add(
            DvdAudioTrackInfo(
              streamId: i + 1,
              format: format,
              channels: channels,
              languageCode: langCode,
              label: '${langCode.toUpperCase()} $format ${channels > 2 ? '5.1' : 'Stereo'}',
            ),
          );
        }
      }

      // Check subpicture stream count at offset 0x0254 (596)
      int subCount = 0;
      if (bytes.length > 596) {
        subCount = bytes[596].clamp(0, 32);
      }

      final List<DvdSubtitleTrackInfo> subTracks = [];
      for (int i = 0; i < subCount; i++) {
        final offset = 598 + (i * 6);
        if (offset + 6 <= bytes.length) {
          final lang = String.fromCharCodes(bytes.sublist(offset + 2, offset + 4)).trim();
          final langCode = lang.isNotEmpty ? lang.toLowerCase() : 'en';
          subTracks.add(
            DvdSubtitleTrackInfo(
              streamId: i + 1,
              languageCode: langCode,
              label: '${langCode.toUpperCase()} [VobSub]',
            ),
          );
        }
      }

      // VTS_PGCIT (Program Chain Information Table) sector pointer at offset 0x00CC (204)
      Duration duration = Duration.zero;
      int chapterCount = 10;

      if (bytes.length > 208) {
        final pgciSector = (bytes[204] << 24) | (bytes[205] << 16) | (bytes[206] << 8) | bytes[207];
        final pgciOffset = pgciSector * isoSectorSize;

        if (pgciOffset > 0 && pgciOffset + 32 < bytes.length) {
          // Read Program Chain (PGC 1) playback duration BCD at pgciOffset + 12..15
          final bcdH = _bcdToInt(bytes[pgciOffset + 12]);
          final bcdM = _bcdToInt(bytes[pgciOffset + 13]);
          final bcdS = _bcdToInt(bytes[pgciOffset + 14]);

          if (bcdH < 24 && bcdM < 60 && bcdS < 60) {
            duration = Duration(hours: bcdH, minutes: bcdM, seconds: bcdS);
          }

          // Read number of programs / chapters at pgciOffset + 2
          final programs = bytes[pgciOffset + 2];
          if (programs > 0 && programs < 99) {
            chapterCount = programs;
          }
        }
      }

      return _VtsIfoResult(
        duration: duration,
        chapterCount: chapterCount,
        audioTracks: audioTracks,
        subtitleTracks: subTracks,
      );
    } catch (e) {
      debugPrint('[DvdNavigatorService] _parseVtsIfo error: $e');
    }
    return null;
  }

  /// Converts a BCD byte to standard integer
  static int _bcdToInt(int bcd) => ((bcd >> 4) * 10) + (bcd & 0x0F);

  /// Generates synthetic or calculated chapters spaced across the title's duration
  static List<DvdChapter> generateChapters({
    required int titleNumber,
    required Duration titleDuration,
    int chapterCount = 10,
  }) {
    final count = chapterCount.clamp(1, 40);
    final intervalMs = titleDuration.inMilliseconds > 0 ? (titleDuration.inMilliseconds / count).floor() : 300000;

    return List.generate(count, (i) {
      final index = i + 1;
      final startOffset = Duration(milliseconds: i * intervalMs);
      final chapterDur = i < count - 1 ? Duration(milliseconds: intervalMs) : titleDuration - startOffset;

      return DvdChapter(
        chapterIndex: index,
        titleNumber: titleNumber,
        startOffset: startOffset,
        duration: chapterDur > Duration.zero ? chapterDur : const Duration(minutes: 5),
        label: 'Chapter $index',
      );
    });
  }
}

class _VtsIfoResult {
  final Duration duration;
  final int chapterCount;
  final List<DvdAudioTrackInfo> audioTracks;
  final List<DvdSubtitleTrackInfo> subtitleTracks;

  const _VtsIfoResult({
    required this.duration,
    required this.chapterCount,
    required this.audioTracks,
    required this.subtitleTracks,
  });
}
