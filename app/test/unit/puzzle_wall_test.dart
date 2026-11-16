import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';
import 'package:app/features/video_effects/domain/puzzle_wall_controller.dart';

void main() {
  group('Puzzle Game & Video Wall Unit Tests (VLC puzzle.c & wall.c Parity)', () {
    test('Default 3x3 PuzzleGameState initializes in fully solved state', () {
      final state = PuzzleGameState(rows: 3, cols: 3, mode: PuzzleGameMode.swap);

      expect(state.totalTiles, equals(9));
      expect(state.moveCount, equals(0));
      expect(state.selectedSlotIndex, isNull);
      expect(state.isSolved, isTrue);

      for (var i = 0; i < 9; i++) {
        final tile = state.tileAtSlot(i);
        expect(tile, isNotNull);
        expect(tile!.id, equals(i));
        expect(tile.currentIndex, equals(i));
        expect(tile.rotation, equals(0));
        expect(tile.isHome(), isTrue);
      }
    });

    test('Swap Mode: two consecutive slot taps swap tiles and increment moveCount', () {
      final state = PuzzleGameState(rows: 3, cols: 3, mode: PuzzleGameMode.swap);

      // Tap slot 1 (selects piece A)
      final firstTapHandled = state.interactSlot(1);
      expect(firstTapHandled, isTrue);
      expect(state.selectedSlotIndex, equals(1));
      expect(state.moveCount, equals(0));

      // Tap slot 5 (swaps piece A and piece B)
      final secondTapHandled = state.interactSlot(5);
      expect(secondTapHandled, isTrue);
      expect(state.selectedSlotIndex, isNull);
      expect(state.moveCount, equals(1));

      // Verify that tile at slot 1 was previously at slot 5, and vice versa
      final tileAt1 = state.tileAtSlot(1);
      final tileAt5 = state.tileAtSlot(5);

      expect(tileAt1!.id, equals(5));
      expect(tileAt5!.id, equals(1));
      expect(state.isSolved, isFalse);
    });

    test('Sliding 15-Puzzle Mode: only adjacent tiles slide into blank slot', () {
      final state = PuzzleGameState(rows: 3, cols: 3, mode: PuzzleGameMode.sliding);

      // Blank tile is at slot 8 (bottom-right: row 2, col 2)
      final blankTile = state.tiles.firstWhere((t) => t.isBlank);
      expect(blankTile.currentIndex, equals(8));

      // Attempt to tap slot 0 (top-left: row 0, col 0) -> NOT adjacent, should fail
      final nonAdjacentTap = state.interactSlot(0);
      expect(nonAdjacentTap, isFalse);
      expect(state.moveCount, equals(0));
      expect(blankTile.currentIndex, equals(8));

      // Attempt to tap slot 7 (bottom-center: row 2, col 1) -> adjacent!
      final adjacentTap = state.interactSlot(7);
      expect(adjacentTap, isTrue);
      expect(state.moveCount, equals(1));
      expect(blankTile.currentIndex, equals(7));

      final movedTile = state.tileAtSlot(8);
      expect(movedTile!.id, equals(7));
    });

    test('Puzzle solve() instantly restores all tiles to home positions', () {
      final state = PuzzleGameState(rows: 3, cols: 3, mode: PuzzleGameMode.swap);

      // Perform a swap
      state.interactSlot(0);
      state.interactSlot(8);
      expect(state.isSolved, isFalse);

      state.solve();
      expect(state.isSolved, isTrue);
      expect(state.selectedSlotIndex, isNull);
      for (var i = 0; i < 9; i++) {
        expect(state.tileAtSlot(i)!.isHome(), isTrue);
      }
    });

    test('Tile rotation: rotateTile clockwise modifies rotation step', () {
      final state = PuzzleGameState(
        rows: 2,
        cols: 2,
        mode: PuzzleGameMode.swap,
        allowRotation: true,
      );

      final tile0 = state.tileAtSlot(0)!;
      expect(tile0.rotation, equals(0));

      state.rotateTile(0);
      expect(tile0.rotation, equals(1)); // 90°
      expect(state.moveCount, equals(1));
      expect(state.isSolved, isFalse);

      state.rotateTile(0);
      state.rotateTile(0);
      state.rotateTile(0);
      expect(tile0.rotation, equals(0)); // 360° / 0°
      expect(state.isSolved, isTrue);
    });

    test('VideoWallState: calculates panels and manages solo zoom toggles (wall-active parity)', () {
      final wall = VideoWallState(rows: 2, cols: 3, bezelWidth: 6.0);

      expect(wall.totalPanels, equals(6));
      expect(wall.hasSolo, isFalse);
      expect(wall.soloSlotIndex, isNull);

      // Solo zoom monitor 4
      wall.toggleSolo(4);
      expect(wall.hasSolo, isTrue);
      expect(wall.soloSlotIndex, equals(4));

      // Solo zoom monitor 2 (switches solo)
      wall.toggleSolo(2);
      expect(wall.soloSlotIndex, equals(2));

      // Tapping same solo monitor exits solo mode
      wall.toggleSolo(2);
      expect(wall.hasSolo, isFalse);
      expect(wall.soloSlotIndex, isNull);
    });

    test('PuzzleWallController coordinates state and syncs with VideoEffectsConfig', () {
      final controller = PuzzleWallController(
        puzzleRows: 3,
        puzzleCols: 3,
        puzzleMode: PuzzleGameMode.swap,
      );

      expect(controller.puzzleState.rows, equals(3));
      expect(controller.puzzleState.cols, equals(3));

      final newConfig = VideoEffectsConfig(
        puzzleEnabled: true,
        puzzleRows: 4,
        puzzleCols: 4,
        puzzleMode: PuzzleGameMode.sliding,
        wallRows: 2,
        wallCols: 2,
        wallBezel: 8.0,
      );

      controller.syncWithConfig(newConfig);

      expect(controller.puzzleState.rows, equals(4));
      expect(controller.puzzleState.cols, equals(4));
      expect(controller.puzzleState.mode, equals(PuzzleGameMode.sliding));
      expect(controller.wallState.rows, equals(2));
      expect(controller.wallState.cols, equals(2));
      expect(controller.wallState.bezelWidth, equals(8.0));
    });

    test('VideoEffectsConfig JSON round-trip retains Puzzle & Video Wall parameters', () {
      final config = VideoEffectsConfig(
        puzzleEnabled: true,
        puzzleRows: 4,
        puzzleCols: 4,
        puzzleMode: PuzzleGameMode.sliding,
        puzzleBorder: 3.5,
        puzzleShowPreview: true,
        puzzleAllowRotation: true,
        wallEnabled: true,
        wallRows: 2,
        wallCols: 5,
        wallBezel: 10.0,
      );

      final json = config.toJson();
      final restored = VideoEffectsConfig.fromJson(json);

      expect(restored.puzzleEnabled, isTrue);
      expect(restored.puzzleRows, equals(4));
      expect(restored.puzzleCols, equals(4));
      expect(restored.puzzleMode, equals(PuzzleGameMode.sliding));
      expect(restored.puzzleBorder, equals(3.5));
      expect(restored.puzzleShowPreview, isTrue);
      expect(restored.puzzleAllowRotation, isTrue);
      expect(restored.wallEnabled, isTrue);
      expect(restored.wallRows, equals(2));
      expect(restored.wallCols, equals(5));
      expect(restored.wallBezel, equals(10.0));
    });
  });
}
