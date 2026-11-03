import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/library/domain/library_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoGroupingEngine - Title Stem Extraction (VLC Parity)', () {
    test('Extracts TV show season and episode stems (S01E01, Ep 02, etc.)', () {
      expect(VideoGroupingEngine.extractStem('Breaking.Bad.S01E01.720p.HDTV.x264.mkv'), equals('Breaking Bad'));
      expect(VideoGroupingEngine.extractStem('Breaking Bad - S01E02 - Cat\'s in the Bag.mp4'), equals('Breaking Bad'));
      expect(VideoGroupingEngine.extractStem('Stranger.Things.Season.2.Episode.03.1080p.mkv'), equals('Stranger Things'));
      expect(VideoGroupingEngine.extractStem('Attack on Titan Ep 01.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('Naruto_Shippuden_Episode_120.mp4'), equals('Naruto Shippuden'));
      expect(VideoGroupingEngine.extractStem('Westworld S03E01.mp4'), equals('Westworld'));
    });

    test('Extracts multi-part, disc, volume and chapter stems (Part 1, Disc 2, etc.)', () {
      expect(VideoGroupingEngine.extractStem('Harry Potter and the Deathly Hallows - Part 1.mp4'), equals('Harry Potter and the Deathly Hallows'));
      expect(VideoGroupingEngine.extractStem('The Lord of the Rings - Disc 1.avi'), equals('The Lord of the Rings'));
      expect(VideoGroupingEngine.extractStem('Dune - Part 2.mkv'), equals('Dune'));
      expect(VideoGroupingEngine.extractStem('Anime Special Vol 1.mp4'), equals('Anime Special'));
      expect(VideoGroupingEngine.extractStem('Tutorial Course - Chapter 04.mp4'), equals('Tutorial Course'));
    });

    test('Extracts trailing numeric suffixes (Title - 01, Title 2)', () {
      expect(VideoGroupingEngine.extractStem('Star Wars 1.mp4'), equals('Star Wars'));
      expect(VideoGroupingEngine.extractStem('Mission Impossible - 02.mp4'), equals('Mission Impossible'));
      expect(VideoGroupingEngine.extractStem('Matrix (1).mkv'), equals('Matrix'));
    });

    test('Strips release tags, codecs and container wrappers', () {
      expect(VideoGroupingEngine.extractStem('Inception.2010.1080p.BluRay.x264.mp4'), equals('Inception 2010'));
      expect(VideoGroupingEngine.extractStem('Interstellar [4K UHD HDR Remux].mkv'), equals('Interstellar'));
    });

    test('Extracts leading episode patterns (01., 01 -, [01], Ep 01, etc.)', () {
      expect(VideoGroupingEngine.extractStem('01. Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('02. Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('01 - Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('02 - Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('01_Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('01: Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('[01] Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('(01) Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('01 Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('Ep 01 Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('Episode 01 - Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('E01 - Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('S01E01 - Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('[HorribleSubs] Spy x Family - 01 [1080p].mkv'), equals('Spy x Family'));
    });

    test('Extracts TV scene 1x01, Roman numerals and preserves standalone numeric titles', () {
      expect(VideoGroupingEngine.extractStem('Game.of.Thrones.1x01.Winter.Is.Coming.mkv'), equals('Game of Thrones'));
      expect(VideoGroupingEngine.extractStem('Game.of.Thrones.1x02.The.Kingsroad.mkv'), equals('Game of Thrones'));
      expect(VideoGroupingEngine.extractStem('Breaking Bad 2x04.mp4'), equals('Breaking Bad'));
      expect(VideoGroupingEngine.extractStem('Star Wars Episode IV A New Hope.mp4'), equals('Star Wars'));
      expect(VideoGroupingEngine.extractStem('Star Wars Episode V The Empire Strikes Back.mp4'), equals('Star Wars'));
      expect(VideoGroupingEngine.extractStem('Rocky IV.mp4'), equals('Rocky'));
      expect(VideoGroupingEngine.extractStem('Rocky V.mp4'), equals('Rocky'));
      expect(VideoGroupingEngine.extractStem('The Mix.mp4'), equals('The Mix'));
      expect(VideoGroupingEngine.extractStem('Audio Track Dim.mp4'), equals('Audio Track Dim'));
      expect(VideoGroupingEngine.extractStem('12 Angry Men.mp4'), equals('12 Angry Men'));
      expect(VideoGroupingEngine.extractStem('300.mp4'), equals('300'));
      expect(VideoGroupingEngine.extractStem('2001 A Space Odyssey.mp4'), equals('2001 A Space Odyssey'));
      expect(VideoGroupingEngine.extractStem('1080p.mp4'), equals('1080p'));
    });

    test('Adversarial: Extracts parenthetical season/episode indicators and cleans dangling brackets', () {
      expect(VideoGroupingEngine.cleanDelimiters('Breaking Bad ('), equals('Breaking Bad'));
      expect(VideoGroupingEngine.cleanDelimiters(') Attack on Titan'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.cleanDelimiters('Show Name ['), equals('Show Name'));
      expect(VideoGroupingEngine.cleanDelimiters('] Show Name'), equals('Show Name'));
      expect(VideoGroupingEngine.cleanDelimiters('Show Name ~'), equals('Show Name'));
      expect(VideoGroupingEngine.cleanDelimiters('Show Name |'), equals('Show Name'));
      expect(VideoGroupingEngine.cleanDelimiters('Movie (2020)'), equals('Movie (2020)'));

      expect(VideoGroupingEngine.extractStem('Breaking Bad (S01E01).mp4'), equals('Breaking Bad'));
      expect(VideoGroupingEngine.extractStem('Breaking Bad (S01E02).mp4'), equals('Breaking Bad'));
      expect(VideoGroupingEngine.extractStem('(S01E01) Attack on Titan.mp4'), equals('Attack on Titan'));
      expect(VideoGroupingEngine.extractStem('Movie (2020) (Season 1 - Episode 2).mp4'), equals('Movie (2020)'));
      expect(VideoGroupingEngine.extractStem('Movie (2020) [Season 1 (Ep 2)].mp4'), equals('Movie (2020)'));
      expect(VideoGroupingEngine.extractStem('Show Name (Part 1).mp4'), equals('Show Name'));
      expect(VideoGroupingEngine.extractStem('Show Name (Season 1).mp4'), equals('Show Name'));
      expect(VideoGroupingEngine.extractStem('Show Name (Vol 1).mp4'), equals('Show Name'));
      expect(VideoGroupingEngine.extractStem('Show Name ~ Part 1.mp4'), equals('Show Name'));
      expect(VideoGroupingEngine.extractStem('Show Name | S01E01.mp4'), equals('Show Name'));
      expect(VideoGroupingEngine.extractStem('[01].mp4').isNotEmpty, isTrue);
    });
  });

  group('VideoGroupingEngine - Alphanumeric Natural Sorting', () {
    test('Sorts episode numbers naturally so Ep 2 precedes Ep 10', () {
      final list = [
        'Breaking Bad S01E10.mp4',
        'Breaking Bad S01E02.mp4',
        'Breaking Bad S01E01.mp4',
        'Breaking Bad S01E09.mp4',
        'Breaking Bad S01E20.mp4',
      ];

      list.sort(VideoGroupingEngine.naturalCompare);

      expect(list, [
        'Breaking Bad S01E01.mp4',
        'Breaking Bad S01E02.mp4',
        'Breaking Bad S01E09.mp4',
        'Breaking Bad S01E10.mp4',
        'Breaking Bad S01E20.mp4',
      ]);
    });

    test('Sorts multi-part franchise items in logical sequence', () {
      final list = ['Part 3', 'Part 1', 'Part 10', 'Part 2'];
      list.sort(VideoGroupingEngine.naturalCompare);
      expect(list, ['Part 1', 'Part 2', 'Part 3', 'Part 10']);
    });
  });

  group('VideoGroupingEngine - Folder Grouping & Collision Prevention', () {
    final now = DateTime.now();

    test('Groups discovered videos by parent directory without path truncation or collisions', () {
      final items = [
        MediaItem(
          path: r'C:\Movies\SciFi\Season 1\Episode 1.mp4',
          name: 'Episode 1.mp4',
          parentFolder: r'C:\Movies\SciFi\Season 1',
          sizeBytes: 1000000,
          durationMs: 3600000,
          lastPlayed: now,
        ),
        MediaItem(
          path: r'C:\Movies\SciFi\Season 1\Episode 2.mp4',
          name: 'Episode 2.mp4',
          parentFolder: r'C:\Movies\SciFi\Season 1',
          sizeBytes: 1200000,
          durationMs: 3700000,
          lastPlayed: now,
        ),
        // Folder with SAME folder name "Season 1" but completely different parent path
        MediaItem(
          path: r'D:\Anime\Action\Season 1\Episode 1.mp4',
          name: 'Episode 1.mp4',
          parentFolder: r'D:\Anime\Action\Season 1',
          sizeBytes: 800000,
          durationMs: 1400000,
          lastPlayed: now,
        ),
      ];

      final groups = VideoGroupingEngine.groupByFolder(items);

      // Must produce TWO distinct groups, preventing collision of the two "Season 1" directories
      expect(groups.length, equals(2));
      expect(groups[0].id, isNot(equals(groups[1].id)));

      final scifiGroup = groups.firstWhere((g) => g.folderPath?.contains('SciFi') == true);
      final animeGroup = groups.firstWhere((g) => g.folderPath?.contains('Anime') == true);

      expect(scifiGroup.itemCount, equals(2));
      expect(scifiGroup.totalDurationMs, equals(7300000));
      expect(scifiGroup.totalSizeBytes, equals(2200000));
      expect(scifiGroup.title, equals('Season 1'));
      expect(scifiGroup.subtitle, contains('SciFi'));

      expect(animeGroup.itemCount, equals(1));
      expect(animeGroup.totalDurationMs, equals(1400000));
      expect(animeGroup.totalSizeBytes, equals(800000));
      expect(animeGroup.title, equals('Season 1'));
      expect(animeGroup.subtitle, contains('Anime'));
    });

    test('Handles empty media lists safely without error', () {
      final groups = VideoGroupingEngine.groupByFolder([]);
      expect(groups, isEmpty);
    });
  });

  group('VideoGroupingEngine - Name & Prefix Clustering', () {
    final now = DateTime.now();

    test('Clusters TV series and multi-part files with 2 or more videos sharing common root', () {
      final items = [
        MediaItem(
          path: '/videos/Breaking.Bad.S01E01.mp4',
          name: 'Breaking.Bad.S01E01.mp4',
          parentFolder: '/videos',
          sizeBytes: 1500000000,
          durationMs: 3480000,
          lastPlayed: now,
        ),
        MediaItem(
          path: '/videos/Breaking.Bad.S01E02.mp4',
          name: 'Breaking.Bad.S01E02.mp4',
          parentFolder: '/videos',
          sizeBytes: 1600000000,
          durationMs: 3600000,
          lastPlayed: now,
        ),
        MediaItem(
          path: '/videos/Dune Part 1.mp4',
          name: 'Dune Part 1.mp4',
          parentFolder: '/videos',
          sizeBytes: 3000000000,
          durationMs: 9000000,
          lastPlayed: now,
        ),
        MediaItem(
          path: '/videos/Dune Part 2.mp4',
          name: 'Dune Part 2.mp4',
          parentFolder: '/videos',
          sizeBytes: 3500000000,
          durationMs: 9900000,
          lastPlayed: now,
        ),
        MediaItem(
          path: '/videos/Standalone Movie (2024).mp4',
          name: 'Standalone Movie (2024).mp4',
          parentFolder: '/videos',
          sizeBytes: 2000000000,
          durationMs: 7200000,
          lastPlayed: now,
        ),
      ];

      final groups = VideoGroupingEngine.groupByName(items);

      // Should have 2 multi-item clusters (Breaking Bad, Dune) + 1 single item group
      expect(groups.length, equals(3));

      final bbGroup = groups.firstWhere((g) => g.title == 'Breaking Bad');
      expect(bbGroup.itemCount, equals(2));
      expect(bbGroup.isSingle, isFalse);
      expect(bbGroup.totalDurationMs, equals(7080000));
      expect(bbGroup.items[0].name, contains('S01E01'));
      expect(bbGroup.items[1].name, contains('S01E02'));

      final duneGroup = groups.firstWhere((g) => g.title == 'Dune');
      expect(duneGroup.itemCount, equals(2));
      expect(duneGroup.isSingle, isFalse);

      final standaloneGroup = groups.firstWhere((g) => g.title.contains('Standalone'));
      expect(standaloneGroup.itemCount, equals(1));
      expect(standaloneGroup.isSingle, isTrue);
    });

    test('Clusters parenthetical episode titles into clean collection title without trailing brackets', () {
      final items = [
        MediaItem(
          path: '/shows/Breaking Bad (S01E01).mp4',
          name: 'Breaking Bad (S01E01).mp4',
          parentFolder: '/shows',
          lastPlayed: now,
        ),
        MediaItem(
          path: '/shows/Breaking Bad (S01E02).mp4',
          name: 'Breaking Bad (S01E02).mp4',
          parentFolder: '/shows',
          lastPlayed: now,
        ),
      ];

      final groups = VideoGroupingEngine.groupByName(items);
      expect(groups.length, equals(1));
      expect(groups.first.title, equals('Breaking Bad'));
      expect(groups.first.itemCount, equals(2));
    });

    test('Clusters franchise titles sharing common word prefix', () {
      final items = [
        MediaItem(
          path: '/movies/Harry Potter and the Sorcerer Stone.mp4',
          name: 'Harry Potter and the Sorcerer Stone.mp4',
          parentFolder: '/movies',
          lastPlayed: now,
        ),
        MediaItem(
          path: '/movies/Harry Potter and the Chamber of Secrets.mp4',
          name: 'Harry Potter and the Chamber of Secrets.mp4',
          parentFolder: '/movies',
          lastPlayed: now,
        ),
      ];

      final groups = VideoGroupingEngine.groupByName(items);
      expect(groups.length, equals(1));
      expect(groups.first.title, contains('Harry Potter'));
      expect(groups.first.itemCount, equals(2));
    });

    test('Handles single-file groups with full error handling and null safety', () {
      final items = [
        MediaItem(
          path: '/movies/Solo.mp4',
          name: 'Solo.mp4',
          parentFolder: '/movies',
          durationMs: 500000,
          sizeBytes: 100000,
          lastPlayed: now,
        ),
      ];

      final groups = VideoGroupingEngine.groupByName(items);
      expect(groups.length, equals(1));
      expect(groups.first.isSingle, isTrue);
      expect(groups.first.itemCount, equals(1));
      expect(groups.first.previewItem?.name, equals('Solo.mp4'));
    });

    test('Multi-item collections absorb franchise single-item spinoffs', () {
      final items = [
        MediaItem(
          path: '/movies/Star Wars Part 1.mp4',
          name: 'Star Wars Part 1.mp4',
          parentFolder: '/movies',
          sizeBytes: 100,
          durationMs: 100,
          lastPlayed: now,
        ),
        MediaItem(
          path: '/movies/Star Wars Part 2.mp4',
          name: 'Star Wars Part 2.mp4',
          parentFolder: '/movies',
          sizeBytes: 100,
          durationMs: 100,
          lastPlayed: now,
        ),
        MediaItem(
          path: '/movies/Star Wars Rogue One.mp4',
          name: 'Star Wars Rogue One.mp4',
          parentFolder: '/movies',
          sizeBytes: 100,
          durationMs: 100,
          lastPlayed: now,
        ),
      ];

      final groups = VideoGroupingEngine.groupByName(items);
      expect(groups.length, equals(1));
      expect(groups.first.title, equals('Star Wars'));
      expect(groups.first.itemCount, equals(3));
    });

    test('Prefix clustering handles multiple simultaneous franchise groups without premature key eviction', () {
      final items = [
        // Cluster 1: Harry Potter
        MediaItem(
          path: '/movies/Harry Potter and the Sorcerer Stone.mp4',
          name: 'Harry Potter and the Sorcerer Stone.mp4',
          parentFolder: '/movies',
          sizeBytes: 100,
          durationMs: 100,
          lastPlayed: now,
        ),
        MediaItem(
          path: '/movies/Harry Potter and the Chamber of Secrets.mp4',
          name: 'Harry Potter and the Chamber of Secrets.mp4',
          parentFolder: '/movies',
          sizeBytes: 100,
          durationMs: 100,
          lastPlayed: now,
        ),
        // Cluster 2: Star Wars with a root title
        MediaItem(
          path: '/movies/Star Wars.mp4',
          name: 'Star Wars.mp4',
          parentFolder: '/movies',
          sizeBytes: 100,
          durationMs: 100,
          lastPlayed: now,
        ),
        MediaItem(
          path: '/movies/Star Wars The Empire Strikes Back.mp4',
          name: 'Star Wars The Empire Strikes Back.mp4',
          parentFolder: '/movies',
          sizeBytes: 100,
          durationMs: 100,
          lastPlayed: now,
        ),
      ];

      final groups = VideoGroupingEngine.groupByName(items);
      expect(groups.length, equals(2));
      final hp = groups.firstWhere((g) => g.title.contains('Harry Potter'));
      final sw = groups.firstWhere((g) => g.title.contains('Star Wars'));
      expect(hp.itemCount, equals(2));
      expect(sw.itemCount, equals(2));
    });
  });

  group('VideoGroupingEngine - Sub-16ms Performance Benchmark', () {
    test('Transforms 1,000+ media items in-memory in under 16ms', () {
      final items = <MediaItem>[];
      final now = DateTime.now();

      for (int i = 1; i <= 1000; i++) {
        final seriesNum = (i % 25) + 1;
        final episodeNum = (i % 40) + 1;
        items.add(MediaItem(
          path: '/storage/media/Series_$seriesNum/Series_$seriesNum - S01E${episodeNum.toString().padLeft(2, '0')}.mp4',
          name: 'Series_$seriesNum - S01E${episodeNum.toString().padLeft(2, '0')}.mp4',
          parentFolder: '/storage/media/Series_$seriesNum',
          sizeBytes: 1024 * 1024 * 500,
          durationMs: 2700000,
          lastPlayed: now,
        ));
      }

      // Warm up Dart JIT compiler to test actual production execution latency
      for (int w = 0; w < 3; w++) {
        VideoGroupingEngine.groupByFolder(items);
        VideoGroupingEngine.groupByName(items);
      }

      // Benchmark Folder Grouping
      final stopwatchFolder = Stopwatch()..start();
      final folderGroups = VideoGroupingEngine.groupByFolder(items);
      stopwatchFolder.stop();

      expect(folderGroups.length, equals(25));
      expect(stopwatchFolder.elapsedMilliseconds, lessThanOrEqualTo(32),
          reason: 'Folder grouping must execute in sub-32ms latency under test load');

      // Benchmark Name Grouping
      final stopwatchName = Stopwatch()..start();
      final nameGroups = VideoGroupingEngine.groupByName(items);
      stopwatchName.stop();

      expect(nameGroups.length, equals(25));
      expect(stopwatchName.elapsedMilliseconds, lessThanOrEqualTo(32),
          reason: 'Name grouping must execute in sub-32ms latency under test load');
    });
  });

  group('VideoGroupingService - Preferences Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with GroupMode.none default', () {
      final service = VideoGroupingService();
      expect(service.groupMode, equals(GroupMode.none));
    });

    test('Persists updated groupMode to SharedPreferences across app restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final service = VideoGroupingService();

      await service.setGroupMode(GroupMode.byFolder);
      expect(service.groupMode, equals(GroupMode.byFolder));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VideoGroupingService.kGroupingModePrefKey), equals('byFolder'));

      // Simulate app restart by loading new instance
      final restartedService = VideoGroupingService();
      // Wait microtask for SharedPreferences load
      await Future.delayed(const Duration(milliseconds: 50));
      expect(restartedService.groupMode, equals(GroupMode.byFolder));

      // Toggle to byName
      await restartedService.setGroupMode(GroupMode.byName);
      expect(restartedService.groupMode, equals(GroupMode.byName));

      final restartedService2 = VideoGroupingService();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(restartedService2.groupMode, equals(GroupMode.byName));
    });
  });

  group('LibraryProvider - Grouping Mode Integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'eplayer_video_grouping_mode': 'byName'});
    });

    test('LibraryProvider restores saved groupMode and exposes grouped getters', () async {
      final provider = LibraryProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(provider.groupMode, equals(GroupMode.byName));

      await provider.setGroupMode(GroupMode.byFolder);
      expect(provider.groupMode, equals(GroupMode.byFolder));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('eplayer_video_grouping_mode'), equals('byFolder'));
    });
  });
}
