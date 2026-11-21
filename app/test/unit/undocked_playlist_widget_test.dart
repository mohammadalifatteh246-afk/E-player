import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/media_item.dart';
import 'package:app/features/player/services/playlist_controller.dart';
import 'package:app/features/player/ui/widgets/undocked_playlist_panel_widget.dart';
import 'package:app/features/player/ui/widgets/desktop_keyboard_handler.dart';
import 'package:media_kit/media_kit.dart';

class _FakePlayer extends Fake implements Player {
  @override
  PlayerState get state => const PlayerState(volume: 100.0, playing: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testItems = [
    MediaItem(
      path: 'C:/Movies/Inception.mp4',
      name: 'Inception.mp4',
      parentFolder: 'C:/Movies',
      durationMs: 7200000,
      lastPlayed: DateTime.now(),
    ),
    MediaItem(
      path: 'C:/Movies/Interstellar.mkv',
      name: 'Interstellar.mkv',
      parentFolder: 'C:/Movies',
      durationMs: 9600000,
      lastPlayed: DateTime.now(),
    ),
    MediaItem(
      path: 'C:/Movies/Dunkirk.mp4',
      name: 'Dunkirk.mp4',
      parentFolder: 'C:/Movies',
      durationMs: 6400000,
      lastPlayed: DateTime.now(),
    ),
  ];

  group('UndockedPlaylistPanelWidget UI Tests (VLC Parity)', () {
    testWidgets('Renders floating playlist panel with items, badges, and controls', (tester) async {
      final controller = PlaylistController();
      controller.setItems(testItems, activePath: 'C:/Movies/Inception.mp4');
      MediaItem? selectedTrack;
      bool dockToggled = false;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: UndockedPlaylistPanelWidget(
                controller: controller,
                onSelectTrack: (item) => selectedTrack = item,
                onClose: () => closed = true,
                onDockToggle: () => dockToggled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and badge
      expect(find.text('Playlist'), findsOneWidget);
      expect(find.byKey(const Key('undocked_playlist_count_badge')), findsOneWidget);
      expect(find.byKey(const Key('undocked_playlist_dock_toggle_button')), findsOneWidget);
      expect(find.byKey(const Key('undocked_playlist_minimize_button')), findsOneWidget);
      expect(find.byKey(const Key('undocked_playlist_close_button')), findsOneWidget);

      // Check track items
      expect(find.text('Inception.mp4'), findsOneWidget);
      expect(find.text('Interstellar.mkv'), findsOneWidget);
      expect(find.text('Dunkirk.mp4'), findsOneWidget);

      // Tap on second track
      await tester.tap(find.text('Interstellar.mkv'));
      await tester.pumpAndSettle();
      expect(selectedTrack?.name, 'Interstellar.mkv');

      // Test dock toggle button
      await tester.tap(find.byKey(const Key('undocked_playlist_dock_toggle_button')));
      await tester.pumpAndSettle();
      expect(dockToggled, isTrue);

      // Test close button
      await tester.tap(find.byKey(const Key('undocked_playlist_close_button')));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });

    testWidgets('Search query filters playlist items and clear button resets query', (tester) async {
      final controller = PlaylistController();
      controller.setItems(testItems, activePath: 'C:/Movies/Inception.mp4');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: UndockedPlaylistPanelWidget(
                controller: controller,
                onSelectTrack: (_) {},
                onClose: () {},
                onDockToggle: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inception.mp4'), findsOneWidget);
      expect(find.text('Interstellar.mkv'), findsOneWidget);
      expect(find.text('Dunkirk.mp4'), findsOneWidget);

      // Search for "Inter"
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Inter');
      await tester.pumpAndSettle();

      expect(find.text('Inception.mp4'), findsNothing);
      expect(find.text('Interstellar.mkv'), findsOneWidget);
      expect(find.text('Dunkirk.mp4'), findsNothing);

      // Clear search
      final clearButton = find.byIcon(Icons.clear_rounded);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.text('Inception.mp4'), findsOneWidget);
      expect(find.text('Interstellar.mkv'), findsOneWidget);
      expect(find.text('Dunkirk.mp4'), findsOneWidget);
    });

    testWidgets('Dragging handle updates controller position', (tester) async {
      final controller = PlaylistController();
      controller.setItems(testItems);
      final initialPos = controller.position;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: UndockedPlaylistPanelWidget(
                controller: controller,
                onSelectTrack: (_) {},
                onClose: () {},
                onDockToggle: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dragHandle = find.byKey(const Key('undocked_playlist_drag_handle'));
      expect(dragHandle, findsOneWidget);

      await tester.drag(dragHandle, const Offset(50, 40));
      await tester.pumpAndSettle();

      expect(controller.position.dx, closeTo(initialPos.dx + 50, 0.1));
      expect(controller.position.dy, closeTo(initialPos.dy + 40, 0.1));
    });

    testWidgets('Minimize button collapses track list and controls', (tester) async {
      final controller = PlaylistController();
      controller.setItems(testItems);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: UndockedPlaylistPanelWidget(
                controller: controller,
                onSelectTrack: (_) {},
                onClose: () {},
                onDockToggle: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inception.mp4'), findsOneWidget);

      // Tap minimize
      final minimizeBtn = find.byKey(const Key('undocked_playlist_minimize_button'));
      await tester.tap(minimizeBtn);
      await tester.pumpAndSettle();

      expect(controller.isMinimized, isTrue);
      // Track list should be hidden when minimized
      expect(find.text('Inception.mp4'), findsNothing);

      // Tap again to restore
      await tester.tap(minimizeBtn);
      await tester.pumpAndSettle();
      expect(controller.isMinimized, isFalse);
      expect(find.text('Inception.mp4'), findsOneWidget);
    });

    testWidgets('Import and Export buttons trigger onImportPlaylist and onExportPlaylist callbacks', (tester) async {
      final controller = PlaylistController();
      controller.setItems(testItems);
      bool importCalled = false;
      bool exportCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: UndockedPlaylistPanelWidget(
                controller: controller,
                onSelectTrack: (_) {},
                onClose: () {},
                onDockToggle: () {},
                onImportPlaylist: () => importCalled = true,
                onExportPlaylist: () => exportCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final importBtn = find.byKey(const Key('undocked_playlist_import_button'));
      final exportBtn = find.byKey(const Key('undocked_playlist_export_button'));

      expect(importBtn, findsOneWidget);
      expect(exportBtn, findsOneWidget);

      await tester.tap(importBtn);
      await tester.pumpAndSettle();
      expect(importCalled, isTrue);

      await tester.tap(exportBtn);
      await tester.pumpAndSettle();
      expect(exportCalled, isTrue);
    });
  });

  group('DesktopKeyboardHandler Ctrl+L Toggle Playlist Tests (VLC Parity)', () {
    testWidgets('Ctrl+L triggers onTogglePlaylist callback', (tester) async {
      bool togglePlaylistCalled = false;
      final player = _FakePlayer();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopKeyboardHandler(
              player: player,
              onToggleFullscreen: () {},
              onCycleAspectRatio: () {},
              onCycleAudioTrack: () {},
              onCycleSubtitleTrack: () {},
              onNudgeAudioDelay: (_) {},
              onNudgeSubtitleDelay: (_) {},
              onShowOsd: (msg, icon, [color]) {},
              onUserActivity: () {},
              onTogglePlaylist: () {
                togglePlaylistCalled = true;
              },
              child: const Center(child: Text('Surface')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Send Ctrl+L key event
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(togglePlaylistCalled, isTrue);
    });
  });
}
