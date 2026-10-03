import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'features/library/domain/library_provider.dart';
import 'features/library/ui/library_screen.dart';
import 'features/export/domain/export_service.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // media_kit init can fail if native libs are missing — must not crash the app
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      debugPrint('[E-Player] MediaKit init failed (playback may not work): $e');
    }

    FlutterError.onError = (details) {
      debugPrint('[E-Player] FlutterError: ${details.exceptionAsString()}');
    };

    runApp(const EPlayerApp());
  }, (error, stack) {
    debugPrint('[E-Player] Uncaught error: $error');
    debugPrint('[E-Player] Stack: $stack');
  });
}

class EPlayerApp extends StatelessWidget {
  const EPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => ExportService()),
      ],
      child: MaterialApp(
        title: 'E-Player',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        home: const LibraryScreen(),
      ),
    );
  }
}
