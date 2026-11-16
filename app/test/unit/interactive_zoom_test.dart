import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/services/interactive_zoom_controller.dart';

void main() {
  group('Interactive Zoom & Magnifier Engine Tests (VLC magnify.c Parity)', () {
    test('InteractiveZoomState initializes with 1.0x neutral scale and centered pan', () {
      final state = InteractiveZoomState();
      expect(state.isActive, isFalse);
      expect(state.zoomFactor, equals(1.0));
      expect(state.panX, equals(0.0));
      expect(state.panY, equals(0.0));
      expect(state.mpvZoomValue, equals(0.0)); // log2(1.0) = 0.0
    });

    test('Zoom factor converts accurately to mpv log2 exponential scale', () {
      final state2x = InteractiveZoomState(zoomFactor: 2.0);
      expect(state2x.mpvZoomValue, closeTo(1.0, 0.001));

      final state4x = InteractiveZoomState(zoomFactor: 4.0);
      expect(state4x.mpvZoomValue, closeTo(2.0, 0.001));

      final state8x = InteractiveZoomState(zoomFactor: 8.0);
      expect(state8x.mpvZoomValue, closeTo(3.0, 0.001));
    });

    test('Zoom factor is clamped within safe range [1.0, 8.0]', () {
      final stateLow = InteractiveZoomState(zoomFactor: 0.2);
      expect(stateLow.zoomFactor, equals(1.0));

      final stateHigh = InteractiveZoomState(zoomFactor: 12.0);
      expect(stateHigh.zoomFactor, equals(8.0));
    });

    test('Pan values are clamped to [-1.0, 1.0]', () {
      final state = InteractiveZoomState(
        zoomFactor: 2.0,
        panX: 1.5,
        panY: -2.0,
      );
      expect(state.panX, equals(1.0));
      expect(state.panY, equals(-1.0));
    });

    test('Normalized viewport calculation provides correct mini-map bounding box', () {
      final state = InteractiveZoomState(
        zoomFactor: 2.0,
        panX: 0.0,
        panY: 0.0,
      );

      // At 2x zoom, width and height of visible viewport are 50% (0.5) of frame
      final rect = state.viewportRect;
      expect(rect.width, closeTo(0.5, 0.01));
      expect(rect.height, closeTo(0.5, 0.01));
      expect(rect.left, closeTo(0.25, 0.01));
      expect(rect.top, closeTo(0.25, 0.01));
    });

    test('Reset restores 1.0x neutral state', () {
      final controller = InteractiveZoomController();
      controller.setZoom(3.5);
      controller.setPan(0.5, -0.4);

      expect(controller.state.zoomFactor, equals(3.5));
      expect(controller.state.isActive, isTrue);

      controller.reset();
      expect(controller.state.zoomFactor, equals(1.0));
      expect(controller.state.isActive, isFalse);
      expect(controller.state.panX, equals(0.0));
      expect(controller.state.panY, equals(0.0));
    });
  });
}
