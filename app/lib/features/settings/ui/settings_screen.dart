import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            subtitle: const Text('E-Player version 1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'E-Player',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.play_circle, size: 48),
                children: [
                  const Text('A premium media player built with Flutter and media_kit.'),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Theme'),
            subtitle: const Text('Dark Mode (Default)'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme customization coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
