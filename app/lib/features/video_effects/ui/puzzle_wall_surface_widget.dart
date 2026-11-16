import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../domain/puzzle_wall_controller.dart';
import '../models/video_effects_config.dart';

/// Hardware-accelerated interactive puzzle game and multi-display video wall surface.
/// Parity with VLC's `modules/video_filter/puzzle/puzzle.c` and `modules/video_splitter/wall.c`.
class PuzzleWallSurfaceWidget extends StatefulWidget {
  final VideoEffectsConfig config;
  final PuzzleWallController controller;
  final Widget child;

  const PuzzleWallSurfaceWidget({
    super.key,
    required this.config,
    required this.controller,
    required this.child,
  });

  @override
  State<PuzzleWallSurfaceWidget> createState() => _PuzzleWallSurfaceWidgetState();
}

class _PuzzleWallSurfaceWidgetState extends State<PuzzleWallSurfaceWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant PuzzleWallSurfaceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;

    // Passthrough if neither Puzzle nor Wall filter is enabled
    if (!cfg.puzzleEnabled && !cfg.wallEnabled) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final totalH = constraints.maxHeight;

        if (totalW <= 0 || totalH <= 0) {
          return widget.child;
        }

        if (cfg.puzzleEnabled) {
          return _buildPuzzleSurface(totalW, totalH);
        } else {
          return _buildWallSurface(totalW, totalH);
        }
      },
    );
  }

  // --- Puzzle Interactive Game Surface (puzzle.c) ---
  Widget _buildPuzzleSurface(double totalW, double totalH) {
    final state = widget.controller.puzzleState;
    final rows = state.rows;
    final cols = state.cols;
    final tileW = totalW / cols;
    final tileH = totalH / rows;

    return Stack(
      children: [
        // Sliced puzzle grid
        Column(
          children: List.generate(rows, (r) {
            return SizedBox(
              height: tileH,
              child: Row(
                children: List.generate(cols, (c) {
                  final slotIndex = r * cols + c;
                  final tile = state.tileAtSlot(slotIndex);
                  return SizedBox(
                    width: tileW,
                    child: _buildPuzzleTile(tile, slotIndex, totalW, totalH),
                  );
                }),
              ),
            );
          }),
        ),

        // Solved Victory Banner
        if (state.isSolved && state.moveCount > 0)
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xE6064E3B), // Emerald dark glass
                  borderRadius: BorderRadius.circular(EDesign.r16),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.celebration, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'PUZZLE SOLVED! (${state.moveCount} Moves)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => widget.controller.shufflePuzzle(),
                      icon: const Icon(Icons.shuffle, size: 16),
                      label: const Text('Play Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Floating HUD Info & Controls (Moves Counter)
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xCC0B1220),
              borderRadius: BorderRadius.circular(EDesign.r8),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.mode == PuzzleGameMode.swap ? Icons.swap_horiz : Icons.grid_view,
                  color: EDesign.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Mode: ${state.mode == PuzzleGameMode.swap ? "Swap" : "15-Sliding"} • Moves: ${state.moveCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => widget.controller.shufflePuzzle(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('Shuffle', style: TextStyle(color: EDesign.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Text(' • ', style: TextStyle(color: Colors.white38)),
                InkWell(
                  onTap: () => widget.controller.solvePuzzle(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('Solve', style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Mini Original Video Preview Thumbnail (VLC puzzle-preview parity)
        if (widget.config.puzzleShowPreview)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 180,
              height: 101, // 16:9 ratio
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(EDesign.r8),
                border: Border.all(color: EDesign.primary.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(EDesign.r8 - 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.child,
                    Positioned(
                      top: 4,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Target Preview', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPuzzleTile(
    PuzzleTile? tile,
    int slotIndex,
    double totalW,
    double totalH,
  ) {
    if (tile == null) {
      return const SizedBox.shrink();
    }

    final isSelected = (widget.controller.puzzleState.selectedSlotIndex == slotIndex);
    final borderGap = widget.config.puzzleBorder;

    if (tile.isBlank) {
      // Empty slot in 15-puzzle sliding mode
      return Container(
        margin: EdgeInsets.all(borderGap / 2.0),
        decoration: BoxDecoration(
          color: const Color(0xEE111827),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: const Center(
          child: Icon(Icons.drag_indicator, color: Colors.white24, size: 28),
        ),
      );
    }

    final cols = widget.controller.puzzleState.cols;
    final rows = widget.controller.puzzleState.rows;
    final srcCol = tile.originalCol(cols);
    final srcRow = tile.originalRow(cols);

    // Exact UV normalization mapping
    final ax = cols > 1 ? -1.0 + (2.0 * srcCol / (cols - 1)) : 0.0;
    final ay = rows > 1 ? -1.0 + (2.0 * srcRow / (rows - 1)) : 0.0;

    return GestureDetector(
      onTap: () => widget.controller.interactPuzzleSlot(slotIndex),
      onSecondaryTap: () => widget.controller.rotatePuzzleTile(slotIndex),
      child: Container(
        margin: EdgeInsets.all(borderGap / 2.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00E5FF)
                : (tile.isHome(checkRotation: widget.config.puzzleAllowRotation)
                    ? const Color(0x5500E5FF)
                    : const Color(0x44FFFFFF)),
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: RotatedBox(
            quarterTurns: tile.rotation,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.none,
                alignment: Alignment(ax, ay),
                child: SizedBox(
                  width: totalW,
                  height: totalH,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Video Wall Display Array Surface (wall.c) ---
  Widget _buildWallSurface(double totalW, double totalH) {
    final wallState = widget.controller.wallState;

    // Solo monitor panel zoom mode
    if (wallState.hasSolo) {
      final soloSlot = wallState.soloSlotIndex!;
      final rows = wallState.rows;
      final cols = wallState.cols;
      final srcCol = soloSlot % cols;
      final srcRow = soloSlot ~/ cols;

      final ax = cols > 1 ? -1.0 + (2.0 * srcCol / (cols - 1)) : 0.0;
      final ay = rows > 1 ? -1.0 + (2.0 * srcRow / (rows - 1)) : 0.0;

      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: FittedBox(
              fit: BoxFit.none,
              alignment: Alignment(ax, ay),
              child: SizedBox(
                width: totalW,
                height: totalH,
                child: widget.child,
              ),
            ),
          ),

          // Exit Solo Panel floating pill
          Positioned(
            top: 20,
            left: 20,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xDD0B1220),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  side: const BorderSide(color: EDesign.primary, width: 1.2),
                ),
              ),
              onPressed: () => widget.controller.clearWallSolo(),
              icon: const Icon(Icons.fullscreen_exit, size: 18, color: EDesign.primary),
              label: Text('Exit Solo Panel (${srcRow + 1}, ${srcCol + 1})'),
            ),
          ),
        ],
      );
    }

    final rows = wallState.rows;
    final cols = wallState.cols;
    final tileW = totalW / cols;
    final tileH = totalH / rows;
    final bezel = widget.config.wallBezel;

    return Column(
      children: List.generate(rows, (r) {
        return SizedBox(
          height: tileH,
          child: Row(
            children: List.generate(cols, (c) {
              final slotIndex = r * cols + c;
              final ax = cols > 1 ? -1.0 + (2.0 * c / (cols - 1)) : 0.0;
              final ay = rows > 1 ? -1.0 + (2.0 * r / (rows - 1)) : 0.0;

              return SizedBox(
                width: tileW,
                child: GestureDetector(
                  onTap: () => widget.controller.toggleWallSolo(slotIndex),
                  child: Container(
                    margin: EdgeInsets.all(bezel / 2.0),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF1F2937), // Dark industrial bezel
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.none,
                        alignment: Alignment(ax, ay),
                        child: SizedBox(
                          width: totalW,
                          height: totalH,
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
