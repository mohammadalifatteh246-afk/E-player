import 'dart:math' as math;

/// Game variation mode for the interactive puzzle video filter (VLC puzzle.c parity).
enum PuzzleGameMode {
  /// Tap piece A then tap piece B to swap their positions.
  swap,

  /// Classic 15-puzzle sliding tile: one slot is empty, tapping an adjacent tile slides it into the blank.
  sliding,
}

/// Represents an individual sliced tile of the video frame.
class PuzzleTile {
  /// Original target index of this tile in the unscrambled grid:
  /// `0 <= id < rows * cols`.
  final int id;

  /// Current slot position in the grid where this tile is placed:
  /// `0 <= currentIndex < rows * cols`.
  int currentIndex;

  /// Rotation step (0: 0°, 1: 90°, 2: 180°, 3: 270°).
  int rotation;

  /// Whether this tile is the empty/blank slot in sliding puzzle mode.
  final bool isBlank;

  PuzzleTile({
    required this.id,
    required this.currentIndex,
    this.rotation = 0,
    this.isBlank = false,
  });

  /// Original column in the un-scrambled source video.
  int originalCol(int cols) => id % cols;

  /// Original row in the un-scrambled source video.
  int originalRow(int cols) => id ~/ cols;

  /// Current column in the displayed puzzle grid.
  int currentCol(int cols) => currentIndex % cols;

  /// Current row in the displayed puzzle grid.
  int currentRow(int cols) => currentIndex ~/ cols;

  /// Checks whether this tile is in its correct home position and rotation.
  bool isHome({bool checkRotation = false}) {
    if (currentIndex != id) return false;
    if (checkRotation && rotation != 0) return false;
    return true;
  }

  PuzzleTile copyWith({
    int? id,
    int? currentIndex,
    int? rotation,
    bool? isBlank,
  }) {
    return PuzzleTile(
      id: id ?? this.id,
      currentIndex: currentIndex ?? this.currentIndex,
      rotation: rotation ?? this.rotation,
      isBlank: isBlank ?? this.isBlank,
    );
  }
}

/// Interactive game state managing tile arrangements, shuffling algorithms,
/// move counts, and win verification (VLC `puzzle.c` parity).
class PuzzleGameState {
  final int rows;
  final int cols;
  final PuzzleGameMode mode;
  final bool allowRotation;
  final List<PuzzleTile> tiles;
  int? selectedSlotIndex;
  int moveCount;
  bool isSolved;

  int get totalTiles => rows * cols;

  PuzzleGameState({
    required this.rows,
    required this.cols,
    this.mode = PuzzleGameMode.swap,
    this.allowRotation = false,
    List<PuzzleTile>? tiles,
    this.selectedSlotIndex,
    this.moveCount = 0,
    this.isSolved = true,
  }) : tiles = tiles ?? _generateInitialTiles(rows, cols, mode);

  static List<PuzzleTile> _generateInitialTiles(
    int rows,
    int cols,
    PuzzleGameMode mode,
  ) {
    final count = rows * cols;
    final blankIndex = count - 1;
    return List.generate(count, (i) {
      final isBlank = (mode == PuzzleGameMode.sliding && i == blankIndex);
      return PuzzleTile(
        id: i,
        currentIndex: i,
        rotation: 0,
        isBlank: isBlank,
      );
    });
  }

  /// Finds the tile currently occupying [slotIndex].
  PuzzleTile? tileAtSlot(int slotIndex) {
    for (final tile in tiles) {
      if (tile.currentIndex == slotIndex) return tile;
    }
    return null;
  }

  /// Shuffles the puzzle tiles.
  /// For sliding mode, uses 120 random legal neighbor walks to guarantee mathematical solvability.
  /// For swap mode, uses Fisher-Yates permutation.
  void shuffle({math.Random? random}) {
    final rng = random ?? math.Random();
    moveCount = 0;
    selectedSlotIndex = null;

    if (mode == PuzzleGameMode.sliding) {
      // Start from solved state
      for (final t in tiles) {
        t.currentIndex = t.id;
        t.rotation = 0;
      }
      final blankTile = tiles.firstWhere((t) => t.isBlank);
      int blankSlot = blankTile.currentIndex;

      // Perform random walk
      for (var i = 0; i < 120; i++) {
        final neighbors = _getAdjacentSlots(blankSlot, rows, cols);
        final pickSlot = neighbors[rng.nextInt(neighbors.length)];
        final neighborTile = tileAtSlot(pickSlot)!;

        neighborTile.currentIndex = blankSlot;
        blankTile.currentIndex = pickSlot;
        blankSlot = pickSlot;
      }
    } else {
      // Swap mode: Fisher-Yates
      final slots = List<int>.generate(totalTiles, (i) => i);
      for (var i = slots.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final temp = slots[i];
        slots[i] = slots[j];
        slots[j] = temp;
      }

      for (var i = 0; i < tiles.length; i++) {
        tiles[i].currentIndex = slots[i];
        if (allowRotation) {
          tiles[i].rotation = rng.nextInt(4);
        } else {
          tiles[i].rotation = 0;
        }
      }
    }

    _evaluateSolved();
  }

  /// Interacts with [tappedSlotIndex] based on game mode.
  /// In swap mode: first click selects piece A; second click swaps piece A with piece B.
  /// In sliding mode: clicks adjacent to the blank piece smoothly slide into the blank slot.
  bool interactSlot(int tappedSlotIndex) {
    if (tappedSlotIndex < 0 || tappedSlotIndex >= totalTiles) return false;

    if (mode == PuzzleGameMode.sliding) {
      final blankTile = tiles.firstWhere((t) => t.isBlank);
      final blankSlot = blankTile.currentIndex;

      if (_isAdjacent(tappedSlotIndex, blankSlot, cols)) {
        final tappedTile = tileAtSlot(tappedSlotIndex);
        if (tappedTile != null) {
          tappedTile.currentIndex = blankSlot;
          blankTile.currentIndex = tappedSlotIndex;
          moveCount++;
          _evaluateSolved();
          return true;
        }
      }
      return false;
    } else {
      // Swap mode
      if (selectedSlotIndex == null) {
        selectedSlotIndex = tappedSlotIndex;
        return true;
      } else if (selectedSlotIndex == tappedSlotIndex) {
        // Deselect or rotate if rotation allowed
        if (allowRotation) {
          final tile = tileAtSlot(tappedSlotIndex);
          if (tile != null) {
            tile.rotation = (tile.rotation + 1) % 4;
            moveCount++;
            _evaluateSolved();
          }
        }
        selectedSlotIndex = null;
        return true;
      } else {
        // Swap selected tile and tapped tile
        final tileA = tileAtSlot(selectedSlotIndex!);
        final tileB = tileAtSlot(tappedSlotIndex);

        if (tileA != null && tileB != null) {
          final tempSlot = tileA.currentIndex;
          tileA.currentIndex = tileB.currentIndex;
          tileB.currentIndex = tempSlot;
          moveCount++;
          selectedSlotIndex = null;
          _evaluateSolved();
          return true;
        }
        selectedSlotIndex = null;
        return false;
      }
    }
  }

  /// Rotates the tile occupying [slotIndex] by 90 degrees clockwise.
  void rotateTile(int slotIndex) {
    final tile = tileAtSlot(slotIndex);
    if (tile != null) {
      tile.rotation = (tile.rotation + 1) % 4;
      moveCount++;
      _evaluateSolved();
    }
  }

  /// Instantly resets / solves the puzzle back to unscrambled order.
  void solve() {
    for (final tile in tiles) {
      tile.currentIndex = tile.id;
      tile.rotation = 0;
    }
    selectedSlotIndex = null;
    isSolved = true;
  }

  void _evaluateSolved() {
    isSolved = tiles.every((t) => t.isHome(checkRotation: allowRotation));
  }

  static List<int> _getAdjacentSlots(int slot, int rows, int cols) {
    final r = slot ~/ cols;
    final c = slot % cols;
    final list = <int>[];
    if (r > 0) list.add((r - 1) * cols + c); // Top
    if (r < rows - 1) list.add((r + 1) * cols + c); // Bottom
    if (c > 0) list.add(r * cols + (c - 1)); // Left
    if (c < cols - 1) list.add(r * cols + (c + 1)); // Right
    return list;
  }

  static bool _isAdjacent(int slotA, int slotB, int cols) {
    final rA = slotA ~/ cols;
    final cA = slotA % cols;
    final rB = slotB ~/ cols;
    final cB = slotB % cols;
    final dist = (rA - rB).abs() + (cA - cB).abs();
    return dist == 1;
  }
}

/// State representation for Video Wall Multi-Display Array (VLC wall.c parity).
class VideoWallState {
  final int rows;
  final int cols;
  final double bezelWidth;
  int? soloSlotIndex;

  VideoWallState({
    this.rows = 3,
    this.cols = 3,
    this.bezelWidth = 4.0,
    this.soloSlotIndex,
  });

  int get totalPanels => rows * cols;
  bool get hasSolo => soloSlotIndex != null;

  void toggleSolo(int slotIndex) {
    if (soloSlotIndex == slotIndex) {
      soloSlotIndex = null;
    } else {
      soloSlotIndex = slotIndex;
    }
  }

  void clearSolo() {
    soloSlotIndex = null;
  }
}
