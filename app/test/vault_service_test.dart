import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/vault/domain/vault_service.dart';

void main() {
  group('VaultService Phase 8 Hardening Tests', () {
    test('PBKDF2-HMAC-SHA256 key derivation is deterministic and salt-dependent', () {
      final saltA = utf8.encode('0123456789abcdef');
      final saltB = utf8.encode('fedcba9876543210');

      final key1 = VaultService.deriveKeyFromPin('1234', saltA);
      final key2 = VaultService.deriveKeyFromPin('1234', saltA);
      final keyDiffPin = VaultService.deriveKeyFromPin('9999', saltA);
      final keyDiffSalt = VaultService.deriveKeyFromPin('1234', saltB);

      expect(key1.length, 32);
      expect(key1, equals(key2));
      expect(key1, isNot(equals(keyDiffPin)));
      expect(key1, isNot(equals(keyDiffSalt)));
    });

    test('VaultItemMetadata serializes and deserializes round-trip', () {
      final now = DateTime.utc(2026, 10, 15, 12, 0, 0);
      final meta = VaultItemMetadata(
        id: '1700000000',
        encryptedFileName: '1700000000_clip.mp4.enc',
        originalName: 'clip.mp4',
        originalDir: '/storage/emulated/0/Movies',
        sizeBytes: 4096,
        addedAt: now,
        sha256PlaintextHash: 'abc123def456',
        chunkCount: 1,
      );

      final restored = VaultItemMetadata.fromJson(meta.toJson());
      expect(restored.id, meta.id);
      expect(restored.encryptedFileName, meta.encryptedFileName);
      expect(restored.originalName, meta.originalName);
      expect(restored.originalDir, meta.originalDir);
      expect(restored.sizeBytes, meta.sizeBytes);
      expect(restored.sha256PlaintextHash, meta.sha256PlaintextHash);
      expect(restored.chunkCount, meta.chunkCount);
    });
  });
}
