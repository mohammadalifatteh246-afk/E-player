import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/models/media_item.dart';

class VaultService extends ChangeNotifier {
  bool _isUnlocked = false;
  bool get isUnlocked => _isUnlocked;
  
  enc.Key? _masterKey;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    String? keyBase64 = prefs.getString('vault_master_key');
    if (keyBase64 == null) {
      final secureRandomKey = enc.Key.fromSecureRandom(32);
      await prefs.setString('vault_master_key', secureRandomKey.base64);
      _masterKey = secureRandomKey;
    } else {
      _masterKey = enc.Key.fromBase64(keyBase64);
    }
  }

  Future<bool> authenticate(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasPin = prefs.getString('vault_pin') != null;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(hasPin ? 'Enter Vault PIN' : 'Set New Vault PIN'),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Enter 4-digit PIN'),
            maxLength: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = controller.text;
                if (pin.length != 4) return;
                
                if (!hasPin) {
                  await prefs.setString('vault_pin', pin);
                  Navigator.pop(ctx, true);
                } else {
                  final savedPin = prefs.getString('vault_pin');
                  if (pin == savedPin) {
                    Navigator.pop(ctx, true);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
                    Navigator.pop(ctx, false);
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _isUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
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

  Future<String> moveToVault(MediaItem item) async {
    if (_masterKey == null) await initialize();
    if (!_isUnlocked) throw Exception("Vault is locked");

    final sourceFile = File(item.path);
    final vaultDir = await getVaultDirectory();
    final String destPath = p.join(vaultDir.path, '\_\.enc');
    final destFile = File(destPath);

    final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
    final destSink = destFile.openWrite();

    const chunkSize = 1024 * 1024;
    final raf = await sourceFile.open(mode: FileMode.read);
    
    try {
      while (true) {
        final bytes = await raf.read(chunkSize);
        if (bytes.isEmpty) break;
        
        final iv = enc.IV.fromSecureRandom(12);
        final encrypted = encrypter.encryptBytes(bytes, iv: iv);
        
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
      await sourceFile.delete(); 
    }
    
    return destPath;
  }

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
        if (ivLenBytes.isEmpty) break; 
        
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

  Future<List<File>> getVaultItems() async {
    if (!_isUnlocked) return [];
    final vaultDir = await getVaultDirectory();
    final List<FileSystemEntity> entities = await vaultDir.list().toList();
    return entities.whereType<File>().where((f) => f.path.endsWith('.enc')).toList();
  }

  Future<String> decryptToTemp(File encryptedFile) async {
    if (_masterKey == null) await initialize();
    if (!_isUnlocked) throw Exception("Vault is locked");

    final tempDir = await getTemporaryDirectory();
    final baseName = p.basename(encryptedFile.path).replaceAll('.enc', '');
    final nameParts = baseName.split('_');
    final originalName = nameParts.length > 1 ? nameParts.sublist(1).join('_') : 'vault_media.mp4';
    
    final String destPath = p.join(tempDir.path, originalName);
    final destFile = File(destPath);
    
    if (await destFile.exists()) await destFile.delete();

    final encrypter = enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.gcm));
    final destSink = destFile.openWrite();
    final raf = await encryptedFile.open(mode: FileMode.read);

    try {
      while (true) {
        final ivLenBytes = await raf.read(1);
        if (ivLenBytes.isEmpty) break; 
        
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
