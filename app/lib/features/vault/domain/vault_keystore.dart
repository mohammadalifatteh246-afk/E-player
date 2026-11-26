library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Storage category for a Portable E-Player Vault root directory.
enum VaultStorageType {
  internalApp,
  externalDrive,
  customFolder,
}

/// Discovery & status metadata for a vault location (Internal SSD, D:\, SD Card, USB).
class VaultLocationInfo {
  final String directoryPath;
  final String label;
  final VaultStorageType storageType;
  final bool existsOnDisk;
  final bool hasKeystoreEnvelope;
  final int encryptedFileCount;
  final bool isActive;

  const VaultLocationInfo({
    required this.directoryPath,
    required this.label,
    required this.storageType,
    required this.existsOnDisk,
    required this.hasKeystoreEnvelope,
    required this.encryptedFileCount,
    required this.isActive,
  });

  bool get hasExistingVaultData =>
      hasKeystoreEnvelope || encryptedFileCount > 0;
}

/// One AES-256-GCM wrapped DEK slot inside `vault_keystore.json`.
class WrappedKeySlot {
  final String saltB64;
  final String ivB64;
  final String wrappedMasterKeyB64;
  final String kekVerifierSha256;
  final int iterations;
  final String? hint;

  const WrappedKeySlot({
    required this.saltB64,
    required this.ivB64,
    required this.wrappedMasterKeyB64,
    required this.kekVerifierSha256,
    required this.iterations,
    this.hint,
  });

  Map<String, dynamic> toJson() => {
        'saltB64': saltB64,
        'ivB64': ivB64,
        'wrappedMasterKeyB64': wrappedMasterKeyB64,
        'kekVerifierSha256': kekVerifierSha256,
        'iterations': iterations,
        if (hint != null) 'hint': hint,
      };

  factory WrappedKeySlot.fromJson(Map<String, dynamic> json) {
    return WrappedKeySlot(
      saltB64: json['saltB64'] as String? ?? '',
      ivB64: json['ivB64'] as String? ?? '',
      wrappedMasterKeyB64: json['wrappedMasterKeyB64'] as String? ?? '',
      kekVerifierSha256: json['kekVerifierSha256'] as String? ?? '',
      iterations: (json['iterations'] as num?)?.toInt() ?? 10000,
      hint: json['hint'] as String?,
    );
  }
}

/// Self-contained portable recovery envelope stored inside `<vaultDir>/vault_keystore.json`.
/// Guarantees that uninstalling E-Player or moving `D:\` / SD card to another device
/// never permanently locks encrypted media files.
class VaultKeyEnvelope {
  final int version;
  final String vaultId;
  final DateTime createdAt;
  final WrappedKeySlot? pinSlot;
  final WrappedKeySlot? recoverySlot;

  const VaultKeyEnvelope({
    this.version = 2,
    required this.vaultId,
    required this.createdAt,
    this.pinSlot,
    this.recoverySlot,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'vaultId': vaultId,
        'createdAt': createdAt.toIso8601String(),
        if (pinSlot != null) 'pinSlot': pinSlot!.toJson(),
        if (recoverySlot != null) 'recoverySlot': recoverySlot!.toJson(),
      };

  factory VaultKeyEnvelope.fromJson(Map<String, dynamic> json) {
    return VaultKeyEnvelope(
      version: (json['version'] as num?)?.toInt() ?? 2,
      vaultId: json['vaultId'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      pinSlot: json['pinSlot'] is Map<String, dynamic>
          ? WrappedKeySlot.fromJson(json['pinSlot'] as Map<String, dynamic>)
          : null,
      recoverySlot: json['recoverySlot'] is Map<String, dynamic>
          ? WrappedKeySlot.fromJson(
              json['recoverySlot'] as Map<String, dynamic>)
          : null,
    );
  }

  VaultKeyEnvelope copyWith({
    int? version,
    String? vaultId,
    DateTime? createdAt,
    WrappedKeySlot? pinSlot,
    WrappedKeySlot? recoverySlot,
  }) {
    return VaultKeyEnvelope(
      version: version ?? this.version,
      vaultId: vaultId ?? this.vaultId,
      createdAt: createdAt ?? this.createdAt,
      pinSlot: pinSlot ?? this.pinSlot,
      recoverySlot: recoverySlot ?? this.recoverySlot,
    );
  }
}

/// Cryptographic helper for PBKDF2-HMAC-SHA256 KEK derivation, AES-256-GCM key wrapping,
/// and human-readable Emergency Recovery Key generation/normalization.
class VaultKeystoreCrypto {
  VaultKeystoreCrypto._();

  static const int defaultIterations = 10000;
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Generates a 128-bit cryptographic recovery code formatted as `EPLY-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX`.
  static String generateRecoveryKey() {
    final rng = Random.secure();
    final groups = <String>[];
    for (int g = 0; g < 6; g++) {
      final buf = StringBuffer();
      for (int c = 0; c < 4; c++) {
        buf.write(_alphabet[rng.nextInt(_alphabet.length)]);
      }
      groups.add(buf.toString());
    }
    return 'EPLY-${groups.join('-')}';
  }

  /// Normalizes user-entered recovery keys (uppercases and strips spaces/hyphens for comparison & KDF).
  static String normalizeRecoveryInput(String raw) {
    final cleaned = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '');
    if (cleaned.startsWith('EPLY') && cleaned.length > 4) {
      return cleaned;
    }
    return cleaned.isEmpty ? '' : 'EPLY$cleaned';
  }

  /// Formats a masked hint like `EPLY-A7K9-••••-••••-••••-••••-M2P4` without storing secret bits.
  static String buildSafeHint(String recoveryKey) {
    final parts = recoveryKey.split('-');
    if (parts.length >= 4) {
      return '${parts[0]}-${parts[1]}-••••-••••-${parts.last}';
    }
    if (recoveryKey.length >= 8) {
      return '${recoveryKey.substring(0, 4)}••••${recoveryKey.substring(recoveryKey.length - 4)}';
    }
    return 'EPLY-••••';
  }

  /// Iterated PBKDF2-HMAC-SHA256 derivation yielding 256-bit AES KEK.
  static Uint8List deriveKek(
    String secret,
    List<int> saltBytes, {
    int iterations = defaultIterations,
  }) {
    final secretBytes = utf8.encode(secret);
    final hmac = Hmac(sha256, secretBytes);
    final block = List<int>.from(saltBytes)..addAll([0, 0, 0, 1]);
    List<int> u = hmac.convert(block).bytes;
    final out = Uint8List.fromList(u);

    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  /// Wraps a 32-byte DEK (`masterKey`) inside an AES-256-GCM encrypted [WrappedKeySlot].
  static WrappedKeySlot wrapMasterKey({
    required enc.Key masterKey,
    required String secret,
    int iterations = defaultIterations,
    String? hint,
  }) {
    final salt = enc.IV.fromSecureRandom(16).bytes;
    final iv = enc.IV.fromSecureRandom(12);
    final kek = deriveKek(secret, salt, iterations: iterations);
    final verifier = sha256.convert(kek).toString();

    final encrypter =
        enc.Encrypter(enc.AES(enc.Key(kek), mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(masterKey.bytes, iv: iv);

    return WrappedKeySlot(
      saltB64: base64Encode(salt),
      ivB64: iv.base64,
      wrappedMasterKeyB64: encrypted.base64,
      kekVerifierSha256: verifier,
      iterations: iterations,
      hint: hint,
    );
  }

  /// Verifies and unwraps a 32-byte DEK from a [WrappedKeySlot]. Returns null if wrong secret/tampered.
  static enc.Key? unwrapMasterKey({
    required WrappedKeySlot slot,
    required String secret,
  }) {
    try {
      if (slot.saltB64.isEmpty ||
          slot.ivB64.isEmpty ||
          slot.wrappedMasterKeyB64.isEmpty) {
        return null;
      }
      final salt = base64Decode(slot.saltB64);
      final kek = deriveKek(secret, salt, iterations: slot.iterations);
      final actualVerifier = sha256.convert(kek).toString();
      if (actualVerifier != slot.kekVerifierSha256) {
        return null;
      }

      final iv = enc.IV.fromBase64(slot.ivB64);
      final cipher = enc.Encrypted.fromBase64(slot.wrappedMasterKeyB64);
      final encrypter =
          enc.Encrypter(enc.AES(enc.Key(kek), mode: enc.AESMode.gcm));
      final plainBytes = encrypter.decryptBytes(cipher, iv: iv);
      if (plainBytes.length != 32) return null;
      return enc.Key(Uint8List.fromList(plainBytes));
    } catch (_) {
      return null;
    }
  }
}
