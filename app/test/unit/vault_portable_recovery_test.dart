import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/models/media_item.dart';
import 'package:app/features/vault/domain/vault_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VaultKeystoreCrypto Unit Tests (Dual-Slot Key Envelope)', () {
    test('1. Generates valid recovery keys and normalizes hyphen/case variations', () {
      final key = VaultKeystoreCrypto.generateRecoveryKey();
      expect(key.startsWith('EPLY-'), isTrue);
      expect(key.split('-').length, 7);

      final lowerSpaced = key.toLowerCase().replaceAll('-', ' ');
      expect(
        VaultKeystoreCrypto.normalizeRecoveryInput(lowerSpaced),
        VaultKeystoreCrypto.normalizeRecoveryInput(key),
      );
      expect(VaultKeystoreCrypto.buildSafeHint(key), contains('••••'));
    });

    test('2. Wraps and unwraps masterKey independently via PIN slot and Recovery slot', () {
      final originalKey = VaultKeystoreCrypto.generateRecoveryKey();
      final normRecovery = VaultKeystoreCrypto.normalizeRecoveryInput(originalKey);

      final fakeMaster = VaultKeystoreCrypto.deriveKek('seed-secret-material', [1, 2, 3, 4]);
      final masterKeyObj = VaultKeystoreCrypto.unwrapMasterKey(
        slot: VaultKeystoreCrypto.wrapMasterKey(
          masterKey: VaultService.createMasterKeyForTesting(fakeMaster),
          secret: '2468',
        ),
        secret: '2468',
      );
      expect(masterKeyObj, isNotNull);

      final recoverySlot = VaultKeystoreCrypto.wrapMasterKey(
        masterKey: masterKeyObj!,
        secret: normRecovery,
      );
      expect(
        VaultKeystoreCrypto.unwrapMasterKey(slot: recoverySlot, secret: normRecovery)?.bytes,
        equals(masterKeyObj.bytes),
      );
      expect(
        VaultKeystoreCrypto.unwrapMasterKey(slot: recoverySlot, secret: 'EPLY-WRONG-KEY'),
        isNull,
      );
    });
  });

  group('Portable Multi-Drive & Reinstall Recovery Integration Tests', () {
    test('3. Full app uninstall simulation: empty SharedPreferences recovers D:/ vault via PIN alone', () async {
      final externalDriveDir = await Directory.systemTemp.createTemp('mock_d_drive_vault_');
      final sourceMediaDir = await Directory.systemTemp.createTemp('mock_d_source_media_');

      try {
        final externalVaultPath = p.join(externalDriveDir.path, '.eplayer_vault');

        // Phase A: Original installation sets PIN, stores a 4K video in D:\.eplayer_vault
        final sourceVideo = File(p.join(sourceMediaDir.path, '4k_vacation.mkv'));
        final samplePayload = List<int>.generate(256 * 1024, (i) => (i * 17) % 256);
        await sourceVideo.writeAsBytes(samplePayload);

        final service1 = VaultService(
          initialVaultDirOverride: externalVaultPath,
        );
        await service1.setPin('4321');
        final encryptedPath = await service1.moveToVault(
          MediaItem(
            path: sourceVideo.path,
            name: '4k_vacation.mkv',
            parentFolder: sourceMediaDir.path,
            sizeBytes: samplePayload.length,
            lastPlayed: DateTime.now(),
          ),
        );
        expect(File(encryptedPath).existsSync(), isTrue);
        expect(File(p.join(externalVaultPath, 'vault_keystore.json')).existsSync(), isTrue);
        await service1.lock();

        // Phase B: Simulate COMPLETE app uninstall / device swap -> wipe SharedPreferences completely!
        SharedPreferences.setMockInitialValues({});

        final serviceAfterReinstall = VaultService(
          initialVaultDirOverride: externalVaultPath,
        );
        await serviceAfterReinstall.initialize();

        // Wrong PIN fails
        expect(await serviceAfterReinstall.verifyPin('9999'), isFalse);
        expect(serviceAfterReinstall.isUnlocked, isFalse);

        // Original PIN unwraps master key directly from D:\.eplayer_vault\vault_keystore.json!
        expect(await serviceAfterReinstall.verifyPin('4321'), isTrue);
        expect(serviceAfterReinstall.isUnlocked, isTrue);

        final items = await serviceAfterReinstall.getVaultItems();
        expect(items.length, 1);

        // Decryption & playback staging succeeds and matches byte-for-byte!
        final decryptedTempPath = await serviceAfterReinstall.decryptToTemp(items.first);
        // Should be staged on the external vault drive when decryptCacheOnVaultDrive == true
        expect(decryptedTempPath.startsWith(externalVaultPath), isTrue);
        expect(await File(decryptedTempPath).readAsBytes(), equals(samplePayload));

        await serviceAfterReinstall.cleanupTempFiles();
        expect(File(decryptedTempPath).existsSync(), isFalse);
      } finally {
        await externalDriveDir.delete(recursive: true);
        await sourceMediaDir.delete(recursive: true);
      }
    });

    test('4. Forgotten PIN recovery via Emergency Recovery Key unwraps vault and sets new PIN cleanly', () async {
      final sdCardDir = await Directory.systemTemp.createTemp('mock_sd_vault_');
      final mediaDir = await Directory.systemTemp.createTemp('mock_sd_src_');

      try {
        final sdVaultPath = p.join(sdCardDir.path, '.eplayer_vault');
        final sourceFile = File(p.join(mediaDir.path, 'secret_clip.mp4'));
        final bytes = List<int>.generate(64 * 1024, (i) => (i ^ 0x5A) % 256);
        await sourceFile.writeAsBytes(bytes);

        final service1 = VaultService(initialVaultDirOverride: sdVaultPath);
        await service1.setPin('1357');
        final generatedRecoveryKey = await service1.generateOrGetRecoveryKey();
        expect(generatedRecoveryKey, startsWith('EPLY-'));

        await service1.moveToVault(
          MediaItem(
            path: sourceFile.path,
            name: 'secret_clip.mp4',
            parentFolder: mediaDir.path,
            sizeBytes: bytes.length,
            lastPlayed: DateTime.now(),
          ),
        );

        // Wipe local prefs (reinstall / new phone) AND pretend user forgot PIN '1357'
        SharedPreferences.setMockInitialValues({});
        final service2 = VaultService(initialVaultDirOverride: sdVaultPath);
        await service2.initialize();

        final recovered = await service2.recoverWithRecoveryKey(
          recoveryKey: generatedRecoveryKey.toLowerCase(),
          newPin: '8642',
        );
        expect(recovered, isTrue);
        expect(service2.isUnlocked, isTrue);

        // New PIN now works cleanly after locking
        await service2.lock();
        expect(await service2.verifyPin('8642'), isTrue);

        final items = await service2.getVaultItems();
        expect(items.length, 1);
        final decryptedPath = await service2.decryptToTemp(items.first);
        expect(await File(decryptedPath).readAsBytes(), equals(bytes));
      } finally {
        await sdCardDir.delete(recursive: true);
        await mediaDir.delete(recursive: true);
      }
    });

    test('5. Switching between Internal Vault and D:/ Vault keeps each partition isolated & discoverable', () async {
      final mockInternal = await Directory.systemTemp.createTemp('mock_internal_root_');
      final mockDriveD = await Directory.systemTemp.createTemp('mock_drive_d_root_');
      final srcDir = await Directory.systemTemp.createTemp('mock_multi_src_');

      try {
        final internalVaultDir = p.join(mockInternal.path, '.eplayer_vault');
        final dDriveVaultDir = p.join(mockDriveD.path, '.eplayer_vault');

        final f1 = File(p.join(srcDir.path, 'internal_vid.mp4'));
        await f1.writeAsBytes([10, 20, 30, 40]);
        final f2 = File(p.join(srcDir.path, 'd_drive_4k.mkv'));
        await f2.writeAsBytes([50, 60, 70, 80, 90]);

        final service = VaultService(
          initialVaultDirOverride: internalVaultDir,
          internalVaultDirProvider: () async => Directory(internalVaultDir),
          externalDriveRootsProvider: () => [mockDriveD.path],
        );

        await service.setPin('1122');
        await service.moveToVault(MediaItem(
          path: f1.path,
          name: 'internal_vid.mp4',
          parentFolder: srcDir.path,
          sizeBytes: 4,
          lastPlayed: DateTime.now(),
        ));
        expect((await service.getVaultItems()).length, 1);

        // Switch active vault to Drive D:
        await service.switchVaultLocation(dDriveVaultDir, autoPinIfUnlocked: '1122');
        expect(p.equals(service.activeVaultPath ?? '', dDriveVaultDir), isTrue);
        expect((await service.getVaultItems()), isEmpty);

        await service.moveToVault(MediaItem(
          path: f2.path,
          name: 'd_drive_4k.mkv',
          parentFolder: srcDir.path,
          sizeBytes: 5,
          lastPlayed: DateTime.now(),
        ));
        expect((await service.getVaultItems()).length, 1);

        // Discover locations lists both Internal and Drive D with exact counts & keystore flags
        final locations = await service.discoverVaultLocations();
        expect(locations.length, greaterThanOrEqualTo(2));
        final dLoc = locations.firstWhere((l) => p.equals(l.directoryPath, dDriveVaultDir));
        expect(dLoc.encryptedFileCount, 1);
        expect(dLoc.hasKeystoreEnvelope, isTrue);
        expect(dLoc.isActive, isTrue);
      } finally {
        await mockInternal.delete(recursive: true);
        await mockDriveD.delete(recursive: true);
        await srcDir.delete(recursive: true);
      }
    });
  });
}
