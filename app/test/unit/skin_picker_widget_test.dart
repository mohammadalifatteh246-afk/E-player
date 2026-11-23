import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/skins/domain/skin_models.dart';
import 'package:app/features/skins/data/skin_theme_service.dart';
import 'package:app/features/skins/ui/skin_picker_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SkinPickerSheet Widget Tests (VLC Skins2 Parity)', () {
    late SkinThemeService skinService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      skinService = SkinThemeService(prefs: prefs);
    });

    tearDown(() {
      skinService.dispose();
    });

    testWidgets('1. Renders title, all 5 skin cards, and active indicator', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkinPickerSheet(skinService: skinService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MODERN CLASSIC SKINS'), findsOneWidget);
      expect(find.textContaining('VLC Skins2 & Winamp'), findsOneWidget);
      expect(find.byKey(const Key('reset_default_skin_button')), findsOneWidget);

      // Verify all 5 skin preset cards exist
      expect(find.byKey(const Key('skin_card_cyberpunkNeon')), findsOneWidget);
      expect(find.byKey(const Key('skin_card_classicMetallic')), findsOneWidget);
      expect(find.byKey(const Key('skin_card_minimalistObsidian')), findsOneWidget);
      expect(find.byKey(const Key('skin_card_retroAmberCrt')), findsOneWidget);
      expect(find.byKey(const Key('skin_card_cupertinoGlass')), findsOneWidget);

      // Default active skin has ACTIVE badge
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('2. Tapping a skin card switches active skin and updates state', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkinPickerSheet(skinService: skinService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Classic VLC & Winamp skin card
      final classicCard = find.byKey(const Key('skin_card_classicMetallic'));
      await tester.ensureVisible(classicCard);
      await tester.tap(classicCard);
      await tester.pumpAndSettle();

      expect(skinService.currentPreset, SkinThemePreset.classicMetallic);
      expect(skinService.currentSkin.name, 'Classic VLC & Winamp');

      // Tap Retro Amber CRT card
      final amberCard = find.byKey(const Key('skin_card_retroAmberCrt'));
      await tester.ensureVisible(amberCard);
      await tester.tap(amberCard);
      await tester.pumpAndSettle();

      expect(skinService.currentPreset, SkinThemePreset.retroAmberCrt);
      expect(skinService.currentSkin.name, 'Retro Amber CRT');
    });

    testWidgets('3. Tapping reset button resets skin back to Cyberpunk Neon', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Change skin first
      await skinService.setSkin(SkinThemePreset.cupertinoGlass);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkinPickerSheet(skinService: skinService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(skinService.currentPreset, SkinThemePreset.cupertinoGlass);

      // Tap Reset button
      final resetButton = find.byKey(const Key('reset_default_skin_button'));
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(skinService.currentPreset, SkinThemePreset.cyberpunkNeon);
      expect(skinService.currentSkin.name, 'Cyberpunk Neon');
    });
  });
}
