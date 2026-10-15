import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/media_item.dart';
import '../../../ui/theme/e_design_tokens.dart';

class VaultTamperException implements Exception {
  final String message;
  const VaultTamperException(this.message);

  @override
  String toString() => 'VaultTamperException: $message';
}

class VaultItemMetadata {
  final String id;
  final String encryptedFileName;
  final String originalName;
  final String originalDir;
  final int sizeBytes;
  final DateTime addedAt;
  final String sha256PlaintextHash;
  final int chunkCount;

  const VaultItemMetadata({
    required this.id,
    required this.encryptedFileName,
    required this.originalName,
    required this.originalDir,
    required this.sizeBytes,
    required this.addedAt,
    required this.sha256PlaintextHash,
    required this.chunkCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'encryptedFileName': encryptedFileName,
        'originalName': originalName,
        'originalDir': originalDir,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
        'sha256PlaintextHash': sha256PlaintextHash,
        'chunkCount': chunkCount,
      };

  factory VaultItemMetadata.fromJson(Map<String, dynamic> json) {
    return VaultItemMetadata(
      id: json['id'] as String? ?? '',
      encryptedFileName: json['encryptedFileName'] as String? ?? '',
      originalName: json['originalName'] as String? ?? 'vault_media.mp4',
      originalDir: json['originalDir'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      sha256PlaintextHash: json['sha256PlaintextHash'] as String? ?? '',
      chunkCount: (json['chunkCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class VaultService extends ChangeNotifier {
  static const int _pbkdf2Iterations = 10000;
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(seconds: 30);
  static const int _chunkSize = 1024 * 1024; // 1 MB authenticated chunks
  static const List<int> _magicHeader = [0x45, 0x50, 0x56, 0x33]; // "EPV3"

  bool _isUnlocked = false;
  bool get isUnlocked => _isUnlocked;

  bool _autoLockOnExit = true;
  bool get autoLockOnExit => _autoLockOnExit;

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;

  DateTime? _lockoutUntil;
  DateTime? get lockoutUntil => _lockoutUntil;

  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  int get remainingLockoutSeconds => isLockedOut
      ? _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(1, 3600)
      : 0;

  enc.Key? _masterKey;
  final List<String> _activeTempFiles = [];
  final Map<String, VaultItemMetadata> _manifest = {};

  List<VaultItemMetadata> get vaultMetadata => _manifest.values.toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  /// Derives a 256-bit key from a PIN and 16-byte salt using iterated HMAC-SHA256 (PBKDF2-HMAC-SHA256).
  static Uint8List deriveKeyFromPin(String pin, List<int> saltBytes) {
    final pinBytes = utf8.encode(pin);
    final hmac = Hmac(sha256, pinBytes);
    List<int> block = List<int>.from(saltBytes)..addAll([0, 0, 0, 1]);
    List<int> u = hmac.convert(block).bytes;
    final Uint8List out = Uint8List.fromList(u);

    for (int i = 1; i < _pbkdf2Iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _autoLockOnExit = prefs.getBool('vault_auto_lock') ?? true;

    String? keyBase64 = prefs.getString('vault_master_key');
    if (keyBase64 == null) {
      final secureRandomKey = enc.Key.fromSecureRandom(32);
      await prefs.setString('vault_master_key', secureRandomKey.base64);
      _masterKey = secureRandomKey;
    } else {
      _masterKey = enc.Key.fromBase64(keyBase64);
    }

    // Migrate legacy plaintext PIN if present
    final legacyPlainPin = prefs.getString('vault_pin');
    if (legacyPlainPin != null && prefs.getString('vault_pin_hash') == null) {
      await _storeSaltedPin(prefs, legacyPlainPin);
      await prefs.remove('vault_pin');
    }

    await _cleanupOrphanedMigrationFiles();
    if (_isUnlocked) {
      await _loadEncryptedManifest();
    }
  }

  Future<void> _storeSaltedPin(SharedPreferences prefs, String pin) async {
    final salt = enc.IV.fromSecureRandom(16).bytes;
    final derived = deriveKeyFromPin(pin, salt);
    final verifierHash = sha256.convert(derived).toString();
    await prefs.setString('vault_pin_salt', base64Encode(salt));
    await prefs.setString('vault_pin_hash', verifierHash);
  }

  Future<bool> verifyPin(String pin) async {
    if (isLockedOut) return false;

    final prefs = await SharedPreferences.getInstance();
    final saltB64 = prefs.getString('vault_pin_salt');
    final expectedHash = prefs.getString('vault_pin_hash');

    if (saltB64 == null || expectedHash == null) {
      return false;
    }

    final salt = base64Decode(saltB64);
    final derived = deriveKeyFromPin(pin, salt);
    final actualHash = sha256.convert(derived).toString();

    if (actualHash == expectedHash) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      _isUnlocked = true;
      await _loadEncryptedManifest();
      notifyListeners();
      return true;
    } else {
      _failedAttempts++;
      if (_failedAttempts >= _maxFailedAttempts) {
        _lockoutUntil = DateTime.now().add(_lockoutDuration);
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    await _storeSaltedPin(prefs, pin);
    _failedAttempts = 0;
    _lockoutUntil = null;
    _isUnlocked = true;
    await _loadEncryptedManifest();
    notifyListeners();
  }

  Future<void> setAutoLock(bool enabled) async {
    _autoLockOnExit = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vault_auto_lock', enabled);
    notifyListeners();
  }

  Future<bool> authenticate(BuildContext context) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final hasPin = prefs.getString('vault_pin_hash') != null;

    if (!context.mounted) return false;

    if (isLockedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vault temporarily locked due to failed attempts. Try again in ${remainingLockoutSeconds}s.',
          ),
          backgroundColor: EDesign.danger,
        ),
      );
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: EDesign.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EDesign.r18),
            side: const BorderSide(color: EDesign.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.shield_outlined, color: EDesign.primary),
              const SizedBox(width: 10),
              Text(
                hasPin ? 'Unlock Private Vault' : 'Create Vault PIN',
                style: EDesign.h3,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasPin
                    ? 'Enter your 4-digit PIN (PBKDF2-SHA256 verified) to unlock AES-256-GCM media.'
                    : 'Set a 4-digit PIN to initialize salted PBKDF2 + AES-256-GCM vault protection.',
                style: EDesign.secondaryStyle,
              ),
              if (_failedAttempts > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Failed attempts: $_failedAttempts / $_maxFailedAttempts',
                  style: const TextStyle(color: EDesign.warning, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 20,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: const TextStyle(color: EDesign.textMuted),
                  filled: true,
                  fillColor: EDesign.elevatedBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(EDesign.r10),
                    borderSide: const BorderSide(color: EDesign.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(EDesign.r10),
                    borderSide: const BorderSide(color: EDesign.primary),
                  ),
                ),
                maxLength: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: EDesign.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: EDesign.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EDesign.r10),
                ),
              ),
              onPressed: () async {
                final pin = controller.text.trim();
                if (pin.length != 4) return;

                if (!hasPin) {
                  await setPin(pin);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } else {
                  final ok = await verifyPin(pin);
                  if (ok) {
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } else {
                    if (ctx.mounted) {
                      final msg = isLockedOut
                          ? 'Too many failed attempts. Vault locked for 30s.'
                          : 'Incorrect Vault PIN';
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: EDesign.danger,
                        ),
                      );
                      Navigator.pop(ctx, false);
                    }
                  }
                }
              },
              child: Text(
                hasPin ? 'Unlock' : 'Save PIN',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> lock() async {
    _isUnlocked = false;
    await cleanupTempFiles();
    notifyListeners();
  }

  Future<void> cleanupTempFiles() async {
    for (final path in List<String>.from(_activeTempFiles)) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
    _activeTempFiles.clear();
  }

  Future<Directory> getVaultDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(docDir.path, '.eplayer_vault'));
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    return vaultDir;
  }

  Future<File> _getManifestFile() async {
    final vaultDir = await getVaultDirectory();
    return File(p.join(vaultDir.path, 'vault_manifest.meta'));
  }

  Future<void> _loadEncryptedManifest() async {
    if (_masterKey == null) return;
    final manifestFile = await _getManifestFile();
    if (!await manifestFile.exists()) return;

    try {
      final rawBytes = await manifestFile.readAsBytes();
      if (rawBytes.length < 13) return;
      final ivLen = rawBytes[0];
      if (rawBytes.length < 1 + ivLen + 1) return;
      final iv = enc.IV(Uint8List.fromList(rawBytes.sublist(1, 1 + ivLen)));
      final cipherBytes = Uint8List.fromList(rawBytes.sublist(1 + ivLen));

      final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
      final decryptedBytes = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
      final jsonStr = utf8.decode(decryptedBytes);
      final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;

      _manifest.clear();
      for (final entry in decoded) {
        final meta = VaultItemMetadata.fromJson(entry as Map<String, dynamic>);
        _manifest[meta.encryptedFileName] = meta;
      }
    } catch (e) {
      debugPrint('[E-Player Vault] Manifest decryption warning: $e');
    }
  }

  Future<void> _saveEncryptedManifest() async {
    if (_masterKey == null) return;
    final manifestFile = await _getManifestFile();
    final tempManifest = File('${manifestFile.path}.tmp');

    final jsonStr = jsonEncode(_manifest.values.map((m) => m.toJson()).toList());
    final plainBytes = utf8.encode(jsonStr);
    final iv = enc.IV.fromSecureRandom(12);
    final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    final builder = BytesBuilder();
    builder.addByte(iv.bytes.length);
    builder.add(iv.bytes);
    builder.add(encrypted.bytes);

    await tempManifest.writeAsBytes(builder.toBytes(), flush: true);
    await tempManifest.rename(manifestFile.path);
  }

  Future<void> _cleanupOrphanedMigrationFiles() async {
    try {
      final vaultDir = await getVaultDirectory();
      await for (final entity in vaultDir.list()) {
        if (entity is File && entity.path.endsWith('.tmp')) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  Future<String?> importFileToVault() async {
    final result = await FilePicker.pickFile(type: FileType.any);
    if (result == null || result.path == null) return null;
    final file = File(result.path!);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    final mediaItem = MediaItem(
      path: file.path,
      name: p.basename(file.path),
      parentFolder: file.parent.path,
      sizeBytes: stat.size,
      lastPlayed: DateTime.now(),
    );
    return await moveToVault(mediaItem);
  }

  /// Phase 8.2–8.4: Crash-safe authenticated chunked AES-256-GCM encryption
  Future<String> moveToVault(MediaItem item) async {
    if (_masterKey == null) await initialize();
    if (!_isUnlocked) throw Exception("Vault is locked");

    final sourceFile = File(item.path);
    if (!await sourceFile.exists()) {
      throw Exception("Source file does not exist: ${item.path}");
    }

    final vaultDir = await getVaultDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeBaseName = p.basename(item.path);
    final encryptedFileName = '${timestamp}_$safeBaseName.enc';
    final String destPath = p.join(vaultDir.path, encryptedFileName);
    final String tempDestPath = '$destPath.tmp';
    final tempDestFile = File(tempDestPath);

    final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
    final destSink = tempDestFile.openWrite();
    final raf = await sourceFile.open(mode: FileMode.read);

    int chunkCount = 0;
    int totalPlainBytes = 0;
    final hashChunks = <int>[];

    try {
      // Write 4-byte EPV3 magic header so format version is explicit
      destSink.add(_magicHeader);

      while (true) {
        final bytes = await raf.read(_chunkSize);
        if (bytes.isEmpty) break;

        totalPlainBytes += bytes.length;
        // Accumulate rolling digest input (bounded by hashing each chunk digest)
        hashChunks.addAll(sha256.convert(bytes).bytes);

        final iv = enc.IV.fromSecureRandom(12);
        final encrypted = encrypter.encryptBytes(bytes, iv: iv);

        destSink.add([iv.bytes.length]);
        destSink.add(iv.bytes);

        final cipherLength = encrypted.bytes.length;
        final lengthBytes = Uint8List(4)
          ..buffer.asByteData().setUint32(0, cipherLength, Endian.little);
        destSink.add(lengthBytes);

        destSink.add(encrypted.bytes);
        chunkCount++;
      }

      await destSink.flush();
      await destSink.close();
      await raf.close();

      // Atomic commit from .enc.tmp -> .enc before deleting plaintext source
      await tempDestFile.rename(destPath);

      final overallHash = sha256.convert(hashChunks).toString();
      final meta = VaultItemMetadata(
        id: '$timestamp',
        encryptedFileName: encryptedFileName,
        originalName: safeBaseName,
        originalDir: item.parentFolder.isNotEmpty
            ? item.parentFolder
            : p.dirname(item.path),
        sizeBytes: totalPlainBytes,
        addedAt: DateTime.now(),
        sha256PlaintextHash: overallHash,
        chunkCount: chunkCount,
      );
      _manifest[encryptedFileName] = meta;
      await _saveEncryptedManifest();

      // Delete plaintext file ONLY after encrypted vault file and manifest are committed
      if (await File(destPath).exists() && await sourceFile.exists()) {
        await sourceFile.delete();
      }
    } catch (e) {
      try {
        await raf.close();
      } catch (_) {}
      try {
        await destSink.close();
      } catch (_) {}
      if (await tempDestFile.exists()) {
        await tempDestFile.delete();
      }
      rethrow;
    }

    notifyListeners();
    return destPath;
  }

  /// Phase 8.4 & 8.7: Authenticated streaming decryption with tamper & corruption detection
  Future<void> _decryptStreamToFile(
    File sourceEncryptedFile,
    File targetPlainFile, {
    VaultItemMetadata? expectedMeta,
  }) async {
    final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
    final tempOutFile = File('${targetPlainFile.path}.dec.tmp');
    if (await tempOutFile.exists()) await tempOutFile.delete();

    final destSink = tempOutFile.openWrite();
    final raf = await sourceEncryptedFile.open(mode: FileMode.read);
    final hashChunks = <int>[];
    int chunksRead = 0;

    try {
      final fileLen = await raf.length();
      if (fileLen == 0) {
        throw const VaultTamperException('Encrypted vault file is empty or truncated.');
      }

      // Check for optional 4-byte "EPV3" magic header (backward compatible with legacy .enc files)
      final firstFour = await raf.read(4);
      final hasMagic = firstFour.length == 4 &&
          firstFour[0] == _magicHeader[0] &&
          firstFour[1] == _magicHeader[1] &&
          firstFour[2] == _magicHeader[2] &&
          firstFour[3] == _magicHeader[3];
      if (!hasMagic) {
        await raf.setPosition(0);
      }

      while (true) {
        final ivLenBytes = await raf.read(1);
        if (ivLenBytes.isEmpty) break;

        final ivLen = ivLenBytes[0];
        if (ivLen <= 0 || ivLen > 32) {
          throw const VaultTamperException('Corrupted chunk IV length header.');
        }

        final ivBytes = await raf.read(ivLen);
        if (ivBytes.length != ivLen) {
          throw const VaultTamperException('Truncated chunk IV in vault file.');
        }
        final iv = enc.IV(Uint8List.fromList(ivBytes));

        final lenBytes = await raf.read(4);
        if (lenBytes.length != 4) {
          throw const VaultTamperException('Truncated chunk length header in vault file.');
        }
        final cipherLen =
            Uint8List.fromList(lenBytes).buffer.asByteData().getUint32(0, Endian.little);
        if (cipherLen <= 0 || cipherLen > _chunkSize + 1024) {
          throw const VaultTamperException('Invalid chunk payload size detected.');
        }

        final cipherBytes = await raf.read(cipherLen);
        if (cipherBytes.length != cipherLen) {
          throw const VaultTamperException('Truncated encrypted payload chunk.');
        }

        final encrypted = enc.Encrypted(Uint8List.fromList(cipherBytes));
        late final List<int> decrypted;
        try {
          decrypted = encrypter.decryptBytes(encrypted, iv: iv);
        } catch (authErr) {
          throw VaultTamperException(
            'AES-GCM authentication tag mismatch on chunk $chunksRead: $authErr',
          );
        }

        hashChunks.addAll(sha256.convert(decrypted).bytes);
        destSink.add(decrypted);
        chunksRead++;
      }

      await destSink.flush();
      await destSink.close();
      await raf.close();

      if (expectedMeta != null && expectedMeta.sha256PlaintextHash.isNotEmpty) {
        final actualHash = sha256.convert(hashChunks).toString();
        if (actualHash != expectedMeta.sha256PlaintextHash) {
          throw const VaultTamperException(
            'Plaintext SHA-256 integrity hash mismatch after decryption.',
          );
        }
      }

      if (await targetPlainFile.exists()) {
        await targetPlainFile.delete();
      }
      await tempOutFile.rename(targetPlainFile.path);
    } catch (e) {
      try {
        await raf.close();
      } catch (_) {}
      try {
        await destSink.close();
      } catch (_) {}
      if (await tempOutFile.exists()) {
        await tempOutFile.delete();
      }
      if (e is VaultTamperException) rethrow;
      throw VaultTamperException('Failed to decrypt vault stream: $e');
    }
  }

  Future<String> restoreFromVault(
    String encryptedPath,
    String originalDir,
    String originalName,
  ) async {
    if (_masterKey == null) await initialize();
    if (!_isUnlocked) throw Exception("Vault is locked");

    final sourceFile = File(encryptedPath);
    final encFileName = p.basename(encryptedPath);
    final meta = _manifest[encFileName];

    final resolvedDir =
        originalDir.isNotEmpty ? originalDir : (meta?.originalDir ?? '');
    final resolvedName =
        originalName.isNotEmpty ? originalName : (meta?.originalName ?? 'restored.mp4');

    final targetDir = Directory(resolvedDir);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final String destPath = p.join(resolvedDir, resolvedName);
    final destFile = File(destPath);

    await _decryptStreamToFile(sourceFile, destFile, expectedMeta: meta);

    if (await destFile.exists() && await sourceFile.exists()) {
      await sourceFile.delete();
      _manifest.remove(encFileName);
      await _saveEncryptedManifest();
    }

    notifyListeners();
    return destPath;
  }

  Future<void> deleteVaultFile(File encryptedFile) async {
    final encFileName = p.basename(encryptedFile.path);
    if (await encryptedFile.exists()) {
      await encryptedFile.delete();
    }
    _manifest.remove(encFileName);
    await _saveEncryptedManifest();
    notifyListeners();
  }

  Future<List<File>> getVaultItems() async {
    if (!_isUnlocked) return [];
    final vaultDir = await getVaultDirectory();
    final List<FileSystemEntity> entities = await vaultDir.list().toList();
    final files = entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.enc'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<String> decryptToTemp(File encryptedFile) async {
    if (_masterKey == null) await initialize();
    if (!_isUnlocked) throw Exception("Vault is locked");

    final tempDir = await getTemporaryDirectory();
    final encFileName = p.basename(encryptedFile.path);
    final meta = _manifest[encFileName];

    final baseName = encFileName.replaceAll('.enc', '');
    final nameParts = baseName.split('_');
    final originalName = meta?.originalName ??
        (nameParts.length > 1 ? nameParts.sublist(1).join('_') : 'vault_media.mp4');

    final String destPath = p.join(tempDir.path, originalName);
    final destFile = File(destPath);

    await _decryptStreamToFile(encryptedFile, destFile, expectedMeta: meta);

    if (!_activeTempFiles.contains(destPath)) {
      _activeTempFiles.add(destPath);
    }
    return destPath;
  }
}
