import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'features/library/domain/library_provider.dart';
import 'features/library/ui/library_screen.dart';
import 'features/export/domain/export_service.dart';
import 'features/vault/domain/vault_service.dart';
import 'features/trash/domain/trash_service.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      debugPrint('[E-Player] MediaKit init failed: \$e');
    }

    FlutterError.onError = (details) {
      debugPrint('[E-Player] FlutterError: \${details.exceptionAsString()}');
    };

    runApp(const EPlayerApp());
  }, (error, stack) {
    debugPrint('[E-Player] Uncaught error: \$error');
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
        ChangeNotifierProvider(create: (_) => VaultService()),
        ChangeNotifierProvider(create: (_) => TrashService()),
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
