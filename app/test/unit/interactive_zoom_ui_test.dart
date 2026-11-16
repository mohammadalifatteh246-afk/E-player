import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/services/interactive_zoom_controller.dart';
import 'package:app/features/player/ui/widgets/interactive_zoom_viewfinder.dart';

void main() {
  group('InteractiveZoomViewfinder Widget Tests', () {
    testWidgets('renders mini-map canvas, zoom badge, and quick zoom buttons', (tester) async {
      final controller = InteractiveZoomController();
      controller.setZoom(2.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveZoomViewfinder(
              controller: controller,
            ),
          ),
        ),
      );

      // Verify zoom factor text
      expect(find.text('2.0x'), findsNWidgets(2)); // Header badge & button
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('4.0x'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
    });

    testWidgets('tapping quick zoom buttons updates controller state', (tester) async {
      final controller = InteractiveZoomController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveZoomViewfinder(
              controller: controller,
            ),
          ),
        ),
      );

      // Tap 4.0x button
      await tester.tap(find.text('4.0x'));
      await tester.pumpAndSettle();

      expect(controller.state.zoomFactor, equals(4.0));
      expect(find.text('4.0x'), findsNWidgets(2)); // Badge and button

      // Tap 1.0x (reset) button
      await tester.tap(find.text('1.0x'));
      await tester.pumpAndSettle();

      expect(controller.state.zoomFactor, equals(1.0));
    });

    testWidgets('dragging inside mini-map canvas updates pan coordinates', (tester) async {
      final controller = InteractiveZoomController();
      controller.setZoom(3.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InteractiveZoomViewfinder(
                controller: controller,
              ),
            ),
          ),
        ),
      );

      // Drag inside the GestureDetector of the mini-map
      final gestureFinder = find.byType(GestureDetector).first;
      await tester.drag(gestureFinder, const Offset(30, 20));
      await tester.pumpAndSettle();

      expect(controller.state.panX.abs(), greaterThan(0.01));
      expect(controller.state.panY.abs(), greaterThan(0.01));
    });

    testWidgets('tapping close button fires onClose callback', (tester) async {
      bool closed = false;
      final controller = InteractiveZoomController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveZoomViewfinder(
              controller: controller,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });
  });
}
