import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/models/media_item.dart';

class VaultService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();
  
  bool _isUnlocked = false;
  bool get isUnlocked => _isUnlocked;
  
  enc.Key? _masterKey;

  Future<void> initialize() async {
    String? keyBase64 = await _storage.read(key: 'vault_master_key');
    if (keyBase64 == null) {
      final secureRandomKey = enc.Key.fromSecureRandom(32);
      await _storage.write(key: 'vault_master_key', value: secureRandomKey.base64);
      _masterKey = secureRandomKey;
    } else {
      _masterKey = enc.Key.fromBase64(keyBase64);
    }
  }

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        _isUnlocked = true;
        notifyListeners();
        return true;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access your private vault',
      );

      if (didAuthenticate) {
        _isUnlocked = true;
        notifyListeners();
      }
      return didAuthenticate;
    } catch (e) {
      debugPrint('Biometric error: $e');
      return false;
    }
  }

  void lock() {
    _isUnlocked = false;
    notifyListeners();
  }

  Future<Directory> getVaultDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(docDir.path, '.eplayer_vault'));
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    return vaultDir;
  }

  /// Encrypts file in 1MB chunks using AES-GCM. 
  /// Format per chunk: [Ciphertext(ChunkSize)]
  /// We generate a random IV per chunk to guarantee nonce uniqueness.
  Future<String> moveToVault(MediaItem item) async {
    if (_masterKey == null) await initialize();
    if (!_isUnlocked) throw Exception("Vault is locked");

    final sourceFile = File(item.path);
    final vaultDir = await getVaultDirectory();
    final String destPath = p.join(vaultDir.path, '${DateTime.now().millisecondsSinceEpoch}_${p.basename(item.path)}.enc');
    final destFile = File(destPath);

    final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
    final destSink = destFile.openWrite();

    // 1MB chunks
    const chunkSize = 1024 * 1024;
    final raf = await sourceFile.open(mode: FileMode.read);
    
    try {
      while (true) {
        final bytes = await raf.read(chunkSize);
        if (bytes.isEmpty) break;
        
        // Generate a 12-byte IV for GCM
        final iv = enc.IV.fromSecureRandom(12);
        final encrypted = encrypter.encryptBytes(bytes, iv: iv);
        
        // Write IV length (1 byte), IV (12 bytes), Ciphertext length (4 bytes), Ciphertext
        destSink.add([iv.bytes.length]);
        destSink.add(iv.bytes);
        
        final cipherLength = encrypted.bytes.length;
        final lengthBytes = Uint8List(4)..buffer.asByteData().setUint32(0, cipherLength, Endian.little);
        destSink.add(lengthBytes);
        
        destSink.add(encrypted.bytes);
      }
    } finally {
      await raf.close();
      await destSink.close();
      await sourceFile.delete(); // Delete original after secure encryption
    }
    
    return destPath;
  }

  /// Decrypts file back to original location
  Future<String> restoreFromVault(String encryptedPath, String originalDir, String originalName) async {
    if (_masterKey == null) await initialize();
    if (!_isUnlocked) throw Exception("Vault is locked");

    final sourceFile = File(encryptedPath);
    final String destPath = p.join(originalDir, originalName);
    final destFile = File(destPath);

    final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
    final destSink = destFile.openWrite();
    final raf = await sourceFile.open(mode: FileMode.read);

    try {
      while (true) {
        final ivLenBytes = await raf.read(1);
        if (ivLenBytes.isEmpty) break; // EOF
        
        final ivLen = ivLenBytes[0];
        final ivBytes = await raf.read(ivLen);
        final iv = enc.IV(Uint8List.fromList(ivBytes));
        
        final lenBytes = await raf.read(4);
        final cipherLen = Uint8List.fromList(lenBytes).buffer.asByteData().getUint32(0, Endian.little);
        
        final cipherBytes = await raf.read(cipherLen);
        final encrypted = enc.Encrypted(Uint8List.fromList(cipherBytes));
        
        final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
        destSink.add(decrypted);
      }
    } finally {
      await raf.close();
      await destSink.close();
      await sourceFile.delete();
    }
    
    return destPath;
  }

  /// Lists all files currently in the vault
  Future<List<File>> getVaultItems() async {
    if (!_isUnlocked) return [];
    final vaultDir = await getVaultDirectory();
    final List<FileSystemEntity> entities = await vaultDir.list().toList();
    return entities.whereType<File>().where((f) => f.path.endsWith('.enc')).toList();
  }

  /// Decrypts a vault file to a temporary directory for playback
  Future<String> decryptToTemp(File encryptedFile) async {
    if (_masterKey == null) await initialize();
    if (!_isUnlocked) throw Exception("Vault is locked");

    final tempDir = await getTemporaryDirectory();
    // Extract original name from format: timestamp_originalName.enc
    final baseName = p.basename(encryptedFile.path).replaceAll('.enc', '');
    final nameParts = baseName.split('_');
    final originalName = nameParts.length > 1 ? nameParts.sublist(1).join('_') : 'vault_media.mp4';
    
    final String destPath = p.join(tempDir.path, originalName);
    final destFile = File(destPath);
    
    // If temp file exists, clear it
    if (await destFile.exists()) await destFile.delete();

    final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
    final destSink = destFile.openWrite();
    final raf = await encryptedFile.open(mode: FileMode.read);

    try {
      while (true) {
        final ivLenBytes = await raf.read(1);
        if (ivLenBytes.isEmpty) break; // EOF
        
        final ivLen = ivLenBytes[0];
        final ivBytes = await raf.read(ivLen);
        final iv = enc.IV(Uint8List.fromList(ivBytes));
        
        final lenBytes = await raf.read(4);
        final cipherLen = Uint8List.fromList(lenBytes).buffer.asByteData().getUint32(0, Endian.little);
        
        final cipherBytes = await raf.read(cipherLen);
        final encrypted = enc.Encrypted(Uint8List.fromList(cipherBytes));
        
        final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
        destSink.add(decrypted);
      }
    } finally {
      await raf.close();
      await destSink.close();
    }
    
    return destPath;
  }
}
