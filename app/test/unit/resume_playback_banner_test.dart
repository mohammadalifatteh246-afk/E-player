import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/widgets/resume_playback_banner_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Resume Playback Prompt Banner (VLC Parity) - Unit & Widget Tests', () {
    testWidgets('Renders prompt title and formatted position correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumePlaybackBannerWidget(
              resumePosition: const Duration(minutes: 4, seconds: 25),
              onResume: () {},
              onRestart: () {},
              onDismiss: () {},
              autoDismissDuration: Duration.zero,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Continue playback?'), findsOneWidget);
      expect(find.text('Resume from 04:25'), findsOneWidget);
      expect(find.byKey(const Key('resume_playback_confirm_button')), findsOneWidget);
      expect(find.byKey(const Key('resume_playback_restart_button')), findsOneWidget);
      expect(find.byKey(const Key('resume_playback_dismiss_button')), findsOneWidget);
    });

    testWidgets('Renders hours in formatted duration when position exceeds 1 hour', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumePlaybackBannerWidget(
              resumePosition: const Duration(hours: 1, minutes: 12, seconds: 40),
              onResume: () {},
              onRestart: () {},
              onDismiss: () {},
              autoDismissDuration: Duration.zero,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Resume from 1:12:40'), findsOneWidget);
    });

    testWidgets('Tapping Resume button fires onResume callback', (tester) async {
      var resumed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumePlaybackBannerWidget(
              resumePosition: const Duration(minutes: 5),
              onResume: () => resumed = true,
              onRestart: () {},
              onDismiss: () {},
              autoDismissDuration: Duration.zero,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('resume_playback_confirm_button')));
      await tester.pump();

      expect(resumed, isTrue);
    });

    testWidgets('Tapping Restart button fires onRestart callback', (tester) async {
      var restarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumePlaybackBannerWidget(
              resumePosition: const Duration(minutes: 5),
              onResume: () {},
              onRestart: () => restarted = true,
              onDismiss: () {},
              autoDismissDuration: Duration.zero,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('resume_playback_restart_button')));
      await tester.pump();

      expect(restarted, isTrue);
    });

    testWidgets('Tapping Close icon fires onDismiss callback', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumePlaybackBannerWidget(
              resumePosition: const Duration(minutes: 5),
              onResume: () {},
              onRestart: () {},
              onDismiss: () => dismissed = true,
              autoDismissDuration: Duration.zero,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('resume_playback_dismiss_button')));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });
  });
}
