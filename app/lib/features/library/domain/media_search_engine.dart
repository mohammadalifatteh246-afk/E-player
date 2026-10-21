import 'package:path/path.dart' as p;
import '../../../core/models/media_item.dart';
import 'media_scanner_service.dart';

enum MediaCategory {
  all,
  videos,
  audio,
  folders,
}

enum SortField {
  name,
  date,
  size,
  duration,
}

enum SortOrder {
  ascending,
  descending,
}

class MediaSearchOptions {
  final String query;
  final MediaCategory category;
  final SortField sortField;
  final SortOrder sortOrder;

  const MediaSearchOptions({
    this.query = '',
    this.category = MediaCategory.all,
    this.sortField = SortField.date,
    this.sortOrder = SortOrder.descending,
  });

  MediaSearchOptions copyWith({
    String? query,
    MediaCategory? category,
    SortField? sortField,
    SortOrder? sortOrder,
  }) {
    return MediaSearchOptions(
      query: query ?? this.query,
      category: category ?? this.category,
      sortField: sortField ?? this.sortField,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// High-performance search and filter engine inspired by VLC media player's
/// `playlist_LiveSearchUpdate` and `input_item_MetaMatch` algorithms.
class MediaSearchEngine {
  /// Evaluates whether a media item matches a multi-token query (parity with VLC `input_item_MetaMatch`).
  ///
  /// In VLC, a multi-word search requires EVERY token to match across the item's
  /// metadata (filename, path, or extension) in a case-insensitive manner.
  static bool matchesQuery(MediaItem item, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return true;

    // Tokenize query by whitespace (e.g. "mission impossible 1080p")
    final tokens = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return true;

    final lowerName = item.name.toLowerCase();
    final lowerFolder = item.parentFolder.toLowerCase();
    final ext = p.extension(item.path).toLowerCase();

    // Combined searchable metadata string
    final combinedMeta = '$lowerName $lowerFolder $ext';

    for (final token in tokens) {
      if (!combinedMeta.contains(token)) {
        return false;
      }
    }

    return true;
  }

  /// Filters a list of media items by category
  static List<MediaItem> filterByCategory(List<MediaItem> items, MediaCategory category) {
    switch (category) {
      case MediaCategory.all:
      case MediaCategory.folders:
        return items;
      case MediaCategory.videos:
        return items.where((item) => MediaScannerService.isVideo(item.path)).toList();
      case MediaCategory.audio:
        return items.where((item) => MediaScannerService.isAudio(item.path)).toList();
    }
  }

  /// Groups items by parent folder and filters folder names
  static Map<String, List<MediaItem>> filterFolders(
    Map<String, List<MediaItem>> groupedFolders,
    String query,
  ) {
    if (query.trim().isEmpty) return groupedFolders;

    final tokens = query.trim().toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final Map<String, List<MediaItem>> filtered = {};

    groupedFolders.forEach((folderPath, items) {
      final folderName = p.basename(folderPath).toLowerCase();
      bool matches = true;

      for (final token in tokens) {
        if (!folderName.contains(token) && !folderPath.toLowerCase().contains(token)) {
          matches = false;
          break;
        }
      }

      if (matches) {
        filtered[folderPath] = items;
      }
    });

    return filtered;
  }

  /// Sorts items according to the requested SortField and SortOrder
  static List<MediaItem> sortItems(
    List<MediaItem> items,
    SortField field,
    SortOrder order,
  ) {
    final sorted = List<MediaItem>.from(items);

    sorted.sort((a, b) {
      int comparison = 0;
      switch (field) {
        case SortField.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortField.date:
          comparison = a.lastPlayed.compareTo(b.lastPlayed);
          break;
        case SortField.size:
          comparison = a.sizeBytes.compareTo(b.sizeBytes);
          break;
        case SortField.duration:
          comparison = a.durationMs.compareTo(b.durationMs);
          break;
      }

      return order == SortOrder.ascending ? comparison : -comparison;
    });

    return sorted;
  }

  /// Executes full search, filtering, and sorting pipeline
  static List<MediaItem> execute(
    List<MediaItem> sourceItems,
    MediaSearchOptions options,
  ) {
    // 1. Filter by category
    var items = filterByCategory(sourceItems, options.category);

    // 2. Filter by search query (VLC input_item_MetaMatch multi-token matcher)
    if (options.query.trim().isNotEmpty) {
      items = items.where((item) => matchesQuery(item, options.query)).toList();
    }

    // 3. Sort items
    return sortItems(items, options.sortField, options.sortOrder);
  }
}
