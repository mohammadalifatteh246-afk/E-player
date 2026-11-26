import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/models/media_item.dart';
import 'package:app/features/vault/domain/vault_service.dart';
import 'package:app/features/vault/ui/vault_storage_recovery_studio_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> waitForLocationsLoaded(WidgetTester tester) async {
    for (int i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  Future<void> safeDeleteDir(Directory? dir) async {
    if (dir == null) return;
    for (int i = 0; i < 8; i++) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        return;
      } on FileSystemException {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  group('VaultStorageRecoveryStudioSheet Widget Tests', () {
    testWidgets('1. Displays Internal + External Drive locations and allows switching to D:/ vault', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockInternal = await tester.runAsync(
        () => Directory.systemTemp.createTemp('studio_internal_'),
      );
      final mockDriveD = await tester.runAsync(
        () => Directory.systemTemp.createTemp('studio_drive_d_'),
      );

      try {
        final internalDir = p.join(mockInternal!.path, '.eplayer_vault');
        final dDir = p.join(mockDriveD!.path, '.eplayer_vault');

        final service = VaultService(
          initialVaultDirOverride: internalDir,
          internalVaultDirProvider: () async => Directory(internalDir),
          externalDriveRootsProvider: () => [mockDriveD.path],
        );

        await tester.runAsync(() => service.setPin('1234'));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VaultStorageRecoveryStudioSheet(service: service),
            ),
          ),
        );
        await waitForLocationsLoaded(tester);

        expect(find.text('Vault Storage & Recovery Studio'), findsOneWidget);
        expect(find.text('Internal App Storage Vault'), findsOneWidget);
        expect(find.byKey(Key('vault_switch_loc_$dDir')), findsOneWidget);

        await tester.tap(find.byKey(Key('vault_switch_loc_$dDir')));
        await tester.pump();
        for (int i = 0; i < 60; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          if (p.equals(service.activeVaultPath ?? '', dDir) &&
              find.textContaining('Switched to').evaluate().isNotEmpty) {
            break;
          }
        }
        await tester.pumpAndSettle();

        expect(p.equals(service.activeVaultPath ?? '', dDir), isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 150));
          await safeDeleteDir(mockInternal);
          await safeDeleteDir(mockDriveD);
        });
      }
    });

    testWidgets('2. Locked Studio allows full Recovery Key + New PIN restore after reinstall', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final vaultRoot = await tester.runAsync(
        () => Directory.systemTemp.createTemp('studio_recover_root_'),
      );
      final srcDir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('studio_recover_src_'),
      );

      try {
        final vaultPath = p.join(vaultRoot!.path, '.eplayer_vault');

        // Setup existing encrypted file & generate recovery key
        final recoveryKey = await tester.runAsync(() async {
          final srcFile = File(p.join(srcDir!.path, 'movie.mp4'));
          await srcFile.writeAsBytes([1, 2, 3, 4, 5]);
          final s1 = VaultService(
            initialVaultDirOverride: vaultPath,
            internalVaultDirProvider: () async => Directory(vaultPath),
            externalDriveRootsProvider: () => const [],
          );
          await s1.setPin('5555');
          await s1.moveToVault(MediaItem(
            path: srcFile.path,
            name: 'movie.mp4',
            parentFolder: srcDir.path,
            sizeBytes: 5,
            lastPlayed: DateTime.now(),
          ));
          return await s1.generateOrGetRecoveryKey();
        });

        // Fresh install state (empty prefs) -> Vault locked
        SharedPreferences.setMockInitialValues({});
        final s2 = VaultService(
          initialVaultDirOverride: vaultPath,
          internalVaultDirProvider: () async => Directory(vaultPath),
          externalDriveRootsProvider: () => const [],
        );
        await tester.runAsync(() => s2.initialize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VaultStorageRecoveryStudioSheet(service: s2),
            ),
          ),
        );
        await waitForLocationsLoaded(tester);

        expect(find.byKey(const Key('vault_recover_key_input')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('vault_recover_key_input')),
          recoveryKey!,
        );
        await tester.enterText(
          find.byKey(const Key('vault_recover_new_pin_input')),
          '9876',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('vault_recover_submit_btn')));
        await tester.pump();
        for (int i = 0; i < 60; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          if (s2.isUnlocked) break;
        }
        await tester.pumpAndSettle();

        expect(s2.isUnlocked, isTrue);
        expect((await tester.runAsync(() => s2.getVaultItems()))!.length, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 150));
          await safeDeleteDir(vaultRoot);
          await safeDeleteDir(srcDir);
        });
      }
    });
  });
}
