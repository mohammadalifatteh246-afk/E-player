# Feature 16 Implementation Plan: Modern Classic Skin Theming Engine (VLC Skins2 Parity)

## Objective
Implement VLC's iconic Skins2 Theming Engine (`skins2` module parity) allowing on-the-fly switching between iconic multimedia aesthetics:
1. **Cyberpunk Neon** (Default E-Player / Stitch V3: Navy + Electric Cyan + Purple Glow)
2. **Classic Winamp / VLC Metallic** (Brushed Aluminum Grey + VLC Cone Amber/Orange + Winamp Green LED)
3. **Minimalist Obsidian** (OLED Pure Pitch Black `#000000` + True White + Hairline Borders)
4. **Retro Amber Phosphor CRT** (Vintage Terminal / Pip-Boy CRT + Monospace + Glowing Amber Phosphor)
5. **macOS Cupertino Glass** (Frosted Translucent Acrylic Glass + Apple Blue + Pill Curves)

All skins persist via `SharedPreferences` across sessions and update the global `MaterialApp` theme and `PlayerScreen` HUD controls instantaneously.

---

## 4-Pillar REA Architecture Breakdown

### Pillar 1: Spec & Presets (`app/lib/features/skins/domain/skin_models.dart`)
- **`SkinThemePreset` Enum**:
  - `cyberpunkNeon`: Cyberpunk Neon
  - `classicMetallic`: Classic Winamp & VLC Metallic
  - `minimalistObsidian`: Minimalist Obsidian (OLED Pure Black)
  - `retroAmberCrt`: Retro Amber CRT Phosphor
  - `cupertinoGlass`: macOS Cupertino Frosted Glass
- **`SkinHudStyle` Enum**:
  - `roundedGlow`, `metallicBevel`, `flatSharp`, `phosphorTerminal`, `glassPill`
- **`SkinThemeData`**:
  - Comprehensive palette tokens: `background`, `surface`, `elevatedSurface`, `border`, `primaryAccent`, `secondaryAccent`, `vlcConeOrange`, `textPrimary`, `textSecondary`, `textMuted`.
  - Layout metrics: `borderRadius`, `hudStyle`, `fontFamily`, `hasScanlines`.
  - Factory `SkinThemeData.fromPreset(SkinThemePreset preset)`.
  - Converter `ThemeData toThemeData()`.

### Pillar 2: Service & Persistence (`app/lib/features/skins/data/skin_theme_service.dart`)
- **`SkinThemeService` (ChangeNotifier)**:
  - Singleton & Provider accessible.
  - Asynchronously loads persisted skin choice from `SharedPreferences` (key: `e_player_active_skin`).
  - `setSkin(SkinThemePreset preset)`: updates state, persists, and calls `notifyListeners()`.
  - `resetToDefault()`: reverts to `SkinThemePreset.cyberpunkNeon`.
  - Exposes `ThemeData get themeData`.

### Pillar 3: Skin Selector Sheet & Interactive Preview UI (`app/lib/features/skins/ui/skin_picker_sheet.dart`)
- Cyberpunk styled modal bottom sheet:
  - Header: Skin Swatch Icon, Title, and active skin badge.
  - Grid/List of Interactive Skin Preview Cards:
    - Mini mockup displaying player window with the skin's background, seekbar color, cone orange accent, and typography.
    - Active checkmark badge on selected skin.
    - 1-tap switching with smooth visual transitions.
  - "Reset to Default" button.

### Pillar 4: App & Player Integration
- In `app/lib/main.dart`:
  - Register `SkinThemeService` in `MultiProvider`.
  - Wrap `MaterialApp` in `Consumer<SkinThemeService>` using `skinService.themeData`.
- In `desktop_keyboard_handler.dart`:
  - Add shortcut `Ctrl+Shift+S` for opening Skin Picker Sheet.
- In `player_screen.dart`:
  - Quick options tile: `hud_skin_picker_button` ("Skins & Themes Engine").
  - Shortcut `Ctrl+Shift+S` opens `SkinPickerSheet`.

---

## Verification Plan

### Automated Unit & Widget Tests:
- `app/test/unit/skin_models_and_service_test.dart`:
  - Verify all 5 skin presets construct with valid non-null colors and styles.
  - Verify `toThemeData()` produces compliant Material 3 dark `ThemeData`.
  - Verify `SkinThemeService` loads and persists skin to `SharedPreferences`.
  - Verify switching preset notifies listeners and updates `themeData`.
- `app/test/unit/skin_picker_widget_test.dart`:
  - Render `SkinPickerSheet` with all 5 skin cards.
  - Verify active checkmark indicator on the current skin.
  - Tapping a skin card (e.g. `classicMetallic` or `retroAmberCrt`) updates active skin in service.
  - Tapping "Reset to Default" reverts to `cyberpunkNeon`.

### Static Analysis:
- `cd app; flutter analyze --no-pub` (Must pass with 0 errors and 0 warnings).
