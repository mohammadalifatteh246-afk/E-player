import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/media_item.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../library/domain/drive_scanner_models.dart';
import '../../library/domain/media_scanner_service.dart';
import 'vault_keystore.dart';

export 'vault_keystore.dart';

typedef VaultDirProvider = Future<Directory> Function();
typedef ExternalDriveRootsProvider = List<String> Function();

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
  static const String _keystoreFileName = 'vault_keystore.json';
  static const String _vaultFolderName = '.eplayer_vault';
  static const String _stagingSubfolder = '.tmp_play';

  static const String _prefActiveVaultDir = 'vault_active_directory';
  static const String _prefCustomVaultDirs = 'vault_custom_directories';
  static const String _prefDecryptCacheOnVaultDrive = 'vault_decrypt_cache_on_drive';

  final VaultDirProvider? _internalVaultDirProvider;
  final ExternalDriveRootsProvider _externalDriveRootsProvider;

  String? _activeVaultDirPath;
  final List<String> _customVaultPaths = [];
  bool _decryptCacheOnVaultDrive = true;
  bool get decryptCacheOnVaultDrive => _decryptCacheOnVaultDrive;

  String? get activeVaultPath => _activeVaultDirPath;

  bool _isUnlocked = false;
  bool get isUnlocked => _isUnlocked;

  bool _isDecoyMode = false;
  bool get isDecoyMode => _isDecoyMode;
  static const String defaultDecoyPin = '0000';

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
  VaultKeyEnvelope? _currentEnvelope;
  String? _sessionRecoveryKey;
  String? _activeUnlockedPin;
  final List<String> _activeTempFiles = [];
  final Map<String, VaultItemMetadata> _manifest = {};

  VaultService({
    String? initialVaultDirOverride,
    VaultDirProvider? internalVaultDirProvider,
    ExternalDriveRootsProvider? externalDriveRootsProvider,
  })  : _activeVaultDirPath = initialVaultDirOverride,
        // ignore: prefer_initializing_formals
        _internalVaultDirProvider = internalVaultDirProvider,
        _externalDriveRootsProvider =
            externalDriveRootsProvider ?? MediaScannerService.getAvailableDrives;

  @visibleForTesting
  static enc.Key createMasterKeyForTesting(Uint8List raw32Bytes) =>
      enc.Key(raw32Bytes);

  bool get hasKeystoreEnvelope => _currentEnvelope != null;
  String? get currentRecoveryKeyHint => _currentEnvelope?.recoverySlot?.hint;
  String? get sessionRecoveryKey => _sessionRecoveryKey;

  List<VaultItemMetadata> get vaultMetadata => _manifest.values.toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  /// Derives a 256-bit key from a PIN and 16-byte salt using iterated HMAC-SHA256 (PBKDF2-HMAC-SHA256).
  static Uint8List deriveKeyFromPin(String pin, List<int> saltBytes) {
    return VaultKeystoreCrypto.deriveKek(
      pin,
      saltBytes,
      iterations: _pbkdf2Iterations,
    );
  }

  Future<Directory> _getInternalVaultDirectory() async {
    if (_internalVaultDirProvider != null) {
      return await _internalVaultDirProvider();
    }
    final docDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(docDir.path, _vaultFolderName));
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _autoLockOnExit = prefs.getBool('vault_auto_lock') ?? true;
    _decryptCacheOnVaultDrive =
        prefs.getBool(_prefDecryptCacheOnVaultDrive) ?? true;

    final savedCustom = prefs.getStringList(_prefCustomVaultDirs);
    if (savedCustom != null) {
      for (final path in savedCustom) {
        if (path.trim().isNotEmpty && !_customVaultPaths.contains(path)) {
          _customVaultPaths.add(path);
        }
      }
    }

    if (_activeVaultDirPath == null || _activeVaultDirPath!.trim().isEmpty) {
      final savedActive = prefs.getString(_prefActiveVaultDir);
      if (savedActive != null && savedActive.trim().isNotEmpty) {
        _activeVaultDirPath = savedActive.trim();
      } else {
        final internalDir = await _getInternalVaultDirectory();
        _activeVaultDirPath = internalDir.path;
      }
    }

    // Load self-contained portable envelope if it exists inside active vault directory
    _currentEnvelope = await _readKeyEnvelopeFromDisk();

    if (_currentEnvelope == null) {
      // Legacy compatibility path when vault_keystore.json hasn't been created yet
      String? keyBase64 = prefs.getString('vault_master_key');
      if (keyBase64 == null) {
        final secureRandomKey = enc.Key.fromSecureRandom(32);
        await prefs.setString('vault_master_key', secureRandomKey.base64);
        _masterKey = secureRandomKey;
      } else {
        _masterKey = enc.Key.fromBase64(keyBase64);
      }
    }

    // Migrate legacy plaintext PIN if present
    final legacyPlainPin = prefs.getString('vault_pin');
    if (legacyPlainPin != null && prefs.getString('vault_pin_hash') == null) {
      await _storeSaltedPin(prefs, legacyPlainPin);
      await prefs.remove('vault_pin');
    }

    await _cleanupOrphanedMigrationFiles();
    if (_isUnlocked && !_isDecoyMode && _masterKey != null) {
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

  Future<VaultKeyEnvelope?> _readKeyEnvelopeFromDisk([String? dirOverride]) async {
    try {
      final dir = dirOverride != null
          ? Directory(dirOverride)
          : await getVaultDirectory(createIfMissing: false);
      final ksFile = File(p.join(dir.path, _keystoreFileName));
      if (!await ksFile.exists()) return null;
      final decoded = jsonDecode(await ksFile.readAsString());
      if (decoded is Map<String, dynamic>) {
        return VaultKeyEnvelope.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[E-Player Vault] Failed to read keystore envelope: $e');
    }
    return null;
  }

  Future<void> _writeKeyEnvelopeToDisk(VaultKeyEnvelope envelope) async {
    final dir = await getVaultDirectory();
    final ksFile = File(p.join(dir.path, _keystoreFileName));
    final tmpFile = File('${ksFile.path}.tmp');
    await tmpFile.writeAsString(jsonEncode(envelope.toJson()), flush: true);
    if (await ksFile.exists()) {
      await ksFile.delete();
    }
    await tmpFile.rename(ksFile.path);
    _currentEnvelope = envelope;
  }

  Future<void> _ensureKeystoreSavedForPin(String pin) async {
    if (_masterKey == null) return;
    final existing = _currentEnvelope ?? await _readKeyEnvelopeFromDisk();
    final pinSlot = VaultKeystoreCrypto.wrapMasterKey(
      masterKey: _masterKey!,
      secret: pin,
      iterations: _pbkdf2Iterations,
    );

    WrappedKeySlot? recoverySlot = existing?.recoverySlot;
    if (recoverySlot == null) {
      final freshRecovery = VaultKeystoreCrypto.generateRecoveryKey();
      _sessionRecoveryKey = freshRecovery;
      recoverySlot = VaultKeystoreCrypto.wrapMasterKey(
        masterKey: _masterKey!,
        secret: VaultKeystoreCrypto.normalizeRecoveryInput(freshRecovery),
        iterations: _pbkdf2Iterations,
        hint: VaultKeystoreCrypto.buildSafeHint(freshRecovery),
      );
    }

    final updated = VaultKeyEnvelope(
      version: 2,
      vaultId: existing?.vaultId.isNotEmpty == true
          ? existing!.vaultId
          : 'vault_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: existing?.createdAt ?? DateTime.now(),
      pinSlot: pinSlot,
      recoverySlot: recoverySlot,
    );
    await _writeKeyEnvelopeToDisk(updated);
  }

  /// Returns an active recovery key in session if present, or generates & seals a fresh recovery slot.
  Future<String> generateOrGetRecoveryKey({bool forceRegenerate = false}) async {
    if (_masterKey == null || !_isUnlocked) {
      throw Exception('Vault must be unlocked to view or rotate Recovery Key.');
    }
    if (!forceRegenerate && _sessionRecoveryKey != null) {
      return _sessionRecoveryKey!;
    }
    final newKey = VaultKeystoreCrypto.generateRecoveryKey();
    _sessionRecoveryKey = newKey;
    final recoverySlot = VaultKeystoreCrypto.wrapMasterKey(
      masterKey: _masterKey!,
      secret: VaultKeystoreCrypto.normalizeRecoveryInput(newKey),
      iterations: _pbkdf2Iterations,
      hint: VaultKeystoreCrypto.buildSafeHint(newKey),
    );
    final existing = _currentEnvelope ?? await _readKeyEnvelopeFromDisk();
    final updated = (existing ??
            VaultKeyEnvelope(
              vaultId: 'vault_${DateTime.now().millisecondsSinceEpoch}',
              createdAt: DateTime.now(),
            ))
        .copyWith(recoverySlot: recoverySlot);
    await _writeKeyEnvelopeToDisk(updated);
    notifyListeners();
    return newKey;
  }

  /// Exports a portable `.epvkey` JSON backup containing the wrapped envelope and vault metadata.
  Future<String> exportPortableKeyBackup(String targetDirectoryPath,
      {String? explicitRecoveryKey}) async {
    if (_masterKey == null || !_isUnlocked) {
      throw Exception('Unlock Vault before exporting portable backup.');
    }
    if (_currentEnvelope == null) {
      final recoveryKey = await generateOrGetRecoveryKey();
      explicitRecoveryKey ??= recoveryKey;
    }
    final dir = Directory(targetDirectoryPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    final outFile = File(p.join(
      dir.path,
      'eplayer_vault_backup_${DateTime.now().millisecondsSinceEpoch}.epvkey',
    ));
    final payload = {
      'app': 'E-Player Vault',
      'exportedAt': DateTime.now().toIso8601String(),
      'vaultPath': activeVaultPath,
      'envelope': _currentEnvelope?.toJson(),
      'recoveryKey': ?explicitRecoveryKey,
    };
    await outFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return outFile.path;
  }

  /// Recovers a portable vault using its emergency [recoveryKey] (even after uninstall or forgotten PIN)
  /// and assigns a [newPin] directly in `vault_keystore.json` without re-encrypting media files.
  Future<bool> recoverWithRecoveryKey({
    required String recoveryKey,
    required String newPin,
  }) async {
    if (isLockedOut) return false;
    final cleanPin = newPin.trim();
    if (cleanPin.length != 4) return false;

    await initialize();
    final envelope = _currentEnvelope ?? await _readKeyEnvelopeFromDisk();
    final slot = envelope?.recoverySlot;
    if (slot == null) {
      return false;
    }

    final normalizedSecret =
        VaultKeystoreCrypto.normalizeRecoveryInput(recoveryKey);
    final unwrapped = VaultKeystoreCrypto.unwrapMasterKey(
      slot: slot,
      secret: normalizedSecret,
    );

    if (unwrapped == null) {
      _failedAttempts++;
      if (_failedAttempts >= _maxFailedAttempts) {
        _lockoutUntil = DateTime.now().add(_lockoutDuration);
      }
      notifyListeners();
      return false;
    }

    _masterKey = unwrapped;
    _activeUnlockedPin = cleanPin;
    _failedAttempts = 0;
    _lockoutUntil = null;
    _isUnlocked = true;
    _isDecoyMode = false;

    final updatedPinSlot = VaultKeystoreCrypto.wrapMasterKey(
      masterKey: unwrapped,
      secret: cleanPin,
      iterations: _pbkdf2Iterations,
    );
    await _writeKeyEnvelopeToDisk(envelope!.copyWith(pinSlot: updatedPinSlot));

    final prefs = await SharedPreferences.getInstance();
    await _storeSaltedPin(prefs, cleanPin);
    await prefs.setString('vault_master_key', unwrapped.base64);

    await _loadEncryptedManifest();
    notifyListeners();
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    if (isLockedOut) return false;

    final prefs = await SharedPreferences.getInstance();
    final decoyPin = prefs.getString('vault_decoy_pin') ?? defaultDecoyPin;
    if (pin == decoyPin) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      _isUnlocked = true;
      _isDecoyMode = true;
      _manifest.clear();
      notifyListeners();
      return true;
    }

    if (_activeVaultDirPath == null) {
      await initialize();
    }

    // 1. Primary Recovery Path: Unwrap DEK directly from portable `vault_keystore.json`
    final envelope = _currentEnvelope ?? await _readKeyEnvelopeFromDisk();
    if (envelope?.pinSlot != null) {
      final unwrapped = VaultKeystoreCrypto.unwrapMasterKey(
        slot: envelope!.pinSlot!,
        secret: pin,
      );
      if (unwrapped != null) {
        _masterKey = unwrapped;
        _activeUnlockedPin = pin;
        _failedAttempts = 0;
        _lockoutUntil = null;
        _isUnlocked = true;
        _isDecoyMode = false;
        _currentEnvelope = envelope;

        // Refresh local SharedPreferences cache cleanly
        await _storeSaltedPin(prefs, pin);
        await prefs.setString('vault_master_key', unwrapped.base64);

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

    // 2. Legacy Fallback Path: Check SharedPreferences PIN hash & migrate to portable envelope
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
      _isDecoyMode = false;
      _activeUnlockedPin = pin;

      if (_masterKey == null) {
        final keyB64 = prefs.getString('vault_master_key');
        if (keyB64 != null) _masterKey = enc.Key.fromBase64(keyB64);
      }

      if (_masterKey != null) {
        await _ensureKeystoreSavedForPin(pin);
      }

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
    _masterKey ??= enc.Key.fromSecureRandom(32);
    final prefs = await SharedPreferences.getInstance();
    await _storeSaltedPin(prefs, pin);
    await prefs.setString('vault_master_key', _masterKey!.base64);

    await _ensureKeystoreSavedForPin(pin);

    _activeUnlockedPin = pin;
    _failedAttempts = 0;
    _lockoutUntil = null;
    _isUnlocked = true;
    _isDecoyMode = false;
    await _loadEncryptedManifest();
    notifyListeners();
  }

  Future<void> setAutoLock(bool enabled) async {
    _autoLockOnExit = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vault_auto_lock', enabled);
    notifyListeners();
  }

  Future<void> setDecryptCacheOnVaultDrive(bool enabled) async {
    _decryptCacheOnVaultDrive = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDecryptCacheOnVaultDrive, enabled);
    notifyListeners();
  }

  /// Discovers Internal Storage Vault + External Drives (`D:\`, `E:\`, SD Cards) + Custom Vault Folders.
  Future<List<VaultLocationInfo>> discoverVaultLocations() async {
    if (_activeVaultDirPath == null) {
      await initialize();
    }

    final results = <VaultLocationInfo>[];
    final seen = <String>{};

    Future<void> inspectAndAdd({
      required String dirPath,
      required String label,
      required VaultStorageType type,
    }) async {
      final norm = p.normalize(dirPath);
      final dedupKey = Platform.isWindows ? norm.toLowerCase() : norm;
      if (!seen.add(dedupKey)) return;

      final dir = Directory(norm);
      bool exists = false;
      bool hasKeystore = false;
      int encCount = 0;
      try {
        exists = await dir.exists();
        if (exists) {
          hasKeystore =
              await File(p.join(norm, _keystoreFileName)).exists();
          await for (final entity in dir.list(followLinks: false)) {
            if (entity is File && entity.path.endsWith('.enc')) {
              encCount++;
            }
          }
        }
      } catch (_) {}

      final activeNorm =
          _activeVaultDirPath != null ? p.normalize(_activeVaultDirPath!) : '';
      final isActive = Platform.isWindows
          ? activeNorm.toLowerCase() == norm.toLowerCase()
          : activeNorm == norm;

      results.add(
        VaultLocationInfo(
          directoryPath: norm,
          label: label,
          storageType: type,
          existsOnDisk: exists,
          hasKeystoreEnvelope: hasKeystore,
          encryptedFileCount: encCount,
          isActive: isActive,
        ),
      );
    }

    // 1. Default App Internal Vault
    final internalDir = await _getInternalVaultDirectory();
    await inspectAndAdd(
      dirPath: internalDir.path,
      label: 'Internal App Storage Vault',
      type: VaultStorageType.internalApp,
    );

    // 2. External Drives / SD Cards (`D:\`, `E:\`, Android `/storage/<SD-UUID>`, Shared `/storage/emulated/0`)
    final systemDrive = Platform.environment['SystemDrive'] ?? 'C:';
    final sysKey = DriveVolumeInfo.normalizeKey(systemDrive).toLowerCase();
    for (final rawRoot in _externalDriveRootsProvider()) {
      final rootKey = DriveVolumeInfo.normalizeKey(rawRoot).toLowerCase();
      // Skip system root drive default if it's C:\ unless a vault folder already sits directly at C:\.eplayer_vault
      final candidateVaultDir = p.join(rawRoot, _vaultFolderName);
      if (Platform.isWindows && rootKey == sysKey) {
        if (!Directory(candidateVaultDir).existsSync()) {
          continue;
        }
      }

      String label;
      if (Platform.isAndroid) {
        if (rawRoot == '/storage/emulated/0') {
          label = 'Shared Internal Storage (Uninstall-Safe)';
        } else {
          label = 'SD Card / USB (${p.basename(rawRoot)})';
        }
      } else {
        final pretty = DriveVolumeInfo.formatDriveLabel(
          rawRoot,
          systemDriveLetter: systemDrive,
        );
        label = '$pretty Vault';
      }

      await inspectAndAdd(
        dirPath: candidateVaultDir,
        label: label,
        type: VaultStorageType.externalDrive,
      );
    }

    // 3. Previously active / user-mounted custom vault directories
    for (final customPath in _customVaultPaths) {
      await inspectAndAdd(
        dirPath: customPath,
        label: 'Custom Vault (${p.basename(customPath)})',
        type: VaultStorageType.customFolder,
      );
    }
    if (_activeVaultDirPath != null) {
      await inspectAndAdd(
        dirPath: _activeVaultDirPath!,
        label: 'Active Vault (${p.basename(_activeVaultDirPath!)})',
        type: VaultStorageType.customFolder,
      );
    }

    return results;
  }

  /// Registers a custom directory (if user picked e.g. `D:\Movies` it uses `D:\Movies\.eplayer_vault`
  /// unless that directory already directly holds `vault_keystore.json` or `.enc` files).
  Future<String> mountCustomVaultFolder(
    String pickedDirectory, {
    String? autoPinIfUnlocked,
  }) async {
    var targetPath = pickedDirectory.trim();
    final hasKsDirect =
        await File(p.join(targetPath, _keystoreFileName)).exists();
    bool hasEncDirect = false;
    try {
      await for (final entity in Directory(targetPath).list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.enc')) {
          hasEncDirect = true;
          break;
        }
      }
    } catch (_) {}

    if (!hasKsDirect && !hasEncDirect && p.basename(targetPath) != _vaultFolderName) {
      targetPath = p.join(targetPath, _vaultFolderName);
    }

    final prefs = await SharedPreferences.getInstance();
    if (!_customVaultPaths.contains(targetPath)) {
      _customVaultPaths.add(targetPath);
      await prefs.setStringList(_prefCustomVaultDirs, _customVaultPaths);
    }

    await switchVaultLocation(
      targetPath,
      autoPinIfUnlocked: autoPinIfUnlocked ?? _activeUnlockedPin,
    );
    return targetPath;
  }

  /// Switches the active vault root directory cleanly (preserving files across drives).
  Future<void> switchVaultLocation(
    String newVaultDirectoryPath, {
    String? autoPinIfUnlocked,
  }) async {
    await cleanupTempFiles();
    _manifest.clear();
    _sessionRecoveryKey = null;
    _masterKey = null;
    _currentEnvelope = null;

    final cleanPath = p.normalize(newVaultDirectoryPath.trim());
    _activeVaultDirPath = cleanPath;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefActiveVaultDir, cleanPath);

    final targetDir = Directory(cleanPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    _currentEnvelope = await _readKeyEnvelopeFromDisk(cleanPath);
    final pinToTry = autoPinIfUnlocked ?? _activeUnlockedPin;

    if (_currentEnvelope?.pinSlot != null) {
      _isUnlocked = false;
      _isDecoyMode = false;
      if (pinToTry != null) {
        await verifyPin(pinToTry);
      } else {
        notifyListeners();
      }
      return;
    }

    // Target is a brand-new external vault location without a keystore yet:
    if (pinToTry != null) {
      _masterKey = enc.Key.fromSecureRandom(32);
      await prefs.setString('vault_master_key', _masterKey!.base64);
      await _storeSaltedPin(prefs, pinToTry);
      await _ensureKeystoreSavedForPin(pinToTry);
      _isUnlocked = true;
      _isDecoyMode = false;
      await _loadEncryptedManifest();
    } else {
      _isUnlocked = false;
      _isDecoyMode = false;
    }
    notifyListeners();
  }

  Future<bool> authenticate(BuildContext context) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final hasPin = (prefs.getString('vault_pin_hash') != null) ||
        (_currentEnvelope?.pinSlot != null);

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
                    : 'Set a 4-digit PIN to initialize salted PBKDF2 + AES-256-GCM portable vault protection.',
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
    _isDecoyMode = false;
    _activeUnlockedPin = null;
    _sessionRecoveryKey = null;
    if (_currentEnvelope != null) {
      // Clear key from RAM when portable envelope is available to unwrap again
      _masterKey = null;
    }
    _manifest.clear();
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

    try {
      final vaultDir = await getVaultDirectory(createIfMissing: false);
      final stagingDir = Directory(p.join(vaultDir.path, _stagingSubfolder));
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<Directory> getVaultDirectory({bool createIfMissing = true}) async {
    if (_activeVaultDirPath == null || _activeVaultDirPath!.trim().isEmpty) {
      final internalDir = await _getInternalVaultDirectory();
      _activeVaultDirPath = internalDir.path;
    }
    final vaultDir = Directory(_activeVaultDirPath!);
    if (createIfMissing && !await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
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
    if (await manifestFile.exists()) {
      await manifestFile.delete();
    }
    await tempManifest.rename(manifestFile.path);
  }

  Future<void> _cleanupOrphanedMigrationFiles() async {
    try {
      final vaultDir = await getVaultDirectory(createIfMissing: false);
      if (!await vaultDir.exists()) return;
      await for (final entity in vaultDir.list()) {
        if (entity is File && entity.path.endsWith('.tmp')) {
          await entity.delete();
        }
      }
      final stagingDir = Directory(p.join(vaultDir.path, _stagingSubfolder));
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
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
    if (!_isUnlocked || _masterKey == null) throw Exception("Vault is locked");

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
      destSink.add(_magicHeader);

      while (true) {
        final bytes = await raf.read(_chunkSize);
        if (bytes.isEmpty) break;

        totalPlainBytes += bytes.length;
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
    if (!_isUnlocked || _masterKey == null) throw Exception("Vault is locked");

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
    if (!_isUnlocked || _isDecoyMode) return [];
    final vaultDir = await getVaultDirectory();
    if (!await vaultDir.exists()) return [];
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
    if (!_isUnlocked || _masterKey == null) throw Exception("Vault is locked");

    final vaultDir = await getVaultDirectory();
    final Directory targetTempDir;
    if (_decryptCacheOnVaultDrive) {
      targetTempDir = Directory(p.join(vaultDir.path, _stagingSubfolder));
      if (!await targetTempDir.exists()) {
        await targetTempDir.create(recursive: true);
      }
    } else {
      targetTempDir = await getTemporaryDirectory();
    }

    final encFileName = p.basename(encryptedFile.path);
    final meta = _manifest[encFileName];

    final baseName = encFileName.replaceAll('.enc', '');
    final nameParts = baseName.split('_');
    final originalName = meta?.originalName ??
        (nameParts.length > 1 ? nameParts.sublist(1).join('_') : 'vault_media.mp4');

    final String destPath = p.join(targetTempDir.path, originalName);
    final destFile = File(destPath);

    await _decryptStreamToFile(encryptedFile, destFile, expectedMeta: meta);

    if (!_activeTempFiles.contains(destPath)) {
      _activeTempFiles.add(destPath);
    }
    return destPath;
  }
}
