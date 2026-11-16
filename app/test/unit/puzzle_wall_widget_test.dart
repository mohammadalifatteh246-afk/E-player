import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/video_effects/models/video_effects_config.dart';
import 'package:app/features/video_effects/domain/puzzle_wall_controller.dart';
import 'package:app/features/video_effects/ui/puzzle_wall_surface_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PuzzleWallSurfaceWidget Rendering & Interaction Tests', () {
    testWidgets('Passthrough mode: directly renders child when neither puzzle nor wall is enabled', (tester) async {
      final config = VideoEffectsConfig(puzzleEnabled: false, wallEnabled: false);
      final controller = PuzzleWallController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PuzzleWallSurfaceWidget(
              config: config,
              controller: controller,
              child: const Text('Live Video Player Surface'),
            ),
          ),
        ),
      );

      expect(find.text('Live Video Player Surface'), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('Puzzle Mode: renders 3x3 interactive puzzle grid with gesture detection', (tester) async {
      final config = VideoEffectsConfig(
        puzzleEnabled: true,
        puzzleRows: 3,
        puzzleCols: 3,
        puzzleMode: PuzzleGameMode.swap,
        puzzleBorder: 2.0,
        puzzleShowPreview: true,
      );
      final controller = PuzzleWallController(
        puzzleRows: 3,
        puzzleCols: 3,
        puzzleMode: PuzzleGameMode.swap,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 450,
              child: PuzzleWallSurfaceWidget(
                config: config,
                controller: controller,
                child: Container(color: Colors.blue),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Target Preview overlay is visible
      expect(find.text('Target Preview'), findsOneWidget);

      // HUD info is visible
      expect(find.textContaining('Mode: Swap • Moves: 0'), findsOneWidget);

      // Sliced tiles: 9 GestureDetector elements
      final tiles = find.byType(GestureDetector);
      expect(tiles, findsWidgets);

      // Tap first tile to select
      await tester.tap(tiles.first);
      await tester.pump();
      expect(controller.puzzleState.selectedSlotIndex, equals(0));

      // Tap second tile to swap
      await tester.tap(tiles.at(1));
      await tester.pump();
      expect(controller.puzzleState.selectedSlotIndex, isNull);
      expect(controller.puzzleState.moveCount, equals(1));
    });

    testWidgets('Video Wall Mode: renders multi-monitor grid and toggles solo zoom on panel tap', (tester) async {
      final config = VideoEffectsConfig(
        wallEnabled: true,
        wallRows: 2,
        wallCols: 2,
        wallBezel: 6.0,
      );
      final controller = PuzzleWallController(
        wallRows: 2,
        wallCols: 2,
        wallBezel: 6.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: PuzzleWallSurfaceWidget(
                config: config,
                controller: controller,
                child: Container(color: Colors.green),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap a monitor panel to solo-zoom
      final panels = find.byType(GestureDetector);
      expect(panels, findsWidgets);

      await tester.tap(panels.first);
      await tester.pump();

      expect(controller.wallState.hasSolo, isTrue);
      expect(find.textContaining('Exit Solo Panel'), findsOneWidget);

      // Tap Exit Solo Panel button
      await tester.tap(find.textContaining('Exit Solo Panel'));
      await tester.pump();

      expect(controller.wallState.hasSolo, isFalse);
      expect(find.textContaining('Exit Solo Panel'), findsNothing);
    });
  });
}
