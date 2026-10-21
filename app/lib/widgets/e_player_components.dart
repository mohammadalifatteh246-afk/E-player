import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/e_player_colors.dart';

class EPrimaryButton extends StatelessWidget {
  const EPrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = true, this.isLoading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool isLoading;
  @override
  Widget build(BuildContext context) {
    final Widget content = isLoading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]);
    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(backgroundColor: EPlayerColors.blue, foregroundColor: Colors.white, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
      child: content,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class ESecondaryButton extends StatelessWidget {
  const ESecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: EPlayerColors.textPrimary, side: const BorderSide(color: EPlayerColors.border), minimumSize: const Size(44, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class EIconActionButton extends StatelessWidget {
  const EIconActionButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.selected = false, this.size = 44});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip, onPressed: onPressed, constraints: BoxConstraints.tightFor(width: size, height: size),
    style: IconButton.styleFrom(backgroundColor: selected ? EPlayerColors.blue.withValues(alpha: .18) : EPlayerColors.surface, foregroundColor: selected ? EPlayerColors.primary : EPlayerColors.textPrimary, side: const BorderSide(color: EPlayerColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    icon: Icon(icon, size: 20),
  );
}

class ESectionHeader extends StatelessWidget {
  const ESectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.subtitle});
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)],
    ])),
    if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
  ]);
}

class EMediaBadge extends StatelessWidget {
  const EMediaBadge({super.key, required this.label, this.color = EPlayerColors.primary, this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: .16), border: Border.all(color: color.withValues(alpha: .65)), borderRadius: BorderRadius.circular(7)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}

class ESettingTile extends StatelessWidget {
  const ESettingTile({super.key, required this.title, required this.icon, this.subtitle, this.trailing, this.onTap});
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(13),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13), child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: EPlayerColors.surfaceElevated, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: EPlayerColors.primary, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)],
      ])),
      if (trailing != null) trailing! else const Icon(Icons.chevron_right, color: EPlayerColors.textMuted),
    ])),
  ));
}

class ESettingSwitchTile extends StatelessWidget {
  const ESettingSwitchTile({super.key, required this.title, required this.icon, required this.value, required this.onChanged, this.subtitle});
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => ESettingTile(title: title, subtitle: subtitle, icon: icon, trailing: Switch(value: value, onChanged: onChanged));
}

class EMediaCard extends StatelessWidget {
  const EMediaCard({super.key, required this.title, required this.image, this.subtitle, this.badge, this.progress, this.onTap, this.aspectRatio = 16 / 9});
  final String title;
  final String? subtitle;
  final ImageProvider image;
  final String? badge;
  final double? progress;
  final VoidCallback? onTap;
  final double aspectRatio;
  @override
  Widget build(BuildContext context) => Material(
    color: EPlayerColors.surface, clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: EPlayerColors.border)),
    child: InkWell(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(aspectRatio: aspectRatio, child: Stack(fit: StackFit.expand, children: [
        Image(image: image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: EPlayerColors.surfaceElevated, child: Icon(Icons.movie, size: 36))),
        if (badge != null) Positioned(top: 8, right: 8, child: EMediaBadge(label: badge!, color: Colors.white)),
        if (progress != null) Positioned(left: 0, right: 0, bottom: 0, child: LinearProgressIndicator(value: progress!.clamp(0, 1), minHeight: 3, backgroundColor: Colors.black45, valueColor: const AlwaysStoppedAnimation(EPlayerColors.primary))),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(10, 9, 10, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)],
      ])),
    ])),
  );
}

class EEmptyState extends StatelessWidget {
  const EEmptyState({super.key, required this.title, required this.message, this.icon = Icons.video_library_outlined, this.actionLabel, this.onAction});
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 72, height: 72, decoration: BoxDecoration(color: EPlayerColors.surfaceElevated, borderRadius: BorderRadius.circular(22), border: Border.all(color: EPlayerColors.border)), child: Icon(icon, size: 34, color: EPlayerColors.primary)),
    const SizedBox(height: 18), Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
    if (actionLabel != null) ...[const SizedBox(height: 18), EPrimaryButton(label: actionLabel!, onPressed: onAction, expand: false)],
  ])));
}

class EProgressBar extends StatelessWidget {
  const EProgressBar({super.key, required this.value, this.height = 4});
  final double value;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(height), child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: height, backgroundColor: EPlayerColors.border, valueColor: const AlwaysStoppedAnimation(EPlayerColors.primary)));
}

class EMediaBottomNavigation extends StatelessWidget {
  const EMediaBottomNavigation({super.key, required this.selectedIndex, required this.onDestinationSelected});
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  @override
  Widget build(BuildContext context) => NavigationBar(selectedIndex: selectedIndex, onDestinationSelected: onDestinationSelected, destinations: const [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Library'),
    NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Enhance'),
    NavigationDestination(icon: Icon(Icons.cast_outlined), selectedIcon: Icon(Icons.cast), label: 'Cast'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
  ]);
}

class ESurface extends StatelessWidget {
  const ESurface({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 16});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(padding: padding, decoration: BoxDecoration(color: EPlayerColors.surface, border: Border.all(color: EPlayerColors.border), borderRadius: BorderRadius.circular(radius)), child: child);
}

/// Loads local SVG icons from `assets/icons/{name}.svg`.
class EVectorIcon extends StatelessWidget {
  const EVectorIcon({super.key, required this.name, this.size = 24, this.color = EPlayerColors.textPrimary});
  final String name;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/icons/$name.svg', width: size, height: size, colorFilter: ColorFilter.mode(color, BlendMode.srcIn), semanticsLabel: name.replaceAll('_', ' '));
}
