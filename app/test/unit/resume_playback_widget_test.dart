import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/ui/widgets/resume_playback_banner_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Resume Playback Flow UI Integration Tests (VLC Parity)', () {
    testWidgets('Full Resume flow: user taps Resume and seeks to saved position', (tester) async {
      Duration currentPos = Duration.zero;
      bool bannerVisible = true;
      const savedPos = Duration(minutes: 3, seconds: 45);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Stack(
                  children: [
                    Center(
                      child: Text('Current: ${currentPos.inSeconds}s'),
                    ),
                    if (bannerVisible)
                      Positioned(
                        top: 40,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ResumePlaybackBannerWidget(
                            resumePosition: savedPos,
                            onResume: () {
                              setState(() {
                                currentPos = savedPos;
                                bannerVisible = false;
                              });
                            },
                            onRestart: () {
                              setState(() {
                                currentPos = Duration.zero;
                                bannerVisible = false;
                              });
                            },
                            onDismiss: () {
                              setState(() {
                                bannerVisible = false;
                              });
                            },
                            autoDismissDuration: Duration.zero,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Current: 0s'), findsOneWidget);
      expect(find.text('Continue playback?'), findsOneWidget);
      expect(find.text('Resume from 03:45'), findsOneWidget);

      // Tap Resume
      await tester.tap(find.byKey(const Key('resume_playback_confirm_button')));
      await tester.pumpAndSettle();

      expect(currentPos, equals(savedPos));
      expect(find.text('Current: 225s'), findsOneWidget);
      expect(find.byKey(const Key('resume_playback_confirm_button')), findsNothing);
    });

    testWidgets('Full Restart flow: user taps Restart and resets to 0s', (tester) async {
      Duration currentPos = const Duration(minutes: 1);
      bool bannerVisible = true;
      const savedPos = Duration(minutes: 10);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Stack(
                  children: [
                    Center(
                      child: Text('Current: ${currentPos.inSeconds}s'),
                    ),
                    if (bannerVisible)
                      Positioned(
                        top: 40,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ResumePlaybackBannerWidget(
                            resumePosition: savedPos,
                            onResume: () {},
                            onRestart: () {
                              setState(() {
                                currentPos = Duration.zero;
                                bannerVisible = false;
                              });
                            },
                            onDismiss: () {},
                            autoDismissDuration: Duration.zero,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Restart
      await tester.tap(find.byKey(const Key('resume_playback_restart_button')));
      await tester.pumpAndSettle();

      expect(currentPos, equals(Duration.zero));
      expect(find.text('Current: 0s'), findsOneWidget);
      expect(find.byKey(const Key('resume_playback_restart_button')), findsNothing);
    });

    testWidgets('Dismiss flow: user taps Close and dismisses banner without seeking', (tester) async {
      Duration currentPos = const Duration(seconds: 15);
      bool bannerVisible = true;
      const savedPos = Duration(minutes: 2);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Stack(
                  children: [
                    Center(
                      child: Text('Current: ${currentPos.inSeconds}s'),
                    ),
                    if (bannerVisible)
                      Positioned(
                        top: 40,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ResumePlaybackBannerWidget(
                            resumePosition: savedPos,
                            onResume: () {},
                            onRestart: () {},
                            onDismiss: () {
                              setState(() {
                                bannerVisible = false;
                              });
                            },
                            autoDismissDuration: Duration.zero,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Close
      await tester.tap(find.byKey(const Key('resume_playback_dismiss_button')));
      await tester.pumpAndSettle();

      expect(currentPos, equals(const Duration(seconds: 15)));
      expect(find.byKey(const Key('resume_playback_dismiss_button')), findsNothing);
    });
  });
}
