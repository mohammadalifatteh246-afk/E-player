import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'features/library/domain/library_provider.dart';
import 'ui/main_scaffold.dart';
import 'features/export/domain/export_service.dart';
import 'features/vault/domain/vault_service.dart';
import 'features/trash/domain/trash_service.dart';
import 'features/settings/domain/settings_provider.dart';
import 'features/casting/domain/cast_service.dart';
import 'features/home/domain/media_group_service.dart';
import 'features/skins/data/skin_theme_service.dart';
import 'features/external_launch/data/external_launch_service.dart';
import 'features/external_launch/domain/external_launch_models.dart';
import 'features/player/ui/player_screen.dart';
import 'ui/theme/e_design_tokens.dart';

void main(List<String> args) {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      debugPrint('[E-Player] MediaKit init failed: $e');
    }

    try {
      await ExternalLaunchService.instance.initialize(cliArgs: args);
    } catch (e) {
      debugPrint('[E-Player] ExternalLaunchService init failed: $e');
    }

    FlutterError.onError = (details) {
      debugPrint('[E-Player] FlutterError: ${details.exceptionAsString()}');
    };

    runApp(const EPlayerApp());
  }, (error, stack) {
    debugPrint('[E-Player] Uncaught error: $error');
  });
}

class EPlayerApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const EPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => ExportService()),
        ChangeNotifierProvider(create: (_) => VaultService()),
        ChangeNotifierProvider(create: (_) => TrashService()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CastService()),
        ChangeNotifierProvider(create: (_) => MediaGroupService()),
        ChangeNotifierProvider(create: (_) => VideoGroupingService()),
        ChangeNotifierProvider(create: (_) => SkinThemeService()),
        ChangeNotifierProvider.value(value: ExternalLaunchService.instance),
      ],
      child: Consumer<SkinThemeService>(
        builder: (context, skinService, _) => MaterialApp(
          navigatorKey: navigatorKey,
          title: 'E-Player',
          theme: skinService.themeData,
          debugShowCheckedModeBanner: false,
          home: const ExternalLaunchCoordinator(child: MainScaffold()),
        ),
      ),
    );
  }
}

/// Coordinates cold-start CLI / Intent playback and warm external file launches
/// across the application without stacking duplicate player routes.
class ExternalLaunchCoordinator extends StatefulWidget {
  final Widget child;

  const ExternalLaunchCoordinator({super.key, required this.child});

  @override
  State<ExternalLaunchCoordinator> createState() =>
      _ExternalLaunchCoordinatorState();
}

class _ExternalLaunchCoordinatorState extends State<ExternalLaunchCoordinator> {
  StreamSubscription<ExternalLaunchRequest>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ExternalLaunchService.instance.launchStream
        .listen(_handleExternalLaunch);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final coldStart =
          ExternalLaunchService.instance.consumePendingColdStart();
      if (coldStart != null) {
        _handleExternalLaunch(coldStart);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handleExternalLaunch(ExternalLaunchRequest req) async {
    if (!mounted) return;
    final launchService = ExternalLaunchService.instance;

    if (req.kind == ExternalMediaKind.networkStream &&
        !launchService.autoPlayStreams) {
      return;
    }

    // 1. If PlayerScreen is currently active on screen, hand over cleanly
    final activeHandler = launchService.activePlayerHandler;
    if (activeHandler != null) {
      final handled = await activeHandler(req);
      if (!mounted) return;
      if (handled) return;
    }

    // 2. Orphan subtitle clicked externally while no video is active
    if (req.kind == ExternalMediaKind.subtitle) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          backgroundColor: EDesign.surface,
          content: Text(
            'Open a video first, then select ${req.displayName} to attach subtitles.',
            style: const TextStyle(color: EDesign.textPrimary),
          ),
        ),
      );
      return;
    }

    // 3. Open PlayerScreen straight away on cold or warm app-level launch
    if (req.isPlayable || req.uri.isNotEmpty) {
      final nav = EPlayerApp.navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            mediaPath: req.uri,
            extraPaths: req.extraUris,
            displayTitle: req.displayName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
