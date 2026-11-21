import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/audio/domain/dual_audio_models.dart';
import 'package:app/features/audio/domain/dual_audio_service.dart';
import 'package:app/features/audio/ui/dual_audio_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DualAudioSheet UI Widget Tests (VLC Parity)', () {
    testWidgets('1. Displays Dual Audio Studio Sheet and toggles master switch', (tester) async {
      final service = DualAudioService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualAudioSheet(
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dual Audio & Dubbing Studio'), findsOneWidget);
      expect(find.text('Enable Dual Audio Output'), findsOneWidget);

      // Routing mode chips hidden when disabled
      expect(find.byKey(const Key('dual_audio_mode_mirror')), findsNothing);

      // Toggle enable
      final enableSwitch = find.byKey(const Key('dual_audio_enable_switch'));
      await tester.tap(enableSwitch);
      await tester.pumpAndSettle();

      expect(service.config.enabled, isTrue);
      expect(find.byKey(const Key('dual_audio_mode_mirror')), findsOneWidget);
      expect(find.byKey(const Key('dual_audio_mode_dubbing')), findsOneWidget);
    });

    testWidgets('2. Switching routing mode chips updates service routingMode', (tester) async {
      final service = DualAudioService()..toggleEnabled();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualAudioSheet(
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dubbingChip = find.byKey(const Key('dual_audio_mode_dubbing'));
      expect(dubbingChip, findsOneWidget);
      await tester.tap(dubbingChip);
      await tester.pumpAndSettle();

      expect(service.config.routingMode, equals(DualAudioRoutingMode.dualTrackDubbing));
    });

    testWidgets('3. Toggling secondary mute button updates isSecondaryMuted', (tester) async {
      final service = DualAudioService()..toggleEnabled();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualAudioSheet(
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final muteButton = find.byKey(const Key('dual_audio_secondary_mute_button'));
      expect(muteButton, findsOneWidget);
      await tester.ensureVisible(muteButton);
      await tester.tap(muteButton);
      await tester.pumpAndSettle();

      expect(service.config.isSecondaryMuted, isTrue);
    });

    testWidgets('4. Tapping Reset button restores defaults', (tester) async {
      final service = DualAudioService()
        ..toggleEnabled()
        ..setSecondaryVolume(160.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualAudioSheet(
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resetButton = find.byKey(const Key('dual_audio_reset_button'));
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(service.config.enabled, isFalse);
      expect(service.config.secondaryVolume, equals(100.0));
    });
  });
}
