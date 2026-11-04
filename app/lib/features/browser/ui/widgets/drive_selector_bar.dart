import 'package:flutter/material.dart';
import '../../../../theme/e_player_colors.dart';

/// Horizontal drive selector bar for switching root logical drives.
class DriveSelectorBar extends StatelessWidget {
  final List<String> drives;
  final String activeRoot;
  final ValueChanged<String> onDriveSelected;

  const DriveSelectorBar({
    super.key,
    required this.drives,
    required this.activeRoot,
    required this.onDriveSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (drives.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: EPlayerColors.background,
        border: Border(
          bottom: BorderSide(color: EPlayerColors.border, width: 0.5),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: drives.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final drive = drives[index];
          final isSelected = drive.toLowerCase() == activeRoot.toLowerCase() ||
              activeRoot.toLowerCase().startsWith(drive.toLowerCase());

          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storage_rounded,
                  size: 14,
                  color: isSelected ? EPlayerColors.background : EPlayerColors.primary,
                ),
                const SizedBox(width: 6),
                Text(drive),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => onDriveSelected(drive),
            backgroundColor: EPlayerColors.surfaceElevated,
            selectedColor: EPlayerColors.primary,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? EPlayerColors.background : EPlayerColors.textPrimary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected ? EPlayerColors.primary : EPlayerColors.border,
                width: 1,
              ),
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}
