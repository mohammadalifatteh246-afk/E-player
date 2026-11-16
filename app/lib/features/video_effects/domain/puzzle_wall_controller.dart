import 'package:flutter/foundation.dart';
import '../models/video_effects_config.dart';

/// Controller coordinating interactive puzzle gameplay and multi-screen video wall state.
/// Parity with VLC's `modules/video_filter/puzzle/puzzle.c` and `modules/video_splitter/wall.c`.
class PuzzleWallController extends ChangeNotifier {
  late PuzzleGameState _puzzleState;
  late VideoWallState _wallState;

  PuzzleGameState get puzzleState => _puzzleState;
  VideoWallState get wallState => _wallState;

  PuzzleWallController({
    int puzzleRows = 3,
    int puzzleCols = 3,
    PuzzleGameMode puzzleMode = PuzzleGameMode.swap,
    bool puzzleAllowRotation = false,
    int wallRows = 3,
    int wallCols = 3,
    double wallBezel = 4.0,
  }) {
    _puzzleState = PuzzleGameState(
      rows: puzzleRows,
      cols: puzzleCols,
      mode: puzzleMode,
      allowRotation: puzzleAllowRotation,
    );
    _wallState = VideoWallState(
      rows: wallRows,
      cols: wallCols,
      bezelWidth: wallBezel,
    );
  }

  /// Syncs controller dimensions and modes with [VideoEffectsConfig].
  void syncWithConfig(VideoEffectsConfig config) {
    bool needsPuzzleReinit = false;
    if (_puzzleState.rows != config.puzzleRows ||
        _puzzleState.cols != config.puzzleCols ||
        _puzzleState.mode != config.puzzleMode ||
        _puzzleState.allowRotation != config.puzzleAllowRotation) {
      needsPuzzleReinit = true;
    }

    if (needsPuzzleReinit) {
      _puzzleState = PuzzleGameState(
        rows: config.puzzleRows,
        cols: config.puzzleCols,
        mode: config.puzzleMode,
        allowRotation: config.puzzleAllowRotation,
      );
    }

    if (_wallState.rows != config.wallRows ||
        _wallState.cols != config.wallCols ||
        _wallState.bezelWidth != config.wallBezel) {
      _wallState = VideoWallState(
        rows: config.wallRows,
        cols: config.wallCols,
        bezelWidth: config.wallBezel,
        soloSlotIndex: _wallState.soloSlotIndex,
      );
    }

    notifyListeners();
  }

  /// Triggers a fresh puzzle shuffle.
  void shufflePuzzle() {
    _puzzleState.shuffle();
    notifyListeners();
  }

  /// Instantly resets / solves the puzzle.
  void solvePuzzle() {
    _puzzleState.solve();
    notifyListeners();
  }

  /// Handles user tapping on a puzzle slot.
  bool interactPuzzleSlot(int slotIndex) {
    final handled = _puzzleState.interactSlot(slotIndex);
    if (handled) {
      notifyListeners();
    }
    return handled;
  }

  /// Rotates the tile at [slotIndex] by 90 degrees clockwise.
  void rotatePuzzleTile(int slotIndex) {
    _puzzleState.rotateTile(slotIndex);
    notifyListeners();
  }

  /// Toggles solo zoom view for a specific monitor panel in video wall mode.
  void toggleWallSolo(int slotIndex) {
    _wallState.toggleSolo(slotIndex);
    notifyListeners();
  }

  /// Clears solo view and restores the full multi-display video wall.
  void clearWallSolo() {
    _wallState.clearSolo();
    notifyListeners();
  }
}
