import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../domain/cdda_models.dart';

/// Pure-Dart CUE Sheet and Red Book CDDA (75 fps) Frame Parser (VLC cdda.c parity).
class CueSheetParser {
  /// Converts Red Book frames format (mm:ss:ff, 75 frames/second) into a Dart [Duration].
  static Duration framesToDuration(String timeString) {
    final parts = timeString.trim().split(':');
    if (parts.length < 3) return Duration.zero;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    final frames = int.tryParse(parts[2]) ?? 0;

    // Red Book CD standard: 75 frames per second -> 1 frame = 1000 / 75 = 13.333 ms
    final frameMs = (frames * 1000.0 / 75.0).round();

    return Duration(minutes: minutes, seconds: seconds, milliseconds: frameMs);
  }

  /// Calculates the total Red Book sector number from mm:ss:ff string.
  static int framesToSector(String timeString) {
    final parts = timeString.trim().split(':');
    if (parts.length < 3) return 0;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    final frames = int.tryParse(parts[2]) ?? 0;

    return (minutes * 60 + seconds) * 75 + frames;
  }

  /// Parses a CUE file from disk into an [AudioCdDiscInfo] structure.
  static Future<AudioCdDiscInfo?> parseCueFile(
    File file, {
    Duration? totalAudioDuration,
  }) async {
    try {
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return parseCueString(
        content,
        cuePath: file.path,
        totalAudioDuration: totalAudioDuration,
      );
    } catch (e) {
      debugPrint('[CueSheetParser] Failed to parse CUE file: $e');
      return null;
    }
  }

  /// Parses raw CUE sheet text content into structured disc metadata.
  static AudioCdDiscInfo parseCueString(
    String content, {
    String? cuePath,
    Duration? totalAudioDuration,
  }) {
    String albumTitle = 'Unknown Audio CD';
    String discPerformer = 'Unknown Artist';
    String? genre;
    String? releaseYear;
    String? audioFileName;

    final lines = content.split(RegExp(r'\r?\n'));

    int? currentTrackNumber;
    String? currentTrackTitle;
    String? currentTrackPerformer;
    Duration? currentTrackIndex;
    int currentTrackSector = 0;

    final rawTrackList = <_RawTrackEntry>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Extract REM metadata
      if (line.toUpperCase().startsWith('REM ')) {
        final remParts = line.substring(4).trim().split(' ');
        if (remParts.isNotEmpty) {
          final key = remParts[0].toUpperCase();
          final val = _stripQuotes(line.substring(4 + remParts[0].length).trim());
          if (key == 'GENRE') genre = val;
          if (key == 'DATE' || key == 'YEAR') releaseYear = val;
        }
        continue;
      }

      // Extract Root Level PERFORMER & TITLE
      if (currentTrackNumber == null) {
        if (line.toUpperCase().startsWith('PERFORMER ')) {
          discPerformer = _stripQuotes(line.substring(10));
          continue;
        }
        if (line.toUpperCase().startsWith('TITLE ')) {
          albumTitle = _stripQuotes(line.substring(6));
          continue;
        }
        if (line.toUpperCase().startsWith('FILE ')) {
          final fileMatch = RegExp(r'^FILE\s+"?([^"]+)"?\s+.*$', caseSensitive: false).firstMatch(line);
          if (fileMatch != null) {
            audioFileName = fileMatch.group(1);
          }
          continue;
        }
      }

      // TRACK entry start
      final trackMatch = RegExp(r'^TRACK\s+(\d+)\s+AUDIO', caseSensitive: false).firstMatch(line);
      if (trackMatch != null) {
        // Save previous track if pending
        if (currentTrackNumber != null && currentTrackIndex != null) {
          rawTrackList.add(
            _RawTrackEntry(
              trackNumber: currentTrackNumber,
              title: currentTrackTitle ?? 'Track $currentTrackNumber',
              artist: currentTrackPerformer ?? discPerformer,
              startOffset: currentTrackIndex,
              startSector: currentTrackSector,
            ),
          );
        }

        currentTrackNumber = int.tryParse(trackMatch.group(1)!) ?? (rawTrackList.length + 1);
        currentTrackTitle = null;
        currentTrackPerformer = null;
        currentTrackIndex = null;
        currentTrackSector = 0;
        continue;
      }

      // Track level properties
      if (currentTrackNumber != null) {
        if (line.toUpperCase().startsWith('TITLE ')) {
          currentTrackTitle = _stripQuotes(line.substring(6));
          continue;
        }
        if (line.toUpperCase().startsWith('PERFORMER ')) {
          currentTrackPerformer = _stripQuotes(line.substring(10));
          continue;
        }
        // INDEX 01 mm:ss:ff represents track start
        final indexMatch = RegExp(r'^INDEX\s+01\s+(\d{2}:\d{2}:\d{2})', caseSensitive: false).firstMatch(line);
        if (indexMatch != null) {
          final timeStr = indexMatch.group(1)!;
          currentTrackIndex = framesToDuration(timeStr);
          currentTrackSector = framesToSector(timeStr);
          continue;
        }
      }
    }

    // Append last track
    if (currentTrackNumber != null && currentTrackIndex != null) {
      rawTrackList.add(
        _RawTrackEntry(
          trackNumber: currentTrackNumber,
          title: currentTrackTitle ?? 'Track $currentTrackNumber',
          artist: currentTrackPerformer ?? discPerformer,
          startOffset: currentTrackIndex,
          startSector: currentTrackSector,
        ),
      );
    }

    // Resolve audio source absolute path
    String? resolvedAudioSource;
    if (audioFileName != null && cuePath != null) {
      final cueDir = p.dirname(cuePath);
      final candidate = p.join(cueDir, audioFileName);
      resolvedAudioSource = candidate;
    }

    // Calculate individual track durations by measuring intervals
    final List<CdTrackInfo> resolvedTracks = [];
    for (int i = 0; i < rawTrackList.length; i++) {
      final current = rawTrackList[i];
      Duration duration;

      if (i < rawTrackList.length - 1) {
        final next = rawTrackList[i + 1];
        duration = next.startOffset - current.startOffset;
      } else {
        // Last track: use total audio duration if supplied, otherwise default estimate
        if (totalAudioDuration != null && totalAudioDuration > current.startOffset) {
          duration = totalAudioDuration - current.startOffset;
        } else {
          duration = const Duration(minutes: 3, seconds: 45);
        }
      }

      if (duration <= Duration.zero) {
        duration = const Duration(minutes: 3, seconds: 30);
      }

      resolvedTracks.add(
        CdTrackInfo(
          trackNumber: current.trackNumber,
          title: current.title,
          artist: current.artist,
          startOffset: current.startOffset,
          duration: duration,
          startSector: current.startSector,
        ),
      );
    }

    return AudioCdDiscInfo(
      albumTitle: albumTitle,
      artist: discPerformer,
      genre: genre,
      releaseYear: releaseYear,
      audioSourcePath: resolvedAudioSource,
      cueSheetPath: cuePath,
      tracks: resolvedTracks,
    );
  }

  static String _stripQuotes(String input) {
    var s = input.trim();
    if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
      s = s.substring(1, s.length - 1);
    }
    return s.trim();
  }
}

class _RawTrackEntry {
  final int trackNumber;
  final String title;
  final String artist;
  final Duration startOffset;
  final int startSector;

  const _RawTrackEntry({
    required this.trackNumber,
    required this.title,
    required this.artist,
    required this.startOffset,
    required this.startSector,
  });
}
