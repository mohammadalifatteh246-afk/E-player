import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../ui/theme/e_design_tokens.dart';
import '../domain/vault_service.dart';

/// Cyberpunk Storage & Recovery Studio Sheet for E-Player Private Vault.
/// Supports Internal Storage + External Drives (D:\, SD Card, USB),
/// live vault switching, portable recovery key generation/export,
/// and reinstall/forgotten-PIN recovery via `vault_keystore.json`.
class VaultStorageRecoveryStudioSheet extends StatefulWidget {
  final VaultService? service;
  final Future<String?> Function()? onPickCustomFolder;
  final Future<String?> Function()? onPickBackupDir;

  const VaultStorageRecoveryStudioSheet({
    super.key,
    this.service,
    this.onPickCustomFolder,
    this.onPickBackupDir,
  });

  static Future<void> show(
    BuildContext context, {
    VaultService? service,
    Future<String?> Function()? onPickCustomFolder,
    Future<String?> Function()? onPickBackupDir,
  }) {
    final effective = service ?? context.read<VaultService>();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => VaultStorageRecoveryStudioSheet(
        service: effective,
        onPickCustomFolder: onPickCustomFolder,
        onPickBackupDir: onPickBackupDir,
      ),
    );
  }

  @override
  State<VaultStorageRecoveryStudioSheet> createState() =>
      _VaultStorageRecoveryStudioSheetState();
}

class _VaultStorageRecoveryStudioSheetState
    extends State<VaultStorageRecoveryStudioSheet> {
  VaultService? _service;
  List<VaultLocationInfo> _locations = [];
  bool _isLoadingLocations = true;
  bool _reloadingInFlight = false;
  bool _reloadPending = false;
  bool _isRecovering = false;
  String? _statusMessage;
  bool _statusIsError = false;
  String? _displayedRecoveryKey;

  final TextEditingController _recoveryKeyController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = widget.service ?? context.read<VaultService>();
    if (_service != next) {
      _service?.removeListener(_onServiceChanged);
      _service = next;
      _service?.addListener(_onServiceChanged);
      _displayedRecoveryKey = next.sessionRecoveryKey;
      _reloadLocations();
    }
  }

  @override
  void dispose() {
    _service?.removeListener(_onServiceChanged);
    _recoveryKeyController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _reloadLocations();
  }

  Future<void> _reloadLocations() async {
    if (_reloadingInFlight) {
      _reloadPending = true;
      return;
    }
    final srv = _service;
    if (srv == null) return;
    _reloadingInFlight = true;
    try {
      do {
        _reloadPending = false;
        final list = await srv.discoverVaultLocations();
        if (!mounted) return;
        setState(() {
          _locations = list;
          _isLoadingLocations = false;
          _displayedRecoveryKey ??= srv.sessionRecoveryKey;
        });
      } while (_reloadPending && mounted);
    } finally {
      _reloadingInFlight = false;
    }
  }

  Future<void> _switchToLocation(VaultLocationInfo loc) async {
    final srv = _service;
    if (srv == null || loc.isActive) return;
    setState(() {
      _statusMessage = null;
      _statusIsError = false;
    });
    await srv.switchVaultLocation(loc.directoryPath);
    if (!mounted) return;
    setState(() {
      _displayedRecoveryKey = srv.sessionRecoveryKey;
      _statusMessage = srv.isUnlocked
          ? 'Switched to ${loc.label} (${loc.encryptedFileCount} items).'
          : 'Mounted ${loc.label}. Enter PIN or Recovery Key to unlock.';
      _statusIsError = false;
    });
  }

  Future<void> _mountCustomFolder() async {
    final srv = _service;
    if (srv == null) return;
    final picked = widget.onPickCustomFolder != null
        ? await widget.onPickCustomFolder!()
        : await FilePicker.getDirectoryPath();
    if (picked == null || picked.trim().isEmpty) return;

    final mountedPath = await srv.mountCustomVaultFolder(picked);
    if (!mounted) return;
    await _reloadLocations();
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Mounted Vault at $mountedPath';
      _statusIsError = false;
    });
  }

  Future<void> _revealOrRotateRecoveryKey({bool rotate = false}) async {
    final srv = _service;
    if (srv == null) return;
    try {
      final key =
          await srv.generateOrGetRecoveryKey(forceRegenerate: rotate);
      if (!mounted) return;
      setState(() {
        _displayedRecoveryKey = key;
        _statusMessage = rotate
            ? 'New Recovery Key generated! Store this code safely.'
            : 'Recovery Key active in keystore envelope.';
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Unlock Vault first to view or rotate Recovery Key.';
        _statusIsError = true;
      });
    }
  }

  Future<void> _exportBackupFile() async {
    final srv = _service;
    if (srv == null) return;
    try {
      final pickedDir = widget.onPickBackupDir != null
          ? await widget.onPickBackupDir!()
          : await FilePicker.getDirectoryPath();
      if (pickedDir == null || pickedDir.trim().isEmpty) return;
      final savedPath = await srv.exportPortableKeyBackup(
        pickedDir,
        explicitRecoveryKey: _displayedRecoveryKey,
      );
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Exported backup key file: $savedPath';
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Backup export failed: $e';
        _statusIsError = true;
      });
    }
  }

  Future<void> _submitRecoveryUnlock() async {
    final srv = _service;
    if (srv == null) return;
    final keyInput = _recoveryKeyController.text.trim();
    final newPin = _newPinController.text.trim();

    if (keyInput.isEmpty || newPin.length != 4) {
      setState(() {
        _statusMessage = 'Enter your EPLY recovery code and a 4-digit new PIN.';
        _statusIsError = true;
      });
      return;
    }

    setState(() => _isRecovering = true);
    final ok = await srv.recoverWithRecoveryKey(
      recoveryKey: keyInput,
      newPin: newPin,
    );
    if (!mounted) return;
    setState(() {
      _isRecovering = false;
      if (ok) {
        _statusMessage = 'Vault recovered & unlocked with new PIN!';
        _statusIsError = false;
        _recoveryKeyController.clear();
        _newPinController.clear();
      } else {
        _statusMessage =
            'Recovery Key mismatch or keystore missing in this vault.';
        _statusIsError = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final srv = _service;
    if (srv == null) return const SizedBox.shrink();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: EDesign.surface.withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: EDesign.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              EDesign.primaryCyan.withValues(alpha: 0.25),
                              EDesign.secondary.withValues(alpha: 0.25),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: EDesign.primaryCyan.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: EDesign.primaryCyan,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vault Storage & Recovery Studio',
                              style: TextStyle(
                                color: EDesign.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Internal + D:\\ / SD Card · Uninstall-Safe Key Envelope',
                              style: TextStyle(
                                color: EDesign.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('vault_studio_close_btn'),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.close_rounded,
                            color: EDesign.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Active Envelope Telemetry Pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPill(
                        key: const Key('vault_keystore_status_pill'),
                        icon: srv.hasKeystoreEnvelope
                            ? Icons.vpn_key_rounded
                            : Icons.key_off_rounded,
                        label: srv.hasKeystoreEnvelope
                            ? 'Portable Keystore ✓'
                            : 'Keystore: Initialize PIN',
                        color: srv.hasKeystoreEnvelope
                            ? EDesign.success
                            : EDesign.warning,
                      ),
                      if (srv.currentRecoveryKeyHint != null)
                        _buildPill(
                          key: const Key('vault_recovery_hint_pill'),
                          icon: Icons.security_rounded,
                          label: 'Key Hint: ${srv.currentRecoveryKeyHint}',
                          color: EDesign.primaryCyan,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Storage Locations Section
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'VAULT STORAGE LOCATIONS (INTERNAL · D:\\ · SD)',
                          style: TextStyle(
                            color: EDesign.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('vault_mount_folder_btn'),
                        onPressed: _mountCustomFolder,
                        icon: const Icon(Icons.create_new_folder_outlined,
                            size: 16, color: EDesign.primaryCyan),
                        label: const Text(
                          'Mount Folder...',
                          style: TextStyle(
                              color: EDesign.primaryCyan, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (_isLoadingLocations)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: EDesign.primaryCyan),
                      ),
                    )
                  else
                    ..._locations.map(_buildLocationCard),

                  const SizedBox(height: 12),

                  // 2. 4K Performance & Staging Setting
                  Material(
                    color: EDesign.elevatedBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r12),
                      side: const BorderSide(color: EDesign.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      key: const Key('vault_staging_switch'),
                      dense: true,
                      title: const Text(
                        'Stage 4K Playback on Vault Drive',
                        style: TextStyle(
                          color: EDesign.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Decrypts temporary stream on D:\\ / SD card instead of filling C:\\ or internal temp',
                        style: TextStyle(color: EDesign.textMuted, fontSize: 11),
                      ),
                      value: srv.decryptCacheOnVaultDrive,
                      activeThumbColor: EDesign.primaryCyan,
                      onChanged: (v) => srv.setDecryptCacheOnVaultDrive(v),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Recovery Key Management / Restore Section
                  const Text(
                    'UNINSTALL & DEVICE-CHANGE RECOVERY',
                    style: TextStyle(
                      color: EDesign.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (srv.isUnlocked && !srv.isDecoyMode)
                    _buildUnlockedRecoveryCard(srv)
                  else
                    _buildLockedRecoveryCard(),

                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('vault_studio_status_msg'),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_statusIsError
                                ? EDesign.danger
                                : EDesign.success)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(EDesign.r8),
                        border: Border.all(
                          color: (_statusIsError
                                  ? EDesign.danger
                                  : EDesign.success)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _statusIsError
                              ? EDesign.danger
                              : EDesign.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(VaultLocationInfo loc) {
    final IconData icon;
    switch (loc.storageType) {
      case VaultStorageType.internalApp:
        icon = Icons.smartphone_rounded;
        break;
      case VaultStorageType.externalDrive:
        icon = Platform.isAndroid
            ? Icons.sd_storage_rounded
            : Icons.storage_rounded;
        break;
      case VaultStorageType.customFolder:
        icon = Icons.folder_special_rounded;
        break;
    }

    final accent = loc.isActive
        ? EDesign.primaryCyan
        : (loc.hasExistingVaultData ? EDesign.success : EDesign.border);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: loc.isActive
            ? EDesign.primaryCyan.withValues(alpha: 0.08)
            : EDesign.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r12),
          side: BorderSide(
            color: loc.isActive
                ? EDesign.primaryCyan.withValues(alpha: 0.65)
                : EDesign.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('vault_loc_card_${loc.directoryPath}'),
          onTap: loc.isActive ? null : () => _switchToLocation(loc),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.label,
                        style: const TextStyle(
                          color: EDesign.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.directoryPath,
                        style: const TextStyle(
                          color: EDesign.textMuted,
                          fontSize: 10,
                          fontFamily: 'Consolas',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (loc.isActive)
                            _buildMiniTag('Active', EDesign.primaryCyan),
                          if (loc.hasKeystoreEnvelope)
                            _buildMiniTag('Recoverable ✓', EDesign.success),
                          if (loc.encryptedFileCount > 0)
                            _buildMiniTag('${loc.encryptedFileCount} enc files',
                                EDesign.warning),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!loc.isActive)
                  OutlinedButton(
                    key: Key('vault_switch_loc_${loc.directoryPath}'),
                    onPressed: () => _switchToLocation(loc),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EDesign.primaryCyan,
                      side: BorderSide(
                          color: EDesign.primaryCyan.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    child: Text(
                      loc.hasExistingVaultData ? 'Mount' : 'Use Here',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedRecoveryCard(VaultService srv) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedSurface,
        borderRadius: BorderRadius.circular(EDesign.r12),
        border: Border.all(color: EDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your vault carries a self-contained keystore envelope inside the folder. You can always recover it with your PIN or Emergency Recovery Key after uninstalling or switching devices.',
            style: TextStyle(color: EDesign.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          if (_displayedRecoveryKey != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: EDesign.appBackground,
                borderRadius: BorderRadius.circular(EDesign.r8),
                border: Border.all(
                    color: EDesign.primaryCyan.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _displayedRecoveryKey!,
                      key: const Key('vault_recovery_key_display'),
                      style: const TextStyle(
                        color: EDesign.primaryCyan,
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('vault_copy_recovery_key_btn'),
                    tooltip: 'Copy Key',
                    icon: const Icon(Icons.copy_rounded,
                        size: 16, color: EDesign.primaryCyan),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _displayedRecoveryKey!));
                      setState(() {
                        _statusMessage = 'Recovery Key copied to clipboard.';
                        _statusIsError = false;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                key: const Key('vault_show_recovery_key_btn'),
                onPressed: () =>
                    _revealOrRotateRecoveryKey(rotate: _displayedRecoveryKey != null),
                icon: const Icon(Icons.vpn_key_rounded, size: 16),
                label: Text(_displayedRecoveryKey == null
                    ? 'Reveal / Generate Recovery Key'
                    : 'Rotate Recovery Key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EDesign.primaryCyan,
                  foregroundColor: Colors.black,
                ),
              ),
              OutlinedButton.icon(
                key: const Key('vault_export_key_btn'),
                onPressed: _exportBackupFile,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export .epvkey Backup'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EDesign.success,
                  side:
                      BorderSide(color: EDesign.success.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockedRecoveryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedSurface,
        borderRadius: BorderRadius.circular(EDesign.r12),
        border: Border.all(color: EDesign.warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Forgot PIN or moved D:\\ / SD Card to a new device? Enter your Recovery Key & set a new 4-digit PIN:',
            style: TextStyle(color: EDesign.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('vault_recover_key_input'),
            controller: _recoveryKeyController,
            style: const TextStyle(
              color: EDesign.textPrimary,
              fontSize: 12,
              fontFamily: 'Consolas',
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'EPLY-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
              hintStyle: TextStyle(
                  color: EDesign.textMuted.withValues(alpha: 0.6), fontSize: 11),
              filled: true,
              fillColor: EDesign.appBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(EDesign.r8),
                borderSide: const BorderSide(color: EDesign.border),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('vault_recover_new_pin_input'),
                  controller: _newPinController,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: EDesign.textPrimary,
                    fontSize: 14,
                    letterSpacing: 4,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: 'New 4-digit PIN',
                    hintStyle: TextStyle(
                        color: EDesign.textMuted.withValues(alpha: 0.6),
                        fontSize: 11,
                        letterSpacing: 0),
                    filled: true,
                    fillColor: EDesign.appBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(EDesign.r8),
                      borderSide: const BorderSide(color: EDesign.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                key: const Key('vault_recover_submit_btn'),
                onPressed: _isRecovering ? null : _submitRecoveryUnlock,
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: Text(_isRecovering ? 'Recovering...' : 'Recover & Unlock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EDesign.warning,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(EDesign.r8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
