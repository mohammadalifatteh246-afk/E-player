import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app/core/models/media_item.dart';
import 'package:app/features/library/domain/media_scanner_service.dart';
import 'package:app/features/library/domain/media_search_engine.dart';
import 'package:app/features/library/domain/library_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MediaScannerService - Extension Whitelist & Blacklist (VLC Parity)', () {
    test('Validates recognized video extensions matching VLC', () {
      expect(MediaScannerService.isVideo('movie.mp4'), isTrue);
      expect(MediaScannerService.isVideo('film.mkv'), isTrue);
      expect(MediaScannerService.isVideo('clip.avi'), isTrue);
      expect(MediaScannerService.isVideo('sample.webm'), isTrue);
      expect(MediaScannerService.isVideo('video.mov'), isTrue);
      expect(MediaScannerService.isVideo('stream.ts'), isTrue);
      expect(MediaScannerService.isVideo('archive.vob'), isTrue);
      expect(MediaScannerService.isVideo('legacy.wmv'), isTrue);

      expect(MediaScannerService.isVideo('song.mp3'), isFalse);
      expect(MediaScannerService.isVideo('notes.txt'), isFalse);
    });

    test('Validates recognized audio extensions matching VLC', () {
      expect(MediaScannerService.isAudio('song.mp3'), isTrue);
      expect(MediaScannerService.isAudio('album.flac'), isTrue);
      expect(MediaScannerService.isAudio('track.m4a'), isTrue);
      expect(MediaScannerService.isAudio('record.wav'), isTrue);
      expect(MediaScannerService.isAudio('voice.opus'), isTrue);
      expect(MediaScannerService.isAudio('podcast.aac'), isTrue);

      expect(MediaScannerService.isAudio('movie.mp4'), isFalse);
      expect(MediaScannerService.isAudio('thumb.jpg'), isFalse);
    });

    test('Rejects blacklisted and ignored file extensions (matches VLC ignore-filetypes)', () {
      expect(MediaScannerService.isMediaFile('movie.nfo'), isFalse);
      expect(MediaScannerService.isMediaFile('desktop.ini'), isFalse);
      expect(MediaScannerService.isMediaFile('thumbs.db'), isFalse);
      expect(MediaScannerService.isMediaFile('cover.jpg'), isFalse);
      expect(MediaScannerService.isMediaFile('poster.png'), isFalse);
      expect(MediaScannerService.isMediaFile('checksum.sfv'), isFalse);
      expect(MediaScannerService.isMediaFile('readme.txt'), isFalse);
      expect(MediaScannerService.isMediaFile('patch.exe'), isFalse);
      expect(MediaScannerService.isMediaFile('codec.dll'), isFalse);
    });

    test('Discovers companion sidecar subtitles for media file', () async {
      final tempDir = await Directory.systemTemp.createTemp('eplayer_sub_test');
      try {
        final videoFile = File(p.join(tempDir.path, 'Inception (2010).mp4'));
        await videoFile.create();

        final subEn = File(p.join(tempDir.path, 'Inception (2010).en.srt'));
        await subEn.create();

        final subEs = File(p.join(tempDir.path, 'Inception (2010).es.vtt'));
        await subEs.create();

        final unrelatedSub = File(p.join(tempDir.path, 'OtherMovie.srt'));
        await unrelatedSub.create();

        final foundSubs = await MediaScannerService.findCompanionSubtitles(videoFile.path);

        expect(foundSubs.length, equals(2));
        expect(foundSubs.any((s) => s.endsWith('.en.srt')), isTrue);
        expect(foundSubs.any((s) => s.endsWith('.es.vtt')), isTrue);
        expect(foundSubs.any((s) => s.contains('OtherMovie')), isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Directory scanner skips hidden files and ignored files during scan', () async {
      final tempDir = await Directory.systemTemp.createTemp('eplayer_scan_test');
      try {
        // Valid video
        final video = File(p.join(tempDir.path, 'test_video.mp4'));
        await video.writeAsBytes([0, 1, 2, 3]);

        // Ignored file (.nfo)
        final nfo = File(p.join(tempDir.path, 'test_video.nfo'));
        await nfo.writeAsString('Movie metadata');

        // Hidden file
        final hidden = File(p.join(tempDir.path, '.hidden_video.mp4'));
        await hidden.writeAsBytes([0, 1]);

        final scanner = MediaScannerService();
        final progressEvents = await scanner.scanDirectories([tempDir.path], showHiddenFiles: false).toList();

        final lastProgress = progressEvents.last;
        expect(lastProgress.isCompleted, isTrue);
        expect(lastProgress.mediaFilesFound, equals(1));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('MediaSearchEngine - Live Multi-Token Search & Filter (VLC Parity)', () {
    final now = DateTime.now();
    final items = [
      MediaItem(
        path: '/storage/movies/The.Batman.2022.1080p.WEBRip.mp4',
        name: 'The.Batman.2022.1080p.WEBRip.mp4',
        parentFolder: '/storage/movies',
        sizeBytes: 2500000000,
        durationMs: 10540000,
        lastPlayed: now.subtract(const Duration(days: 1)),
      ),
      MediaItem(
        path: '/storage/movies/Interstellar.2014.4K.HDR.mkv',
        name: 'Interstellar.2014.4K.HDR.mkv',
        parentFolder: '/storage/movies',
        sizeBytes: 15000000000,
        durationMs: 10140000,
        lastPlayed: now.subtract(const Duration(days: 5)),
      ),
      MediaItem(
        path: '/storage/music/Daft Punk/Random Access Memories/01 - Give Life Back to Music.flac',
        name: '01 - Give Life Back to Music.flac',
        parentFolder: '/storage/music/Daft Punk/Random Access Memories',
        sizeBytes: 45000000,
        durationMs: 275000,
        lastPlayed: now.subtract(const Duration(days: 2)),
      ),
      MediaItem(
        path: '/storage/music/Hans Zimmer/Interstellar Soundtrack/Cornfield Chase.mp3',
        name: 'Cornfield Chase.mp3',
        parentFolder: '/storage/music/Hans Zimmer/Interstellar Soundtrack',
        sizeBytes: 9000000,
        durationMs: 130000,
        lastPlayed: now,
      ),
    ];

    test('Matches single token case-insensitively', () {
      expect(MediaSearchEngine.matchesQuery(items[0], 'batman'), isTrue);
      expect(MediaSearchEngine.matchesQuery(items[0], 'BATMAN'), isTrue);
      expect(MediaSearchEngine.matchesQuery(items[1], 'batman'), isFalse);
    });

    test('Matches multi-token query across title and parent folder (VLC input_item_MetaMatch)', () {
      // "interstellar 4k" -> matches Interstellar 4K HDR
      expect(MediaSearchEngine.matchesQuery(items[1], 'interstellar 4k'), isTrue);

      // "interstellar soundtrack" -> matches Cornfield Chase because "Interstellar Soundtrack" is in parent folder
      expect(MediaSearchEngine.matchesQuery(items[3], 'interstellar soundtrack'), isTrue);

      // "interstellar 4k" does NOT match the mp3 track
      expect(MediaSearchEngine.matchesQuery(items[3], 'interstellar 4k'), isFalse);
    });

    test('Filters by Category (Videos, Audio, All)', () {
      final videos = MediaSearchEngine.filterByCategory(items, MediaCategory.videos);
      expect(videos.length, equals(2));
      expect(videos.every((i) => MediaScannerService.isVideo(i.path)), isTrue);

      final audio = MediaSearchEngine.filterByCategory(items, MediaCategory.audio);
      expect(audio.length, equals(2));
      expect(audio.every((i) => MediaScannerService.isAudio(i.path)), isTrue);

      final all = MediaSearchEngine.filterByCategory(items, MediaCategory.all);
      expect(all.length, equals(4));
    });

    test('Sorts by Name, Date, Size, Duration', () {
      // Sort by Name Ascending
      final byNameAsc = MediaSearchEngine.sortItems(items, SortField.name, SortOrder.ascending);
      expect(byNameAsc.first.name, startsWith('01 - Give'));

      // Sort by Size Descending
      final bySizeDesc = MediaSearchEngine.sortItems(items, SortField.size, SortOrder.descending);
      expect(bySizeDesc.first.name, contains('Interstellar.2014.4K'));

      // Sort by Date Descending (Newest first)
      final byDateDesc = MediaSearchEngine.sortItems(items, SortField.date, SortOrder.descending);
      expect(byDateDesc.first.name, equals('Cornfield Chase.mp3'));
    });

    test('Full search pipeline executes combined query + category + sort', () {
      const options = MediaSearchOptions(
        query: 'interstellar',
        category: MediaCategory.audio,
        sortField: SortField.size,
        sortOrder: SortOrder.descending,
      );

      final results = MediaSearchEngine.execute(items, options);
      expect(results.length, equals(1));
      expect(results.first.name, equals('Cornfield Chase.mp3'));
    });
  });

  group('LibraryProvider - Search & Scan Integration', () {
    test('Reacts to search query and category changes', () async {
      final provider = LibraryProvider();

      provider.setSearchQuery('test query');
      expect(provider.searchOptions.query, equals('test query'));

      provider.setCategory(MediaCategory.videos);
      expect(provider.searchOptions.category, equals(MediaCategory.videos));

      provider.setSort(SortField.size, SortOrder.ascending);
      expect(provider.searchOptions.sortField, equals(SortField.size));
      expect(provider.searchOptions.sortOrder, equals(SortOrder.ascending));

      provider.toggleSortOrder();
      expect(provider.searchOptions.sortOrder, equals(SortOrder.descending));

      provider.clearSearch();
      expect(provider.searchOptions.query, isEmpty);
    });
  });
}
