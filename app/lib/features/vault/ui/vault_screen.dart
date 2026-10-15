import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../library/domain/library_provider.dart';
import '../domain/vault_service.dart';
import '../../player/ui/player_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _isLoading = false;
  List<File> _vaultItems = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    if (service.isUnlocked) {
      final items = await service.getVaultItems();
      if (mounted) {
        setState(() {
          _vaultItems = items;
        });
      }
    }
  }

  Future<void> _unlock() async {
    final service = context.read<VaultService>();
    final unlocked = await service.authenticate(context);
    if (unlocked) {
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
          'Permanently delete "$displayName" from the encrypted vault? This action cannot be undone.',
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
            child: const Text('Delete Forever'),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Private Vault', style: EDesign.h2),
        centerTitle: true,
        actions: [
          if (vaultService.isUnlocked)
            IconButton(
              icon: const Icon(Icons.lock_outline, color: EDesign.primary),
              tooltip: 'Lock Vault Now',
              onPressed: () async {
                await vaultService.lock();
                if (mounted) setState(() => _vaultItems = []);
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: vaultService.isUnlocked
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
              ? _buildLockedView()
              : _buildUnlockedView(vaultService),
    );
  }

  /// Screen 22 — Vault Unlock (Stitch V3 Specification)
  Widget _buildLockedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: EDesign.cardDecoration(
            color: EDesign.surface,
            radius: EDesign.r24,
            withGlow: true,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      EDesign.primary.withValues(alpha: 0.28),
                      EDesign.surface,
                    ],
                  ),
                  border: Border.all(
                    color: EDesign.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 44,
                  color: EDesign.primary,
                ),
              ),
              const SizedBox(height: 20),
              EDesign.buildBadge(
                'AES-256-GCM ENCRYPTED',
                color: EDesign.success,
                icon: Icons.verified_user_outlined,
              ),
              const SizedBox(height: 16),
              const Text(
                'Vault Locked',
                style: EDesign.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Protected media is encrypted locally in 1 MB authenticated AES-GCM chunks. Files are never exposed to external scanners or hidden using .nomedia tricks.',
                style: EDesign.secondaryStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r14),
                    ),
                    elevation: 6,
                    shadowColor: EDesign.primary.withValues(alpha: 0.4),
                  ),
                  icon: const Icon(Icons.fingerprint, size: 24),
                  label: const Text(
                    'Authenticate & Unlock',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _unlock,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Screen 21 — Vault (Stitch V3 Specification)
  Widget _buildUnlockedView(VaultService vaultService) {
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
        // Security Status Header Card
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: EDesign.cardDecoration(
              color: EDesign.elevatedSurface,
              radius: EDesign.r18,
              withGlow: true,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: EDesign.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(EDesign.r14),
                      ),
                      child: const Icon(Icons.verified_user, color: EDesign.success, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Vault Unlocked', style: EDesign.h3),
                              const SizedBox(width: 8),
                              EDesign.buildBadge('AES-GCM', color: EDesign.primary),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_vaultItems.length} protected files · ${EDesign.formatBytes(totalEncryptedBytes)}',
                            style: EDesign.secondaryStyle,
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
                        Icon(Icons.timer_outlined, size: 18, color: EDesign.textSecondary),
                        SizedBox(width: 8),
                        Text('Auto-lock when leaving Vault', style: EDesign.secondaryStyle),
                      ],
                    ),
                    Switch(
                      value: vaultService.autoLockOnExit,
                      activeColor: EDesign.primary,
                      onChanged: (v) => vaultService.setAutoLock(v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Search Bar
        if (_vaultItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 46,
              decoration: EDesign.cardDecoration(radius: EDesign.r10),
              child: TextField(
                controller: _searchController,
                style: EDesign.body,
                decoration: InputDecoration(
                  hintText: 'Search encrypted media...',
                  hintStyle: const TextStyle(color: EDesign.textMuted),
                  prefixIcon: const Icon(Icons.search, color: EDesign.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: EDesign.textSecondary, size: 18),
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

        const SizedBox(height: 12),

        // Protected Media List
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_clock_outlined,
                        size: 64,
                        color: EDesign.primary.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _vaultItems.isEmpty
                            ? 'Your Private Vault is Empty'
                            : 'No matching encrypted files',
                        style: EDesign.h3.copyWith(color: EDesign.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Import sensitive videos or move items from your Media Library.',
                        style: EDesign.secondaryStyle,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 88),
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
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: EDesign.cardDecoration(radius: EDesign.r14),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: EDesign.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(EDesign.r10),
                          ),
                          child: const Icon(Icons.lock_rounded, color: EDesign.primary),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            color: EDesign.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              EDesign.buildBadge(
                                ext.isEmpty ? 'ENC' : ext,
                                color: EDesign.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                EDesign.formatBytes(sizeBytes),
                                style: EDesign.caption,
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_circle_fill, color: EDesign.primary, size: 28),
                              tooltip: 'Decrypt & Play',
                              onPressed: () => _playVaultItem(file),
                            ),
                            IconButton(
                              icon: const Icon(Icons.restore_page_outlined, color: EDesign.success),
                              tooltip: 'Restore from Vault',
                              onPressed: () => _restoreVaultItem(file, displayName),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: EDesign.danger),
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
}
