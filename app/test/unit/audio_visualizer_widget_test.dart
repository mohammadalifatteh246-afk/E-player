import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/audio/domain/audio_visualizer_engine.dart';
import 'package:app/features/audio/ui/audio_spectrum_visualizer_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioSpectrumVisualizerWidget Rendering Tests', () {
    late AudioVisualizerEngine engine;

    setUp(() {
      engine = AudioVisualizerEngine(bandCount: 16);
      engine.setActive(true);
      engine.updateAudioContext(
        position: const Duration(seconds: 15),
        volume: 100.0,
        isPlaying: true,
      );
    });

    testWidgets('Renders bars visualizer cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioSpectrumVisualizerWidget(
              engine: engine,
              style: VisualizerStyle.bars,
              height: 120,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AudioSpectrumVisualizerWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Renders mirrorWave and circular visualizer styles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AudioSpectrumVisualizerWidget(
                  engine: engine,
                  style: VisualizerStyle.mirrorWave,
                  height: 100,
                ),
                AudioSpectrumVisualizerWidget(
                  engine: engine,
                  style: VisualizerStyle.circular,
                  height: 100,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AudioSpectrumVisualizerWidget), findsNWidgets(2));
    });
  });
}
