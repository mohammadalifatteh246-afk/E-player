import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/services/desktop_drag_drop_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DesktopDragDropService dragDropService;

  setUp(() {
    dragDropService = DesktopDragDropService();
    dragDropService.initialize(isTest: true);
    DesktopDragDropService.setMockInstance(dragDropService);
  });

  tearDown(() {
    dragDropService.dispose();
  });

  group('Desktop Drag-and-Drop Ingestion (VLC Parity) - Widget & UI Tests', () {
    testWidgets('Widget reacts to subtitle drop by attaching subtitle track', (tester) async {
      String? attachedSubtitle;
      String? osdMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: StreamBuilder<DroppedMediaEvent>(
                  stream: dragDropService.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final event = snapshot.data!;
                      if (event.hasSubtitle) {
                        final sub = event.subtitleItems.first;
                        attachedSubtitle = sub.path;
                        osdMessage = 'Subtitle attached: ${sub.name}';
                      }
                    }
                    return Column(
                      children: [
                        Text('Current Subtitle: ${attachedSubtitle ?? 'None'}'),
                        if (osdMessage != null) Text(osdMessage!),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Current Subtitle: None'), findsOneWidget);

      // Simulate dropping a subtitle file onto the active player window (VLC parity)
      dragDropService.simulateDrop(['C:/Movies/Interstellar.srt']);
      await tester.pump(const Duration(milliseconds: 50));

      expect(attachedSubtitle, equals('C:/Movies/Interstellar.srt'));
      expect(find.text('Current Subtitle: C:/Movies/Interstellar.srt'), findsOneWidget);
      expect(find.text('Subtitle attached: Interstellar.srt'), findsOneWidget);
    });

    testWidgets('Widget reacts to video drop by opening new media', (tester) async {
      String? activeVideo;
      String? osdMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: StreamBuilder<DroppedMediaEvent>(
                  stream: dragDropService.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final event = snapshot.data!;
                      if (event.hasVideoAudio) {
                        final video = event.videoAudioItems.first;
                        activeVideo = video.path;
                        osdMessage = 'Playing: ${video.name}';
                      }
                    }
                    return Column(
                      children: [
                        Text('Current Video: ${activeVideo ?? 'None'}'),
                        if (osdMessage != null) Text(osdMessage!),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Current Video: None'), findsOneWidget);

      // Simulate dropping a video file (VLC parity)
      dragDropService.simulateDrop(['D:/Media/Gladiator.mkv']);
      await tester.pump(const Duration(milliseconds: 50));

      expect(activeVideo, equals('D:/Media/Gladiator.mkv'));
      expect(find.text('Current Video: D:/Media/Gladiator.mkv'), findsOneWidget);
      expect(find.text('Playing: Gladiator.mkv'), findsOneWidget);
    });

    testWidgets('Widget reacts to unsupported file drop with warning', (tester) async {
      String? warningMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamBuilder<DroppedMediaEvent>(
              stream: dragDropService.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final event = snapshot.data!;
                  if (!event.hasVideoAudio && !event.hasSubtitle && event.primaryItem != null) {
                    warningMessage = 'Unsupported format: ${event.primaryItem!.name}';
                  }
                }
                return Text(warningMessage ?? 'Ready');
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Ready'), findsOneWidget);

      dragDropService.simulateDrop(['C:/Files/document.docx']);
      await tester.pump(const Duration(milliseconds: 50));

      expect(warningMessage, equals('Unsupported format: document.docx'));
      expect(find.text('Unsupported format: document.docx'), findsOneWidget);
    });
  });
}
