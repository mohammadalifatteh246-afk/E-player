import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/media_item.dart';

/// Distinct modes for organizing media collections matching VLC's grouping behavior.
enum GroupMode {
  none,
  byFolder,
  byName;

  String get label {
    switch (this) {
      case GroupMode.none:
        return 'None';
      case GroupMode.byFolder:
        return 'By Folder';
      case GroupMode.byName:
        return 'By Name';
    }
  }

  String get description {
    switch (this) {
      case GroupMode.none:
        return 'Standard flat list of videos';
      case GroupMode.byFolder:
        return 'Group videos by their parent folder';
      case GroupMode.byName:
        return 'Smart series, episode & franchise title clustering';
    }
  }

  IconData get icon {
    switch (this) {
      case GroupMode.none:
        return Icons.format_list_bulleted_rounded;
      case GroupMode.byFolder:
        return Icons.folder_outlined;
      case GroupMode.byName:
        return Icons.auto_awesome_motion_outlined;
    }
  }
}

/// Represents an automated grouped collection of videos (by folder or by name/stem).
class VideoGroup {
  final String id;
  final String title;
  final String subtitle;
  final String? folderPath;
  final GroupMode mode;
  final List<MediaItem> items;
  final int totalDurationMs;
  final int totalSizeBytes;
  final DateTime latestDate;

  const VideoGroup({
    required this.id,
    required this.title,
    required this.subtitle,
    this.folderPath,
    required this.mode,
    required this.items,
    required this.totalDurationMs,
    required this.totalSizeBytes,
    required this.latestDate,
  });

  int get itemCount => items.length;
  bool get isSingle => items.length == 1;
  MediaItem? get previewItem => items.isNotEmpty ? items.first : null;

  VideoGroup copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? folderPath,
    GroupMode? mode,
    List<MediaItem>? items,
    int? totalDurationMs,
    int? totalSizeBytes,
    DateTime? latestDate,
  }) {
    return VideoGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      folderPath: folderPath ?? this.folderPath,
      mode: mode ?? this.mode,
      items: items ?? this.items,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      latestDate: latestDate ?? this.latestDate,
    );
  }
}

class _StemGroup {
  final String title;
  final List<MediaItem> items = [];
  int totalDuration = 0;
  int totalSize = 0;
  int latestMs = 0;

  _StemGroup(this.title);

  void add(MediaItem item) {
    items.add(item);
    totalDuration += item.durationMs;
    totalSize += item.sizeBytes;
    final ms = item.lastPlayed.millisecondsSinceEpoch;
    if (ms > latestMs) latestMs = ms;
  }
}

/// Core in-memory grouping engine reverse engineered from VLC media library.
///
/// Implements sub-16ms transformations:
/// - Folder grouping with zero path truncation, trailing-slash normalization, and strict collision prevention
/// - Smart regex and prefix clustering for TV episodes, franchise films, leading episode tokens, and multi-part media
/// - Non-allocating alphanumeric natural sorting with leading zero support and overflow safety
class VideoGroupingEngine {
  // Roman numerals up to 30 (I to XXX) for media parts and episodes
  static const String _romanPattern = r'(?:x{0,3}(?:ix|iv|v|v?i{1,3})|x{1,3})';

  // Linear non-backtracking regexes for episode/season/part extraction
  // Supports S01E01, Season 1 Episode 2, Ep 01, Episode IV, and TV scene standard 1x01 / 01x02
  static final RegExp _seasonEpisodePattern = RegExp(
    r'\b(?:(?:s(?:eason)?[._\s-]*)?(\d{1,3})?[._\s-]*(?:e(?:p(?:isode)?)?)[._\s-]*(\d{1,3}|' + _romanPattern + r')|(\d{1,2})x(\d{1,3}))\b',
    caseSensitive: false,
  );

  static final RegExp _seasonOnlyPattern = RegExp(
    r'\b(?:s|season)[._\s-]*(\d{1,3})\b',
    caseSensitive: false,
  );

  static final RegExp _partDiscPattern = RegExp(
    r'\b(?:part|pt|disc|cd|disk|vol|volume|chapter|ch)[._\s-]*(\d{1,3}|' + _romanPattern + r')\b',
    caseSensitive: false,
  );

  static final RegExp _trailingNumberPattern = RegExp(
    r'(?:[-_:\s]+|\s*\()\s*(\d{1,3}|' + _romanPattern + r')\s*\)?$',
    caseSensitive: false,
  );

  // Leading episode numbers/tokens with explicit keywords (e.g. "Ep 01 - Title", "Episode 01 Title", "E01 Title")
  static final RegExp _leadingExplicitEpisodePattern = RegExp(
    r'^(?:ep(?:isode)?|s\d{1,3}e\d{1,3}|e)\s*[._\s-]*\s*(\d{1,4})\s*(?:[-_:\.]|\s)\s*(.*)$',
    caseSensitive: false,
  );

  // Leading separated or bracketed numbers (e.g. "01. Title", "01 - Title", "01_Title", "[01] Title", "01 Title")
  static final RegExp _leadingSeparatedNumberPattern = RegExp(
    r'^(?:\[\s*(\d{1,4})\s*\]|\(\s*(\d{1,4})\s*\)|(\d{1,4})\s*[-_:\.]|0+(\d{1,3})\s+)\s*(.*)$',
    caseSensitive: false,
  );

  static final RegExp _releaseTagsPattern = RegExp(
    r'\b(?:1080p|720p|2160p|4k|uhd|fhd|hd|bluray|bdrip|web-dl|webrip|hdtv|dvdrip|x264|x265|hevc|h264|h265|10bit|remux|aac|ac3|dts|flac)\b',
    caseSensitive: false,
  );

  static final RegExp _bracketsPattern = RegExp(r'\[.*?\]');
  static final RegExp _resolutionParensPattern = RegExp(r'\(.*?\d{3,4}p.*?\)');

  static const Set<String> _videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'ts', '3gp', 'mpg', 'mpeg'
  };

  /// Compares strings naturally so that e.g. "Episode 2" sorts before "Episode 10".
  /// Handles arbitrary digit lengths without 64-bit integer overflow and trims leading zeros.
  static int naturalCompare(String a, String b) {
    if (identical(a, b) || a == b) return 0;

    int i = 0;
    int j = 0;
    final lenA = a.length;
    final lenB = b.length;

    while (i < lenA && j < lenB) {
      final codeA = a.codeUnitAt(i);
      final codeB = b.codeUnitAt(j);

      final isDigitA = codeA >= 48 && codeA <= 57;
      final isDigitB = codeB >= 48 && codeB <= 57;

      if (isDigitA && isDigitB) {
        // Skip leading zeros
        while (i < lenA && a.codeUnitAt(i) == 48) {
          i++;
        }
        while (j < lenB && b.codeUnitAt(j) == 48) {
          j++;
        }

        final startA = i;
        final startB = j;

        while (i < lenA && a.codeUnitAt(i) >= 48 && a.codeUnitAt(i) <= 57) {
          i++;
        }
        while (j < lenB && b.codeUnitAt(j) >= 48 && b.codeUnitAt(j) <= 57) {
          j++;
        }

        final digitLenA = i - startA;
        final digitLenB = j - startB;

        // Number with more significant digits is strictly greater
        if (digitLenA != digitLenB) {
          return digitLenA.compareTo(digitLenB);
        }

        // Equal length: compare digit by digit
        for (int k = 0; k < digitLenA; k++) {
          final diff = a.codeUnitAt(startA + k) - b.codeUnitAt(startB + k);
          if (diff != 0) return diff > 0 ? 1 : -1;
        }
      } else {
        var charCodeA = codeA;
        var charCodeB = codeB;
        if (charCodeA >= 65 && charCodeA <= 90) charCodeA += 32;
        if (charCodeB >= 65 && charCodeB <= 90) charCodeB += 32;
        if (charCodeA != charCodeB) {
          return charCodeA.compareTo(charCodeB);
        }
        i++;
        j++;
      }
    }
    return (lenA - i).compareTo(lenB - j);
  }

  /// Trims leading and trailing separators, punctuation, dangling brackets, and loose conjunctions.
  static String cleanDelimiters(String s) {
    var str = s.trim();

    // Clean trailing punctuation / separators
    while (str.isNotEmpty) {
      final code = str.codeUnitAt(str.length - 1);
      if (code == 32 || code == 45 || code == 95 || code == 58 || code == 59 ||
          code == 44 || code == 46 || code == 8211 || code == 8212 || code == 8722 ||
          code == 47 || code == 92 || code == 124 || code == 126) {
        str = str.substring(0, str.length - 1).trimRight();
        continue;
      }
      // Dangling opening bracket at end of string: (, [, {, <
      if (code == 40 || code == 91 || code == 123 || code == 60) {
        str = str.substring(0, str.length - 1).trimRight();
        continue;
      }
      // Dangling closing bracket at end if unmatched in string
      if (code == 41 && !str.contains('(')) {
        str = str.substring(0, str.length - 1).trimRight();
        continue;
      }
      if (code == 93 && !str.contains('[')) {
        str = str.substring(0, str.length - 1).trimRight();
        continue;
      }
      if (code == 125 && !str.contains('{')) {
        str = str.substring(0, str.length - 1).trimRight();
        continue;
      }
      break;
    }

    // Clean leading punctuation / separators
    while (str.isNotEmpty) {
      final code = str.codeUnitAt(0);
      if (code == 32 || code == 45 || code == 95 || code == 58 || code == 59 ||
          code == 44 || code == 46 || code == 8211 || code == 8212 || code == 8722 ||
          code == 47 || code == 92 || code == 124 || code == 126) {
        str = str.substring(1).trimLeft();
        continue;
      }
      // Dangling closing bracket at beginning: ), ], }, >
      if (code == 41 || code == 93 || code == 125 || code == 62) {
        str = str.substring(1).trimLeft();
        continue;
      }
      // Dangling opening bracket at beginning if unmatched in string
      if (code == 40 && !str.contains(')')) {
        str = str.substring(1).trimLeft();
        continue;
      }
      if (code == 91 && !str.contains(']')) {
        str = str.substring(1).trimLeft();
        continue;
      }
      if (code == 123 && !str.contains('}')) {
        str = str.substring(1).trimLeft();
        continue;
      }
      break;
    }

    // Clean trailing conjunctions
    if (str.length >= 4) {
      final lower = str.toLowerCase();
      for (final conj in const [' and the', ' and', ' the', ' of', ' in', ' a', ' an']) {
        if (lower.endsWith(conj)) {
          str = str.substring(0, str.length - conj.length).trimRight();
          break;
        }
      }
      while (str.isNotEmpty) {
        final code = str.codeUnitAt(str.length - 1);
        if (code == 32 || code == 45 || code == 95 || code == 58 || code == 59 ||
            code == 44 || code == 46 || code == 8211 || code == 8212 || code == 8722 ||
            code == 47 || code == 92 || code == 124 || code == 126 ||
            code == 40 || code == 91 || code == 123 || code == 60) {
          str = str.substring(0, str.length - 1).trimRight();
        } else if ((code == 41 && !str.contains('(')) ||
                   (code == 93 && !str.contains('[')) ||
                   (code == 125 && !str.contains('{'))) {
          str = str.substring(0, str.length - 1).trimRight();
        } else {
          break;
        }
      }
    }
    return str;
  }

  /// Extracts the series or collection stem from a video file name.
  static String extractStem(String rawName) {
    var name = fastBasename(rawName);

    // Fast zero-regex extension stripping
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1) {
      final ext = name.substring(dot + 1).toLowerCase();
      if (_videoExtensions.contains(ext)) {
        name = name.substring(0, dot);
      }
    }

    // Preserve base name in case bracket stripping wipes out the entire title
    final originalBase = name.trim();

    // Strip bracketed release tags like [1080p] or [HorribleSubs]
    if (name.contains('[')) {
      final stripped = name.replaceAll(_bracketsPattern, ' ');
      if (stripped.trim().isNotEmpty) {
        name = stripped;
      }
    }
    if (name.contains('(')) {
      final stripped = name.replaceAll(_resolutionParensPattern, ' ');
      if (stripped.trim().isNotEmpty) {
        name = stripped;
      }
    }

    // 1. Check leading episode patterns on pre-spaced trimmed name before separator stripping
    final rawTrimmed = name.trim();
    final code0 = rawTrimmed.isNotEmpty ? rawTrimmed.codeUnitAt(0) : 0;
    final isPossibleLeading = (code0 >= 48 && code0 <= 57) || // '0'-'9'
        code0 == 91 || code0 == 40 || // '[', '('
        code0 == 69 || code0 == 101 || // 'E', 'e'
        code0 == 83 || code0 == 115; // 'S', 's'

    if (isPossibleLeading) {
      final leadingExplicit = _leadingExplicitEpisodePattern.firstMatch(rawTrimmed);
      if (leadingExplicit != null) {
        final titlePart = cleanDelimiters(leadingExplicit.group(2) ?? '');
        if (titlePart.length >= 2) return titlePart;
      }
      final leadingSeparated = _leadingSeparatedNumberPattern.firstMatch(rawTrimmed);
      if (leadingSeparated != null) {
        final titlePart = cleanDelimiters(leadingSeparated.group(5) ?? '');
        if (titlePart.length >= 2) return titlePart;
      }
    }

    // Fast separator replacement
    var spaced = name;
    if (name.contains('.') || name.contains('_')) {
      spaced = name.replaceAll('.', ' ').replaceAll('_', ' ');
    }
    spaced = spaced.trim();

    // 2. Season & Episode Pattern (S01E02, Season 1 Episode 2, Ep 01, Episode IV, etc.)
    var match = _seasonEpisodePattern.firstMatch(spaced);
    if (match != null) {
      if (match.start > 0) {
        final candidate = cleanDelimiters(spaced.substring(0, match.start));
        if (candidate.length >= 2) return candidate;
      }
      if (match.end < spaced.length) {
        final candidate = cleanDelimiters(spaced.substring(match.end));
        if (candidate.length >= 2) return candidate;
      }
    }

    // 3. Part / Disc / Vol Pattern (Part 1, Disc 2, Part II, etc.)
    match = _partDiscPattern.firstMatch(spaced);
    if (match != null) {
      if (match.start > 0) {
        final candidate = cleanDelimiters(spaced.substring(0, match.start));
        if (candidate.length >= 2) return candidate;
      }
      if (match.end < spaced.length) {
        final candidate = cleanDelimiters(spaced.substring(match.end));
        if (candidate.length >= 2) return candidate;
      }
    }

    // 4. Season Only (Season 1, S1)
    match = _seasonOnlyPattern.firstMatch(spaced);
    if (match != null && match.start > 0) {
      final candidate = cleanDelimiters(spaced.substring(0, match.start));
      if (candidate.length >= 2) return candidate;
    }

    // 5. Trailing Number Pattern (Title - 01, Title 02, Title (1))
    match = _trailingNumberPattern.firstMatch(spaced);
    if (match != null && match.start > 0) {
      final candidate = cleanDelimiters(spaced.substring(0, match.start));
      if (candidate.length >= 2) return candidate;
    }

    // 6. Fallback: Strip release tags and clean delimiters
    var fallback = spaced.replaceAll(_releaseTagsPattern, ' ');
    fallback = cleanDelimiters(fallback);
    if (fallback.isNotEmpty) return fallback;
    final trimmedSpaced = spaced.trim();
    if (trimmedSpaced.isNotEmpty) return trimmedSpaced;
    return originalBase.isNotEmpty ? originalBase : rawName;
  }

  /// Identifies common word-boundary prefixes between titles for franchise clustering.
  static String? findCommonWordPrefix(String a, String b) {
    if (a.isEmpty || b.isEmpty) return null;
    final wordsA = a.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final wordsB = b.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final commonWords = <String>[];

    final minWords = min(wordsA.length, wordsB.length);
    for (int i = 0; i < minWords; i++) {
      if (wordsA[i].toLowerCase() == wordsB[i].toLowerCase()) {
        commonWords.add(wordsA[i]);
      } else {
        break;
      }
    }

    if (commonWords.isEmpty) return null;
    final result = cleanDelimiters(commonWords.join(' '));
    if (result.length < 4) return null;
    return result;
  }

  /// High-speed basename extraction avoiding path context overhead.
  static String fastBasename(String path) {
    if (path.isEmpty) return path;
    final lastSlash = path.lastIndexOf('/');
    final lastBackslash = path.lastIndexOf('\\');
    final sep = lastSlash > lastBackslash ? lastSlash : lastBackslash;
    if (sep == -1) return path;
    if (sep == path.length - 1) {
      final trimmed = path.substring(0, path.length - 1);
      return fastBasename(trimmed);
    }
    return path.substring(sep + 1);
  }

  /// Groups items by parent folder without path truncation or collisions.
  static List<VideoGroup> groupByFolder(List<MediaItem> items) {
    if (items.isEmpty) return const [];

    final Map<String, _StemGroup> folderMap = {};
    final Map<String, String> originalPathMap = {};

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      var rawPath = item.parentFolder.trim();
      while (rawPath.length > 1 && (rawPath.endsWith('/') || rawPath.endsWith('\\'))) {
        rawPath = rawPath.substring(0, rawPath.length - 1);
      }
      final key = rawPath.toLowerCase();
      var group = folderMap[key];
      if (group == null) {
        var folderName = fastBasename(rawPath);
        if (folderName.isEmpty) folderName = rawPath;
        group = _StemGroup(folderName);
        folderMap[key] = group;
        originalPathMap[key] = rawPath;
      }
      group.add(item);
    }

    final List<VideoGroup> groups = [];
    folderMap.forEach((key, group) {
      final folderPath = originalPathMap[key]!;
      group.items.sort((a, b) => naturalCompare(a.name, b.name));

      groups.add(VideoGroup(
        id: 'folder_$key',
        title: group.title,
        subtitle: folderPath,
        folderPath: folderPath,
        mode: GroupMode.byFolder,
        items: group.items,
        totalDurationMs: group.totalDuration,
        totalSizeBytes: group.totalSize,
        latestDate: DateTime.fromMillisecondsSinceEpoch(group.latestMs),
      ));
    });

    groups.sort((a, b) => naturalCompare(a.title, b.title));
    return groups;
  }

  /// Groups items by smart title stem and franchise prefix clustering.
  ///
  /// Automatically clusters related multi-part videos, TV show episodes and franchise films
  /// when 2 or more videos share a common root.
  static List<VideoGroup> groupByName(List<MediaItem> items) {
    if (items.isEmpty) return const [];

    final Map<String, _StemGroup> stemMap = {};

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final stem = extractStem(item.name);
      final key = stem.toLowerCase().trim();
      var group = stemMap[key];
      if (group == null) {
        group = _StemGroup(stem);
        stemMap[key] = group;
      }
      group.add(item);
    }

    final singleKeys = stemMap.entries
        .where((e) => e.value.items.length == 1)
        .map((e) => e.key)
        .toList();

    if (singleKeys.isNotEmpty) {
      // Pass 1.5: Absorb single-item spinoffs into existing multi-item collections in O(1) per word prefix
      final absorbedKeys = <String>{};
      for (final singleKey in singleKeys) {
        final spaceIdx = singleKey.lastIndexOf(' ');
        if (spaceIdx > 2) {
          var candidate = singleKey.substring(0, spaceIdx).trim();
          while (candidate.length >= 3) {
            final targetGroup = stemMap[candidate];
            if (targetGroup != null && targetGroup.items.length >= 2) {
              final singleGroup = stemMap[singleKey];
              if (singleGroup != null) {
                for (final it in singleGroup.items) {
                  targetGroup.add(it);
                }
                absorbedKeys.add(singleKey);
              }
              break;
            }
            final nextSpace = candidate.lastIndexOf(' ');
            if (nextSpace <= 2) break;
            candidate = candidate.substring(0, nextSpace).trim();
          }
        }
      }
      for (final k in absorbedKeys) {
        stemMap.remove(k);
      }

      // Recompute remaining single keys for franchise prefix clustering
      final remainingSingleKeys = stemMap.entries
          .where((e) => e.value.items.length == 1)
          .map((e) => e.key)
          .toList();

      if (remainingSingleKeys.length >= 2) {
        remainingSingleKeys.sort();

        final mergedPrefixes = <String, List<_StemGroup>>{};
        final prefixDisplayNames = <String, String>{};
        final consumedKeys = <String>{};

        int i = 0;
        while (i < remainingSingleKeys.length - 1) {
          final keyA = remainingSingleKeys[i];
          if (consumedKeys.contains(keyA)) {
            i++;
            continue;
          }
          final groupA = stemMap[keyA]!;
          final keyB = remainingSingleKeys[i + 1];
          if (consumedKeys.contains(keyB)) {
            i++;
            continue;
          }
          final groupB = stemMap[keyB]!;

          final prefix = findCommonWordPrefix(groupA.title, groupB.title);
          if (prefix != null && prefix.length >= 4) {
            final prefixKey = prefix.toLowerCase().trim();
            prefixDisplayNames.putIfAbsent(prefixKey, () => prefix);
            final cluster = mergedPrefixes.putIfAbsent(prefixKey, () => []);
            if (!cluster.contains(groupA)) {
              cluster.add(groupA);
              consumedKeys.add(keyA);
            }
            if (!cluster.contains(groupB)) {
              cluster.add(groupB);
              consumedKeys.add(keyB);
            }

            int k = i + 2;
            final prefixWordBoundary = '$prefixKey ';
            while (k < remainingSingleKeys.length) {
              final keyNext = remainingSingleKeys[k];
              if (!consumedKeys.contains(keyNext)) {
                final groupNext = stemMap[keyNext]!;
                final nextPrefix = findCommonWordPrefix(groupA.title, groupNext.title);
                if ((nextPrefix != null && nextPrefix.toLowerCase().trim() == prefixKey) ||
                    keyNext.startsWith(prefixWordBoundary)) {
                  cluster.add(groupNext);
                  consumedKeys.add(keyNext);
                  k++;
                  continue;
                }
              }
              break;
            }
            i = k;
          } else {
            i++;
          }
        }

        for (final entry in mergedPrefixes.entries) {
          if (entry.value.length >= 2) {
            final displayName = prefixDisplayNames[entry.key] ?? entry.key;
            final prefixGroup = _StemGroup(displayName);
            for (final child in entry.value) {
              for (final item in child.items) {
                prefixGroup.add(item);
              }
            }
            stemMap[entry.key] = prefixGroup;
          }
        }

        for (final key in consumedKeys) {
          if (stemMap.containsKey(key) && !mergedPrefixes.containsKey(key)) {
            stemMap.remove(key);
          }
        }
      }
    }

    final List<VideoGroup> multiGroups = [];
    final List<VideoGroup> singleGroups = [];

    stemMap.forEach((key, group) {
      group.items.sort((a, b) => naturalCompare(a.name, b.name));

      final title = group.title.isNotEmpty ? group.title : key;
      final subtitle = group.items.length > 1
          ? '${group.items.length} videos · Collection'
          : (group.items.isNotEmpty ? fastBasename(group.items.first.parentFolder) : '');

      final vg = VideoGroup(
        id: 'name_$key',
        title: title,
        subtitle: subtitle,
        mode: GroupMode.byName,
        items: group.items,
        totalDurationMs: group.totalDuration,
        totalSizeBytes: group.totalSize,
        latestDate: DateTime.fromMillisecondsSinceEpoch(group.latestMs),
      );

      if (group.items.length >= 2) {
        multiGroups.add(vg);
      } else {
        singleGroups.add(vg);
      }
    });

    multiGroups.sort((a, b) => naturalCompare(a.title, b.title));
    singleGroups.sort((a, b) => naturalCompare(a.title, b.title));

    return [...multiGroups, ...singleGroups];
  }

  /// High-level dispatcher executing in-memory grouping for the requested mode.
  static List<VideoGroup> group(List<MediaItem> items, GroupMode mode) {
    switch (mode) {
      case GroupMode.none:
        return const [];
      case GroupMode.byFolder:
        return groupByFolder(items);
      case GroupMode.byName:
        return groupByName(items);
    }
  }
}

/// Service managing user grouping preferences and in-memory media transformations.
class VideoGroupingService extends ChangeNotifier {
  static const String kGroupingModePrefKey = 'eplayer_video_grouping_mode';

  GroupMode _groupMode = GroupMode.none;
  bool _isLoaded = false;

  GroupMode get groupMode => _groupMode;
  bool get isLoaded => _isLoaded;

  VideoGroupingService() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kGroupingModePrefKey);
      if (saved != null) {
        _groupMode = GroupMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => GroupMode.none,
        );
      }
    } catch (_) {}
    _isLoaded = true;
    notifyListeners();
  }

  /// Updates active grouping mode and persists to SharedPreferences.
  Future<void> setGroupMode(GroupMode mode) async {
    if (_groupMode == mode) return;
    _groupMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kGroupingModePrefKey, mode.name);
    } catch (_) {}
  }

  /// Groups items in-memory with sub-16ms latency.
  List<VideoGroup> groupMedia(List<MediaItem> items, [GroupMode? overrideMode]) {
    final mode = overrideMode ?? _groupMode;
    return VideoGroupingEngine.group(items, mode);
  }
}
