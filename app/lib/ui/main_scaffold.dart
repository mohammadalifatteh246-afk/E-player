import 'package:flutter/material.dart';
import '../widgets/e_player_components.dart';
import '../ui/theme/e_design_tokens.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/library/ui/library_screen.dart';
import '../../features/enhancement/ui/enhance_screen.dart';
import '../../features/casting/ui/casting_screen.dart';
import '../../features/settings/ui/settings_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const LibraryScreen(),
    const EnhanceScreen(),
    const CastingScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EDesign.appBackground,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: EDesign.elevatedBackground,
          border: Border(
            top: BorderSide(
              color: EDesign.border.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: EDesign.elevatedBackground,
          selectedItemColor: EDesign.primary,
          unselectedItemColor: EDesign.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: EVectorIcon(name: 'home', size: 20, color: EDesign.textMuted),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: EVectorIcon(name: 'home', size: 20, color: EDesign.primary),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: EVectorIcon(name: 'library', size: 20, color: EDesign.textMuted),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: EVectorIcon(name: 'library', size: 20, color: EDesign.primary),
              ),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: EVectorIcon(name: 'enhance', size: 20, color: EDesign.textMuted),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: EVectorIcon(name: 'enhance', size: 20, color: EDesign.primary),
              ),
              label: 'Enhance',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: EVectorIcon(name: 'cast', size: 20, color: EDesign.textMuted),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: EVectorIcon(name: 'cast', size: 20, color: EDesign.primary),
              ),
              label: 'Casting',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: EVectorIcon(name: 'settings', size: 20, color: EDesign.textMuted),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: EVectorIcon(name: 'settings', size: 20, color: EDesign.primary),
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
