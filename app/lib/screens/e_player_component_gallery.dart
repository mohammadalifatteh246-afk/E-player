import 'package:flutter/material.dart';
import '../theme/e_player_colors.dart';
import '../widgets/e_player_logo.dart';
import '../widgets/e_player_components.dart';

/// Temporary preview gallery. Register as a debug route during integration.
class EPlayerComponentGallery extends StatefulWidget {
  const EPlayerComponentGallery({super.key});
  @override
  State<EPlayerComponentGallery> createState() => _EPlayerComponentGalleryState();
}
class _EPlayerComponentGalleryState extends State<EPlayerComponentGallery> {
  bool aiEnabled = true;
  bool gesturesEnabled = true;
  int selectedTab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('E-Player UI Kit'), leadingWidth: 150, leading: const Padding(padding: EdgeInsets.only(left: 12), child: Align(alignment: Alignment.centerLeft, child: EPlayerLogo(height: 27)))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const ESectionHeader(title: 'Your Media. Your Control.', subtitle: 'Reusable E-Player design components'),
      const SizedBox(height: 16),
      ESurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Brand', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12), const EPlayerLogo(height: 56), const SizedBox(height: 18),
        const Wrap(spacing: 8, runSpacing: 8, children: [
          EMediaBadge(label: '4K'), EMediaBadge(label: 'HDR', color: EPlayerColors.purple),
          EMediaBadge(label: 'AI READY', color: EPlayerColors.success), EMediaBadge(label: 'OFFLINE', color: EPlayerColors.info),
        ]),
      ])),
      const SizedBox(height: 14), const ESectionHeader(title: 'Actions'), const SizedBox(height: 10),
      Row(children: [Expanded(child: EPrimaryButton(label: 'Enhance', icon: Icons.auto_awesome, onPressed: () {})), const SizedBox(width: 10), const ESecondaryButton(label: 'Details', icon: Icons.info_outline, onPressed: null)]),
      const SizedBox(height: 14), const ESectionHeader(title: 'Player settings'), const SizedBox(height: 8),
      ESurface(child: Column(children: [
        ESettingSwitchTile(title: 'AI Enhancement', subtitle: 'Connect to actual model state', icon: Icons.auto_awesome, value: aiEnabled, onChanged: (v) => setState(() => aiEnabled = v)),
        const Divider(color: EPlayerColors.border),
        ESettingSwitchTile(title: 'Gesture Controls', subtitle: 'Volume, brightness and seeking', icon: Icons.gesture, value: gesturesEnabled, onChanged: (v) => setState(() => gesturesEnabled = v)),
        const ESettingTile(title: 'Decoder Mode', subtitle: 'Auto · hardware where supported', icon: Icons.memory, trailing: Text('Auto')),
        const ESettingTile(title: 'Subtitles', subtitle: 'Track, delay and style', icon: Icons.subtitles_outlined),
      ])),
      const SizedBox(height: 14), const ESectionHeader(title: 'Media card'), const SizedBox(height: 10),
      SizedBox(width: 220, child: EMediaCard(title: 'The Last Horizon', subtitle: 'Demo thumbnail · 01:24 watched', image: const AssetImage('assets/thumbnails/demo_landscape.png'), badge: '4K', progress: .62, onTap: () {})),
      const SizedBox(height: 18),
      const EEmptyState(title: 'Your library is ready', message: 'Add a video or scan a folder to build your library.', icon: Icons.video_library_outlined, actionLabel: 'Add Media'),
      const SizedBox(height: 24),
    ]),
    bottomNavigationBar: EMediaBottomNavigation(selectedIndex: selectedTab, onDestinationSelected: (index) => setState(() => selectedTab = index)),
  );
}
