library;

import 'package:flutter/material.dart';
import '../domain/skin_models.dart';
import '../data/skin_theme_service.dart';

/// Modal bottom sheet allowing users to browse, live-preview, and select skins (VLC Skins2 Parity).
class SkinPickerSheet extends StatefulWidget {
  final SkinThemeService skinService;

  const SkinPickerSheet({super.key, required this.skinService});

  static Future<void> show(BuildContext context, SkinThemeService skinService) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SkinPickerSheet(skinService: skinService),
    );
  }

  @override
  State<SkinPickerSheet> createState() => _SkinPickerSheetState();
}

class _SkinPickerSheetState extends State<SkinPickerSheet> {
  @override
  void initState() {
    super.initState();
    widget.skinService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    widget.skinService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activeSkin = widget.skinService.currentSkin;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: activeSkin.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.vertical(top: Radius.circular(activeSkin.borderRadius * 1.5)),
        border: Border.all(color: activeSkin.primaryAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: activeSkin.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row: Icon, Title & Reset Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        activeSkin.primaryAccent.withValues(alpha: 0.25),
                        activeSkin.secondaryAccent.withValues(alpha: 0.25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: activeSkin.primaryAccent.withValues(alpha: 0.4)),
                  ),
                  child: Icon(
                    Icons.palette_rounded,
                    color: activeSkin.primaryAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MODERN CLASSIC SKINS',
                        style: TextStyle(
                          color: activeSkin.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'VLC Skins2 & Winamp Dynamic Theme Engine',
                        style: TextStyle(
                          color: activeSkin.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const Key('reset_default_skin_button'),
                  style: TextButton.styleFrom(
                    foregroundColor: activeSkin.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  onPressed: widget.skinService.resetToDefault,
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(color: activeSkin.border, height: 1),
            const SizedBox(height: 12),

            // Section Label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SELECT INTERFACE AESTHETIC (${SkinThemePreset.values.length} PRESETS)',
                  style: TextStyle(
                    color: activeSkin.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: activeSkin.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: activeSkin.primaryAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    activeSkin.name.toUpperCase(),
                    style: TextStyle(
                      color: activeSkin.primaryAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // List of Skin Cards
            Expanded(
              child: ListView.separated(
                itemCount: SkinThemePreset.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final preset = SkinThemePreset.values[index];
                  final skinData = SkinThemeData.fromPreset(preset);
                  final isSelected = widget.skinService.currentPreset == preset;

                  return _buildSkinCard(
                    skinData: skinData,
                    isSelected: isSelected,
                    onTap: () => widget.skinService.setSkin(preset),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkinCard({
    required SkinThemeData skinData,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: Key('skin_card_${skinData.preset.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(skinData.borderRadius + 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: skinData.surface,
          borderRadius: BorderRadius.circular(skinData.borderRadius + 4),
          border: Border.all(
            color: isSelected ? skinData.primaryAccent : skinData.border,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: skinData.primaryAccent.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Preset Icon, Name, and Active Indicator
            Row(
              children: [
                Icon(skinData.preset.icon, color: skinData.primaryAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skinData.name,
                        style: TextStyle(
                          color: skinData.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        skinData.description,
                        style: TextStyle(
                          color: skinData.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: skinData.primaryAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: skinData.background, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: skinData.background,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Realistic Miniature Player Mockup Surface
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: skinData.background,
                borderRadius: BorderRadius.circular(skinData.borderRadius),
                border: Border.all(color: skinData.border),
              ),
              child: Column(
                children: [
                  // Mock Top Title Bar
                  Row(
                    children: [
                      Icon(Icons.play_circle_fill_rounded, color: skinData.vlcConeOrange, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Interstellar_4K_Remux.mkv',
                          style: TextStyle(
                            fontFamily: skinData.hasScanlines ? 'monospace' : null,
                            color: skinData.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '01:42:15',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: skinData.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mock Seekbar Line
                  ClipRRect(
                    borderRadius: BorderRadius.circular(skinData.borderRadius / 2),
                    child: SizedBox(
                      height: 4,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 45,
                            child: Container(color: skinData.primaryAccent),
                          ),
                          Expanded(
                            flex: 55,
                            child: Container(color: skinData.border),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Mock Controls Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.skip_previous_rounded, color: skinData.textSecondary, size: 14),
                          const SizedBox(width: 6),
                          Icon(Icons.pause_circle_filled_rounded, color: skinData.primaryAccent, size: 18),
                          const SizedBox(width: 6),
                          Icon(Icons.skip_next_rounded, color: skinData.textSecondary, size: 14),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: skinData.vlcConeOrange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'VLC 100%',
                              style: TextStyle(
                                color: skinData.vlcConeOrange,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.fullscreen_rounded, color: skinData.secondaryAccent, size: 14),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
