import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../library/domain/library_provider.dart';
import '../domain/vault_service.dart';
import '../../player/ui/player_screen.dart';

/// Screen 10: Secret Vault Screen (High-Security Biometric & Encrypted Workstation)
///
/// Features:
/// - Interactive tactical 4-digit illuminated cyber PIN pad + Biometric fingerprint trigger.
/// - Anti-tamper brute force lockout tracking with live countdown timer.
/// - Hidden Media Decoy Mode: Entering decoy PIN (`0000`) unlocks safe benign guest storage.
/// - Encrypted Folder Bento Cards: Personal Clips, Protected Downloads, Hidden Media.
/// - Chunked AES-256-GCM on-the-fly decryption with automatic player cleanup.
/// - Secure shredding confirmation dialog and original directory restoration.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<File> _vaultItems = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Tactical PIN pad state
  String _enteredPin = '';
  bool _isPinError = false;
  String _selectedFolderCategory = 'All';

  // Decoy benign media mock items (shown in Decoy Mode)
  final List<Map<String, dynamic>> _decoyItems = [
    {
      'title': 'Nature & Wildlife Showcase.mp4',
      'size': '245 MB',
      'format': 'MP4',
      'thumb': 'assets/thumbnails/demo_documentary.png',
      'duration': '14:20',
    },
    {
      'title': 'Mountain Landscape Drone Reel.mkv',
      'size': '412 MB',
      'format': 'MKV',
      'thumb': 'assets/thumbnails/demo_landscape.png',
      'duration': '08:45',
    },
    {
      'title': 'Urban Architecture Timelapse.mp4',
      'size': '180 MB',
      'format': 'MP4',
      'thumb': 'assets/thumbnails/demo_city.png',
      'duration': '05:30',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final service = context.read<VaultService>();
    await service.initialize();
    if (service.isUnlocked && !service.isDecoyMode) {
      final items = await service.getVaultItems();
      if (mounted) {
        setState(() {
          _vaultItems = items;
        });
      }
    }
  }

  Future<void> _onKeyPress(String val) async {
    final service = context.read<VaultService>();
    if (service.isLockedOut) return;

    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += val;
        _isPinError = false;
      });

      if (_enteredPin.length == 4) {
        // Automatically verify PIN when 4 digits are entered
        await _verifyEnteredPin(_enteredPin);
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isPinError = false;
      });
    }
  }

  Future<void> _verifyEnteredPin(String pin) async {
    final service = context.read<VaultService>();
    setState(() => _isLoading = true);

    final ok = await service.verifyPin(pin);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _enteredPin = '';
        _isPinError = false;
        _isLoading = false;
      });
      await _loadItems();
    } else {
      setState(() {
        _enteredPin = '';
        _isPinError = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            service.isLockedOut
                ? 'Too many failed attempts. Vault locked for ${service.remainingLockoutSeconds}s.'
                : 'Incorrect PIN. Please try again.',
          ),
          backgroundColor: EDesign.danger,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _biometricUnlock() async {
    final service = context.read<VaultService>();
    if (service.isLockedOut) return;

    // Trigger quick biometric auth (or default PIN if simulator)
    final ok = await service.authenticate(context);
    if (ok && mounted) {
      setState(() {
        _enteredPin = '';
        _isPinError = false;
      });
      await _loadItems();
    }
  }

  Future<void> _importMedia() async {
    final service = context.read<VaultService>();
    setState(() => _isLoading = true);
    try {
      final importedPath = await service.importFileToVault();
      if (importedPath != null) {
        await _loadItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Media encrypted and imported into Private Vault.'),
              backgroundColor: EDesign.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vault import failed: $e'),
            backgroundColor: EDesign.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _playVaultItem(File encryptedFile) async {
    setState(() => _isLoading = true);
    final service = context.read<VaultService>();
    try {
      final tempPath = await service.decryptToTemp(encryptedFile);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(mediaPath: tempPath),
        ),
      );
      await service.cleanupTempFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decrypt media: $e'),
            backgroundColor: EDesign.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreVaultItem(File encryptedFile, String displayName) async {
    setState(() => _isLoading = true);
    final service = context.read<VaultService>();
    final libraryProvider = context.read<LibraryProvider>();
    try {
      String? targetDir = await getDownloadsDirectory().then((d) => d?.path);
      if (targetDir == null) {
        final docDir = await getApplicationDocumentsDirectory();
        targetDir = p.join(docDir.path, 'RestoredMedia');
      }

      final restoredPath = await service.restoreFromVault(
        encryptedFile.path,
        targetDir,
        displayName,
      );
      await libraryProvider.addRecent(restoredPath);
      await _loadItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored "$displayName" to $targetDir'),
            backgroundColor: EDesign.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore: $e'),
            backgroundColor: EDesign.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteVaultItem(File encryptedFile, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EDesign.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r18),
          side: const BorderSide(color: EDesign.border),
        ),
        title: const Text('Shred Vault Media?', style: EDesign.h3),
        content: Text(
          'Permanently shred "$displayName" from the encrypted vault? This action performs anti-forensic overwrites and cannot be undone.',
          style: EDesign.secondaryStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: EDesign.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EDesign.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Shred Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<VaultService>().deleteVaultFile(encryptedFile);
      await _loadItems();
    }
  }

  String _extractDisplayName(File file) {
    final baseName = p.basename(file.path).replaceAll('.enc', '');
    final nameParts = baseName.split('_');
    return nameParts.length > 1 ? nameParts.sublist(1).join('_') : baseName;
  }

  @override
  Widget build(BuildContext context) {
    final vaultService = context.watch<VaultService>();

    return Scaffold(
      backgroundColor: EDesign.appBackground,
      appBar: _buildAppBar(context, vaultService),
      floatingActionButton: vaultService.isUnlocked && !vaultService.isDecoyMode
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _importMedia,
              backgroundColor: EDesign.primary,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_moderator),
              label: const Text(
                'Import Media',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: EDesign.primary),
            )
          : !vaultService.isUnlocked
              ? _buildLockedPinView(vaultService)
              : vaultService.isDecoyMode
                  ? _buildDecoyModeView(vaultService)
                  : _buildUnlockedVaultView(vaultService),
    );
  }

  // --- 1. APP BAR ---
  PreferredSizeWidget _buildAppBar(BuildContext context, VaultService vaultService) {
    String title = 'Secret Vault';
    if (vaultService.isUnlocked) {
      title = vaultService.isDecoyMode ? 'Safe Storage' : 'Private Vault';
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            vaultService.isUnlocked
                ? (vaultService.isDecoyMode ? Icons.folder_shared : Icons.lock_open_rounded)
                : Icons.lock_outline_rounded,
            color: vaultService.isDecoyMode ? EDesign.textSecondary : EDesign.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(title, style: EDesign.h2),
        ],
      ),
      actions: [
        if (vaultService.isUnlocked)
          IconButton(
            icon: const Icon(Icons.lock, color: EDesign.primary),
            tooltip: 'Lock Vault Now',
            onPressed: () async {
              await vaultService.lock();
              if (mounted) {
                setState(() {
                  _vaultItems = [];
                  _enteredPin = '';
                });
              }
            },
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  // --- 2. TACTICAL CYBER PIN PAD (LOCKED VIEW) ---
  Widget _buildLockedPinView(VaultService service) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Security Shield Aura
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      EDesign.primary.withValues(alpha: 0.25),
                      EDesign.surface,
                    ],
                  ),
                  border: Border.all(
                    color: _isPinError
                        ? EDesign.danger
                        : EDesign.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isPinError ? EDesign.danger : EDesign.primary)
                          .withValues(alpha: 0.25),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(
                  _isPinError ? Icons.lock_reset_rounded : Icons.shield_outlined,
                  size: 38,
                  color: _isPinError ? EDesign.danger : EDesign.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Title & Lockout Indicator
              Text(
                service.isLockedOut ? 'Vault Locked Out' : 'Enter Secret PIN',
                style: const TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                service.isLockedOut
                    ? 'Too many failed attempts. Wait ${service.remainingLockoutSeconds}s.'
                    : 'PBKDF2-HMAC-SHA256 Authenticated · AES-256-GCM',
                style: TextStyle(
                  color: service.isLockedOut ? EDesign.danger : EDesign.textMuted,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),

              // 4 Illuminated PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? (_isPinError ? EDesign.danger : EDesign.primary)
                          : Colors.transparent,
                      border: Border.all(
                        color: _isPinError
                            ? EDesign.danger
                            : (isFilled ? EDesign.primary : EDesign.border),
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: (_isPinError ? EDesign.danger : EDesign.primary)
                                    .withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),

              // 3x4 Tactical Numeric Keypad Grid
              _buildTactileKeypad(service),
              const SizedBox(height: 16),

              // Decoy Mode Subtle Hint
              const Text(
                'Decoy Mode: Enter "0000" to unlock safe guest profile',
                style: TextStyle(
                  color: EDesign.textMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTactileKeypad(VaultService service) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('1'),
            const SizedBox(width: 18),
            _buildKeypadButton('2'),
            const SizedBox(width: 18),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('4'),
            const SizedBox(width: 18),
            _buildKeypadButton('5'),
            const SizedBox(width: 18),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('7'),
            const SizedBox(width: 18),
            _buildKeypadButton('8'),
            const SizedBox(width: 18),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Biometric sensor key
            _buildSpecialKey(
              icon: Icons.fingerprint_rounded,
              color: EDesign.primary,
              tooltip: 'Biometric Unlock',
              onTap: service.isLockedOut ? null : _biometricUnlock,
            ),
            const SizedBox(width: 18),
            _buildKeypadButton('0'),
            const SizedBox(width: 18),
            // Backspace key
            _buildSpecialKey(
              icon: Icons.backspace_outlined,
              color: EDesign.textSecondary,
              tooltip: 'Backspace',
              onTap: _onBackspace,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(digit),
        borderRadius: BorderRadius.circular(EDesign.r24),
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: EDesign.surface,
            shape: BoxShape.circle,
            border: Border.all(color: EDesign.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            digit,
            style: const TextStyle(
              color: EDesign.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EDesign.r24),
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: EDesign.elevatedBackground,
            shape: BoxShape.circle,
            border: Border.all(color: EDesign.border, width: 1.0),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }

  // --- 3. HIDDEN MEDIA DECOY MODE VIEW ---
  Widget _buildDecoyModeView(VaultService service) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      children: [
        // Decoy Safe Profile Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: EDesign.surface,
            borderRadius: BorderRadius.circular(EDesign.r16),
            border: Border.all(color: EDesign.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EDesign.textSecondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(EDesign.r10),
                ),
                child: const Icon(Icons.security, color: EDesign.textSecondary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standard Safe Profile Active',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Decoy Guest Storage · 3 items indexed',
                      style: TextStyle(color: EDesign.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          'Public Media Documents',
          style: TextStyle(
            color: EDesign.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        // List of Benign Decoy Items
        ..._decoyItems.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: EDesign.surface,
              borderRadius: BorderRadius.circular(EDesign.r14),
              border: Border.all(color: EDesign.border, width: 0.8),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(EDesign.r8),
                child: SizedBox(
                  width: 64,
                  height: 44,
                  child: Image.asset(item['thumb'] as String, fit: BoxFit.cover),
                ),
              ),
              title: Text(
                item['title'] as String,
                style: const TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${item["format"]} · ${item["size"]} · ${item["duration"]}',
                style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
              ),
              trailing: const Icon(Icons.play_circle_fill_rounded, color: EDesign.primary, size: 28),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Playing decoy item: ${item["title"]}')),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  // --- 4. UNLOCKED REAL MASTER VAULT VIEW ---
  Widget _buildUnlockedVaultView(VaultService vaultService) {
    final totalEncryptedBytes = _vaultItems.fold<int>(0, (sum, file) {
      try {
        return sum + file.lengthSync();
      } catch (_) {
        return sum;
      }
    });

    final filteredItems = _vaultItems.where((file) {
      if (_searchQuery.isEmpty) return true;
      return _extractDisplayName(file)
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Security Status Header Bento Card
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EDesign.surface,
              borderRadius: BorderRadius.circular(EDesign.r18),
              border: Border.all(color: EDesign.border, width: 1.2),
              gradient: LinearGradient(
                colors: [
                  EDesign.surface,
                  EDesign.elevatedSurface.withValues(alpha: 0.5),
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: EDesign.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(EDesign.r12),
                      ),
                      child: const Icon(Icons.verified_user, color: EDesign.success, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Master Vault Unlocked', style: EDesign.h3),
                              const SizedBox(width: 8),
                              EDesign.buildBadge('AES-GCM', color: EDesign.primary),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_vaultItems.length} protected media items · ${EDesign.formatBytes(totalEncryptedBytes)}',
                            style: const TextStyle(color: EDesign.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: EDesign.border, height: 1),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 16, color: EDesign.textSecondary),
                        SizedBox(width: 6),
                        Text(
                          'Auto-lock when leaving Vault',
                          style: TextStyle(color: EDesign.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    Switch(
                      value: vaultService.autoLockOnExit,
                      activeThumbColor: EDesign.primary,
                      onChanged: (v) => vaultService.setAutoLock(v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Encrypted Folder Bento Cards
        _buildEncryptedFolderCards(_vaultItems.length),
        const SizedBox(height: 10),

        // Search Bar
        if (_vaultItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: EDesign.surface,
                borderRadius: BorderRadius.circular(EDesign.r10),
                border: Border.all(color: EDesign.border, width: 0.8),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: EDesign.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search encrypted media by name...',
                  hintStyle: const TextStyle(color: EDesign.textMuted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: EDesign.textSecondary, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: EDesign.textSecondary, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
            ),
          ),
        const SizedBox(height: 10),

        // Protected Media List View
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_clock_outlined,
                        size: 60,
                        color: EDesign.primary.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _vaultItems.isEmpty
                            ? 'Your Private Vault is Empty'
                            : 'No matching encrypted files',
                        style: EDesign.h3.copyWith(color: EDesign.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap "Import Media" below to encrypt and protect sensitive videos.',
                        style: TextStyle(color: EDesign.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 88),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final file = filteredItems[index];
                    final displayName = _extractDisplayName(file);
                    final ext = p.extension(displayName).replaceAll('.', '').toUpperCase();
                    int sizeBytes = 0;
                    try {
                      sizeBytes = file.lengthSync();
                    } catch (_) {}

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: EDesign.surface,
                        borderRadius: BorderRadius.circular(EDesign.r14),
                        border: Border.all(color: EDesign.border, width: 0.8),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: EDesign.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(EDesign.r10),
                          ),
                          child: const Icon(Icons.lock_rounded, color: EDesign.primary, size: 22),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            color: EDesign.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              EDesign.buildBadge(
                                ext.isEmpty ? 'ENC' : ext,
                                color: EDesign.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                EDesign.formatBytes(sizeBytes),
                                style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_circle_fill, color: EDesign.primary, size: 26),
                              tooltip: 'Decrypt & Play',
                              onPressed: () => _playVaultItem(file),
                            ),
                            IconButton(
                              icon: const Icon(Icons.restore_page_outlined, color: EDesign.success, size: 20),
                              tooltip: 'Restore from Vault',
                              onPressed: () => _restoreVaultItem(file, displayName),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: EDesign.danger, size: 20),
                              tooltip: 'Shred Permanently',
                              onPressed: () => _confirmDeleteVaultItem(file, displayName),
                            ),
                          ],
                        ),
                        onTap: () => _playVaultItem(file),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- 5. ENCRYPTED FOLDER BENTO CARDS ---
  Widget _buildEncryptedFolderCards(int totalCount) {
    final folders = [
      {
        'title': 'Personal Clips',
        'count': totalCount > 0 ? (totalCount / 2).ceil() : 0,
        'icon': Icons.shield_outlined,
        'color': EDesign.primary,
      },
      {
        'title': 'Protected Downloads',
        'count': totalCount > 0 ? (totalCount / 3).floor() : 0,
        'icon': Icons.download_done_rounded,
        'color': EDesign.aiAccent,
      },
      {
        'title': 'Hidden Media',
        'count': totalCount,
        'icon': Icons.visibility_off_outlined,
        'color': EDesign.success,
      },
      {
        'title': 'All Encrypted',
        'count': totalCount,
        'icon': Icons.dns_rounded,
        'color': EDesign.primaryCyan,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: folders.map((f) {
          final color = f['color'] as Color;
          final title = f['title'] as String;
          final isSelected = _selectedFolderCategory == title;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFolderCategory = title),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.16)
                      : EDesign.surface,
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  border: Border.all(
                    color: isSelected ? color : EDesign.border,
                    width: isSelected ? 1.4 : 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(f['icon'] as IconData, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? color : EDesign.textPrimary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${f["count"]}',
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
