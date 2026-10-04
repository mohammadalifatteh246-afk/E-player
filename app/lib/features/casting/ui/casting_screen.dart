import 'package:flutter/material.dart';

class CastingScreen extends StatelessWidget {
  const CastingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      appBar: AppBar(
        title: const Text('Network & Casting', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Casting (V3 Construction)', style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}
