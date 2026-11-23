import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:app/features/cdda/domain/cdda_models.dart';
import 'package:app/features/cdda/data/cue_sheet_parser.dart';
import 'package:app/features/cdda/data/audio_cd_ripper_service.dart';

void main() {
  group('CDDA & Audio Rip Models', () {
    test('AudioRipFormat provides correct codecs, extensions and bitrates', () {
      expect(AudioRipFormat.flac.codec, 'flac');
      expect(AudioRipFormat.flac.extension, 'flac');
      expect(AudioRipFormat.flac.isLossless, isTrue);

      expect(AudioRipFormat.mp3.codec, 'libmp3lame');
      expect(AudioRipFormat.mp3.extension, 'mp3');
      expect(AudioRipFormat.mp3.bitrateKbps, 320);

      expect(AudioRipFormat.aac.codec, 'aac');
      expect(AudioRipFormat.aac.extension, 'm4a');

      expect(AudioRipFormat.wav.codec, 'pcm_s16le');
      expect(AudioRipFormat.wav.extension, 'wav');

      expect(AudioRipFormat.opus.codec, 'libopus');
      expect(AudioRipFormat.opus.extension, 'opus');
    });

    test('CdTrackInfo and AudioCdDiscInfo serialize and deserialize correctly', () {
      final track = CdTrackInfo(
        trackNumber: 1,
        title: 'Time',
        artist: 'Pink Floyd',
        startOffset: const Duration(minutes: 7, seconds: 5),
        duration: const Duration(minutes: 6, seconds: 53),
        startSector: 31875,
      );

      final disc = AudioCdDiscInfo(
        albumTitle: 'The Dark Side of the Moon',
        artist: 'Pink Floyd',
        genre: 'Progressive Rock',
        releaseYear: '1973',
        audioSourcePath: '/music/dark_side.wav',
        cueSheetPath: '/music/dark_side.cue',
        tracks: [track],
      );

      final json = disc.toJson();
      expect(json['albumTitle'], 'The Dark Side of the Moon');
      expect(json['genre'], 'Progressive Rock');

      final restored = AudioCdDiscInfo.fromJson(json);
      expect(restored.albumTitle, 'The Dark Side of the Moon');
      expect(restored.tracks.length, 1);
      expect(restored.tracks.first.title, 'Time');
      expect(restored.tracks.first.formattedDuration, '06:53');
      expect(restored.formattedTotalDuration, '06:53');
    });
  });

  group('CueSheetParser Red Book & Metadata Parsing', () {
    test('framesToDuration converts 75 fps Red Book frames accurately', () {
      // 00:00:00 -> 0s
      expect(CueSheetParser.framesToDuration('00:00:00'), Duration.zero);

      // 01:30:00 -> 1 min 30 sec
      expect(
        CueSheetParser.framesToDuration('01:30:00'),
        const Duration(minutes: 1, seconds: 30),
      );

      // 00:01:37 -> 1 sec + 37 frames (37 * 1000 / 75 = 493ms)
      final d = CueSheetParser.framesToDuration('00:01:37');
      expect(d.inSeconds, 1);
      expect(d.inMilliseconds, 1493);

      // framesToSector
      expect(CueSheetParser.framesToSector('00:01:00'), 75);
      expect(CueSheetParser.framesToSector('01:00:00'), 4500);
    });

    test('parseCueString extracts album metadata and tracks with calculated intervals', () {
      const cueContent = '''
REM GENRE "Soundtrack"
REM DATE 2014
PERFORMER "Hans Zimmer"
TITLE "Interstellar OST"
FILE "Interstellar.wav" WAVE
  TRACK 01 AUDIO
    TITLE "Dreaming of the Crash"
    PERFORMER "Hans Zimmer"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Cornfield Chase"
    PERFORMER "Hans Zimmer"
    INDEX 01 03:55:00
  TRACK 03 AUDIO
    TITLE "Dust"
    PERFORMER "Hans Zimmer"
    INDEX 01 06:01:00
''';

      final disc = CueSheetParser.parseCueString(
        cueContent,
        cuePath: '/music/Interstellar.cue',
        totalAudioDuration: const Duration(minutes: 10),
      );

      expect(disc.albumTitle, 'Interstellar OST');
      expect(disc.artist, 'Hans Zimmer');
      expect(disc.genre, 'Soundtrack');
      expect(disc.releaseYear, '2014');
      expect(disc.tracks.length, 3);

      // Track 1: starts at 00:00, duration until Track 2 (03:55) = 3m 55s
      expect(disc.tracks[0].trackNumber, 1);
      expect(disc.tracks[0].title, 'Dreaming of the Crash');
      expect(disc.tracks[0].startOffset, Duration.zero);
      expect(disc.tracks[0].duration, const Duration(minutes: 3, seconds: 55));

      // Track 2: starts at 03:55, duration until Track 3 (06:01) = 2m 06s
      expect(disc.tracks[1].trackNumber, 2);
      expect(disc.tracks[1].title, 'Cornfield Chase');
      expect(disc.tracks[1].startOffset, const Duration(minutes: 3, seconds: 55));
      expect(disc.tracks[1].duration, const Duration(minutes: 2, seconds: 6));

      // Track 3: starts at 06:01, duration until end (10:00) = 3m 59s
      expect(disc.tracks[2].trackNumber, 3);
      expect(disc.tracks[2].title, 'Dust');
      expect(disc.tracks[2].startOffset, const Duration(minutes: 6, seconds: 1));
      expect(disc.tracks[2].duration, const Duration(minutes: 3, seconds: 59));
    });
  });

  group('AudioCdRipperService Engine & Batch Transcoding', () {
    late Directory tempDir;
    late File mockAudioFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cdda_test_');
      mockAudioFile = File(p.join(tempDir.path, 'album.wav'))..writeAsBytesSync(List.filled(1024, 0));
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('buildRipArguments builds valid FFmpeg CLI command with metadata tags', () {
      final service = AudioCdRipperService();

      final track = CdTrackInfo(
        trackNumber: 2,
        title: 'Cornfield Chase',
        artist: 'Hans Zimmer',
        startOffset: const Duration(minutes: 3, seconds: 55),
        duration: const Duration(minutes: 2, seconds: 6),
      );

      final disc = AudioCdDiscInfo(
        albumTitle: 'Interstellar OST',
        artist: 'Hans Zimmer',
        genre: 'Soundtrack',
        releaseYear: '2014',
        tracks: [track],
      );

      final args = service.buildRipArguments(
        sourcePath: '/music/album.wav',
        outputPath: '/output/02 - Cornfield Chase.flac',
        format: AudioRipFormat.flac,
        track: track,
        disc: disc,
      );

      expect(args.contains('-y'), isTrue);
      expect(args.contains('-ss'), isTrue);
      expect(args.contains('-t'), isTrue);
      expect(args.contains('-vn'), isTrue);
      expect(args.contains('-c:a'), isTrue);
      expect(args.contains('flac'), isTrue);
      expect(args.contains('title=Cornfield Chase'), isTrue);
      expect(args.contains('artist=Hans Zimmer'), isTrue);
      expect(args.contains('album=Interstellar OST'), isTrue);
      expect(args.contains('track=2/1'), isTrue);
      expect(args.contains('date=2014'), isTrue);
      expect(args.contains('genre=Soundtrack'), isTrue);
      expect(args.last, '/output/02 - Cornfield Chase.flac');
    });

    test('ripSelectedTracks executes batch ripping and emits progress events', () async {
      final service = AudioCdRipperService();
      final executedCommands = <List<String>>[];

      // Mock executor
      service.customExecutor = (args, onProgress, isCancelled) async {
        executedCommands.add(args);
        onProgress(0.5);
        onProgress(1.0);
      };

      final track1 = CdTrackInfo(
        trackNumber: 1,
        title: 'Track One',
        artist: 'Test Artist',
        startOffset: Duration.zero,
        duration: const Duration(minutes: 3),
        isSelected: true,
      );

      final track2 = CdTrackInfo(
        trackNumber: 2,
        title: 'Track Two',
        artist: 'Test Artist',
        startOffset: const Duration(minutes: 3),
        duration: const Duration(minutes: 4),
        isSelected: false, // Unselected should be skipped
      );

      final track3 = CdTrackInfo(
        trackNumber: 3,
        title: 'Track Three',
        artist: 'Test Artist',
        startOffset: const Duration(minutes: 7),
        duration: const Duration(minutes: 2),
        isSelected: true,
      );

      final disc = AudioCdDiscInfo(
        albumTitle: 'Test Album',
        artist: 'Test Artist',
        audioSourcePath: mockAudioFile.path,
        tracks: [track1, track2, track3],
      );

      final progressList = <CdRipProgress>[];
      final sub = service.progressStream.listen(progressList.add);

      await service.ripSelectedTracks(
        disc: disc,
        outputDirectory: tempDir.path,
        format: AudioRipFormat.mp3,
      );

      await Future.delayed(Duration.zero);
      await sub.cancel();

      // Only Track 1 and Track 3 should be executed
      expect(executedCommands.length, 2);
      expect(executedCommands[0].contains('title=Track One'), isTrue);
      expect(executedCommands[1].contains('title=Track Three'), isTrue);

      expect(service.progress.status, CdRipStatus.completed);
      expect(service.progress.progressPercent, 100.0);
      expect(progressList.any((p) => p.isRipping), isTrue);
      expect(progressList.last.isCompleted, isTrue);
    });

    test('cancelRip interrupts active rip job', () async {
      final service = AudioCdRipperService();

      service.customExecutor = (args, onProgress, isCancelled) async {
        service.cancelRip();
      };

      final disc = AudioCdDiscInfo(
        albumTitle: 'Test Album',
        artist: 'Test Artist',
        audioSourcePath: mockAudioFile.path,
        tracks: [
          CdTrackInfo(
            trackNumber: 1,
            title: 'Track 1',
            artist: 'Artist',
            startOffset: Duration.zero,
            duration: const Duration(minutes: 3),
            isSelected: true,
          ),
          CdTrackInfo(
            trackNumber: 2,
            title: 'Track 2',
            artist: 'Artist',
            startOffset: const Duration(minutes: 3),
            duration: const Duration(minutes: 3),
            isSelected: true,
          ),
        ],
      );

      await service.ripSelectedTracks(
        disc: disc,
        outputDirectory: tempDir.path,
      );

      expect(service.progress.isCancelled, isTrue);
    });
  });
}
