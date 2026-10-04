import 'package:flutter/material.dart';
import 'enhancement_studio_sheet.dart';

class EnhanceScreen extends StatelessWidget {
  const EnhanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      appBar: AppBar(
        title: const Text('Enhancement Studio', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Enhancement Settings (V3 Construction)', style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}
