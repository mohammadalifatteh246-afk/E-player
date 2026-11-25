import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../ui/theme/e_design_tokens.dart';
import '../domain/library_provider.dart';

/// Cyberpunk Multi-Drive & Storage Scanner Studio Sheet.
/// Enables Windows & desktop/mobile users to discover all logical drives (C:, D:, E:, USB),
/// identify unscanned drives at a glance, add custom folders, and run simultaneous batch scans.
class DriveScannerStudioSheet extends StatefulWidget {
  final LibraryProvider? provider;
  final List<String>? overrideDrives;
  final Future<String?> Function()? onPickCustomFolder;

  const DriveScannerStudioSheet({
    super.key,
    this.provider,
    this.overrideDrives,
    this.onPickCustomFolder,
  });

  static Future<void> show(
    BuildContext context, {
    LibraryProvider? provider,
    List<String>? overrideDrives,
    Future<String?> Function()? onPickCustomFolder,
  }) {
    final effectiveProvider = provider ?? context.read<LibraryProvider>();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DriveScannerStudioSheet(
        provider: effectiveProvider,
        overrideDrives: overrideDrives,
        onPickCustomFolder: onPickCustomFolder,
      ),
    );
  }

  @override
  State<DriveScannerStudioSheet> createState() =>
      _DriveScannerStudioSheetState();
}

class _DriveScannerStudioSheetState extends State<DriveScannerStudioSheet> {
  LibraryProvider? _provider;
  List<DriveVolumeInfo> _volumes = [];
  final Set<String> _selectedPaths = {};
  bool _skipSystemFolders = true;
  bool _includeHiddenFiles = false;
  bool _initializedSelection = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextProvider = widget.provider ?? context.read<LibraryProvider>();
    if (_provider != nextProvider) {
      _provider?.removeListener(_onProviderChanged);
      _provider = nextProvider;
      _provider?.addListener(_onProviderChanged);
      _refreshVolumes(preselectUnscanned: !_initializedSelection);
      _initializedSelection = true;
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    _refreshVolumes(preselectUnscanned: false);
  }

  void _refreshVolumes({bool preselectUnscanned = false}) {
    final prov = _provider;
    if (prov == null) return;
    final discovered = prov.discoverDrives(overrideDrives: widget.overrideDrives);

    if (preselectUnscanned) {
      _selectedPaths.clear();
      final unscanned = discovered.where((v) => !v.isScanned).toList();
      if (unscanned.isNotEmpty) {
        for (final v in unscanned) {
          _selectedPaths.add(v.rootPath);
        }
      } else {
        for (final v in discovered) {
          _selectedPaths.add(v.rootPath);
        }
      }
      for (final folder in prov.customScanFolders) {
        _selectedPaths.add(folder);
      }
    }

    setState(() {
      _volumes = discovered;
    });
  }

  String _selectionKey(String path) =>
      Platform.isWindows ? path.toLowerCase() : path;

  bool _isPathSelected(String path) {
    final key = _selectionKey(path);
    return _selectedPaths.any((p) => _selectionKey(p) == key);
  }

  void _togglePath(String path) {
    final key = _selectionKey(path);
    setState(() {
      final existing =
          _selectedPaths.where((p) => _selectionKey(p) == key).toList();
      if (existing.isNotEmpty) {
        _selectedPaths.removeAll(existing);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _selectUnscannedOnly() {
    setState(() {
      _selectedPaths.clear();
      for (final v in _volumes) {
        if (!v.isScanned) {
          _selectedPaths.add(v.rootPath);
        }
      }
    });
  }

  void _toggleSelectAll() {
    final prov = _provider;
    final allPaths = <String>[
      ..._volumes.map((v) => v.rootPath),
      if (prov != null) ...prov.customScanFolders,
    ];
    final allSelected =
        allPaths.isNotEmpty && allPaths.every(_isPathSelected);

    setState(() {
      _selectedPaths.clear();
      if (!allSelected) {
        _selectedPaths.addAll(allPaths);
      }
    });
  }

  Future<void> _pickAndAddCustomFolder() async {
    final prov = _provider;
    if (prov == null) return;

    final picked = widget.onPickCustomFolder != null
        ? await widget.onPickCustomFolder!()
        : await FilePicker.getDirectoryPath();
    if (picked == null || picked.trim().isEmpty) return;

    await prov.addCustomScanFolder(picked);
    if (!mounted) return;
    setState(() {
      if (!_isPathSelected(picked)) {
        _selectedPaths.add(picked);
      }
    });
  }

  Future<void> _startSelectedScan() async {
    final prov = _provider;
    if (prov == null || _selectedPaths.isEmpty || prov.isScanning) return;
    await prov.scanDrives(
      _selectedPaths.toList(),
      showHiddenFiles: _includeHiddenFiles,
      skipSystemDirectories: _skipSystemFolders,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = _provider;
    if (prov == null) return const SizedBox.shrink();

    final unscannedCount = _volumes.where((v) => !v.isScanned).length;
    final scannedCount = _volumes.length - unscannedCount;
    final customFolders = prov.customScanFolders;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: EDesign.surface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
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
                            color: EDesign.primaryCyan.withValues(alpha: 0.35)),
                      ),
                      child: const Icon(
                        Icons.storage_rounded,
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
                            'Multi-Drive & Storage Studio',
                            style: TextStyle(
                              color: EDesign.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Discover & scan multiple drives (C:, D:, USB) simultaneously',
                            style: TextStyle(
                              color: EDesign.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('studio_refresh_drives_btn'),
                      tooltip: 'Refresh Drives',
                      onPressed: prov.isScanning
                          ? null
                          : () => _refreshVolumes(preselectUnscanned: false),
                      icon: const Icon(Icons.refresh_rounded,
                          color: EDesign.primaryCyan, size: 20),
                    ),
                    IconButton(
                      key: const Key('studio_close_btn'),
                      tooltip: 'Close',
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

                // Telemetry Summary Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSummaryBadge(
                      icon: Icons.dns_rounded,
                      label: '${_volumes.length} Drives Detected',
                      color: EDesign.primaryCyan,
                    ),
                    _buildSummaryBadge(
                      icon: Icons.check_circle_outline_rounded,
                      label: '$scannedCount Scanned',
                      color: EDesign.success,
                    ),
                    _buildSummaryBadge(
                      icon: Icons.warning_amber_rounded,
                      label: '$unscannedCount Unscanned',
                      color: unscannedCount > 0
                          ? EDesign.warning
                          : EDesign.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick Batch Selection Actions
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      key: const Key('studio_select_unscanned_btn'),
                      avatar: Icon(
                        Icons.new_releases_outlined,
                        size: 16,
                        color: unscannedCount > 0
                            ? EDesign.warning
                            : EDesign.textMuted,
                      ),
                      label: Text('Select Unscanned ($unscannedCount)'),
                      labelStyle: const TextStyle(
                          fontSize: 12, color: EDesign.textPrimary),
                      backgroundColor: EDesign.elevatedSurface,
                      side: BorderSide(
                        color: unscannedCount > 0
                            ? EDesign.warning.withValues(alpha: 0.6)
                            : EDesign.border,
                      ),
                      onPressed: prov.isScanning ? null : _selectUnscannedOnly,
                    ),
                    ActionChip(
                      key: const Key('studio_select_all_btn'),
                      avatar: const Icon(Icons.done_all_rounded,
                          size: 16, color: EDesign.primaryCyan),
                      label: const Text('Toggle All'),
                      labelStyle: const TextStyle(
                          fontSize: 12, color: EDesign.textPrimary),
                      backgroundColor: EDesign.elevatedSurface,
                      side: const BorderSide(color: EDesign.border),
                      onPressed: prov.isScanning ? null : _toggleSelectAll,
                    ),
                    ActionChip(
                      key: const Key('studio_add_folder_btn'),
                      avatar: const Icon(Icons.create_new_folder_outlined,
                          size: 16, color: EDesign.success),
                      label: const Text('Add Custom Folder...'),
                      labelStyle: const TextStyle(
                          fontSize: 12, color: EDesign.textPrimary),
                      backgroundColor: EDesign.elevatedSurface,
                      side: BorderSide(
                          color: EDesign.success.withValues(alpha: 0.45)),
                      onPressed:
                          prov.isScanning ? null : _pickAndAddCustomFolder,
                    ),
                    ActionChip(
                      key: const Key('studio_quick_user_folders_btn'),
                      avatar: const Icon(Icons.bolt_rounded,
                          size: 16, color: EDesign.aiAccent),
                      label: const Text('Quick User Folders'),
                      labelStyle: const TextStyle(
                          fontSize: 12, color: EDesign.textPrimary),
                      backgroundColor: EDesign.elevatedSurface,
                      side: const BorderSide(color: EDesign.border),
                      onPressed: prov.isScanning
                          ? null
                          : () => prov.scanSystemMediaDirectories(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Drives List Header
                const Text(
                  'DETECTED DRIVES & PARTITIONS',
                  style: TextStyle(
                    color: EDesign.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 8),

                // Drives Cards
                ..._volumes.map((vol) => _buildDriveCard(vol, prov.isScanning)),

                // Custom Folders Subsection
                if (customFolders.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'CUSTOM SCAN FOLDERS',
                    style: TextStyle(
                      color: EDesign.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...customFolders.map((folder) =>
                      _buildCustomFolderCard(folder, prov)),
                ],

                const SizedBox(height: 10),

                // Studio Crawler Toggles
                Material(
                  color: EDesign.elevatedBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(EDesign.r12),
                    side: const BorderSide(color: EDesign.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('studio_skip_os_switch'),
                        dense: true,
                        title: const Text(
                          'Skip OS & System Folders',
                          style: TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Skips Windows, Program Files, \$Recycle.Bin & AppData for safe speed',
                          style:
                              TextStyle(color: EDesign.textMuted, fontSize: 11),
                        ),
                        value: _skipSystemFolders,
                        activeThumbColor: EDesign.primaryCyan,
                        onChanged: prov.isScanning
                            ? null
                            : (val) =>
                                setState(() => _skipSystemFolders = val),
                      ),
                      const Divider(color: EDesign.border, height: 1),
                      SwitchListTile(
                        key: const Key('studio_hidden_files_switch'),
                        dense: true,
                        title: const Text(
                          'Include Hidden Files & Folders',
                          style: TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Scan dotfiles & hidden directories (VLC show-hiddenfiles)',
                          style:
                              TextStyle(color: EDesign.textMuted, fontSize: 11),
                        ),
                        value: _includeHiddenFiles,
                        activeThumbColor: EDesign.primaryCyan,
                        onChanged: prov.isScanning
                            ? null
                            : (val) =>
                                setState(() => _includeHiddenFiles = val),
                      ),
                    ],
                  ),
                ),

                // Live Progress Feedback inside Studio
                if (prov.isScanning) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('studio_live_progress_card'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EDesign.primaryCyan.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(EDesign.r12),
                      border: Border.all(
                          color: EDesign.primaryCyan.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: EDesign.primaryCyan,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Multi-Drive Indexing in Progress...',
                                style: TextStyle(
                                  color: EDesign.primaryCyan,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              key: const Key('studio_cancel_scan_btn'),
                              onPressed: prov.cancelScan,
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                    color: EDesign.warning,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prov.scanProgress,
                          style: const TextStyle(
                            color: EDesign.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ] else if (prov.scanProgress.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    prov.scanProgress,
                    key: const Key('studio_status_message'),
                    style: const TextStyle(
                      color: EDesign.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Footer CTA
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('studio_scan_all_btn'),
                        onPressed: prov.isScanning || _volumes.isEmpty
                            ? null
                            : () => prov.scanAllDrives(
                                  showHiddenFiles: _includeHiddenFiles,
                                  skipSystemDirectories: _skipSystemFolders,
                                ),
                        icon: const Icon(Icons.radar_rounded, size: 18),
                        label: const Text('Scan All Drives'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: EDesign.primaryCyan,
                          side: BorderSide(
                              color:
                                  EDesign.primaryCyan.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(EDesign.r12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        key: const Key('studio_start_scan_btn'),
                        onPressed:
                            prov.isScanning || _selectedPaths.isEmpty
                                ? null
                                : _startSelectedScan,
                        icon: Icon(
                          prov.isScanning
                              ? Icons.hourglass_top_rounded
                              : Icons.play_arrow_rounded,
                          size: 20,
                        ),
                        label: Text(
                          prov.isScanning
                              ? 'Scanning...'
                              : 'Scan Selected (${_selectedPaths.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EDesign.primaryCyan,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: EDesign.border,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(EDesign.r12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(EDesign.r8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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

  Widget _buildSelectableCard({
    required bool isSelected,
    required Color accentColor,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? accentColor.withValues(alpha: 0.08)
            : EDesign.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EDesign.r12),
          side: BorderSide(
            color: isSelected
                ? accentColor.withValues(alpha: 0.6)
                : EDesign.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }

  Widget _buildDriveCard(DriveVolumeInfo vol, bool isBusy) {
    final isSelected = _isPathSelected(vol.rootPath);
    final statusColor = vol.isScanned ? EDesign.success : EDesign.warning;
    final statusText = vol.isScanned
        ? 'Scanned • ${vol.indexedFileCount} files'
        : 'Not Scanned Yet';

    return _buildSelectableCard(
      isSelected: isSelected,
      accentColor: EDesign.primaryCyan,
      onTap: isBusy ? null : () => _togglePath(vol.rootPath),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              key: Key('drive_checkbox_${vol.rootPath}'),
              value: isSelected,
              activeColor: EDesign.primaryCyan,
              checkColor: Colors.black,
              onChanged: isBusy ? null : (_) => _togglePath(vol.rootPath),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                vol.isSystemDrive
                    ? Icons.computer_rounded
                    : Icons.sd_storage_rounded,
                color: statusColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vol.label,
                    style: const TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vol.rootPath,
                    style: const TextStyle(
                      color: EDesign.textMuted,
                      fontSize: 11,
                      fontFamily: 'Consolas',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              key: Key('drive_status_${vol.rootPath}'),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(EDesign.r6),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFolderCard(String folderPath, LibraryProvider prov) {
    final isSelected = _isPathSelected(folderPath);
    final fileCount = prov.countFilesUnderPath(folderPath);
    final folderName = p.basename(folderPath).isNotEmpty
        ? p.basename(folderPath)
        : folderPath;

    return _buildSelectableCard(
      isSelected: isSelected,
      accentColor: EDesign.success,
      onTap: prov.isScanning ? null : () => _togglePath(folderPath),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              key: Key('folder_checkbox_$folderPath'),
              value: isSelected,
              activeColor: EDesign.success,
              checkColor: Colors.black,
              onChanged:
                  prov.isScanning ? null : (_) => _togglePath(folderPath),
            ),
            const Icon(Icons.folder_rounded,
                color: EDesign.success, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folderName,
                    style: const TextStyle(
                      color: EDesign.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$folderPath ($fileCount files)',
                    style: const TextStyle(
                      color: EDesign.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('remove_custom_folder_$folderPath'),
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: EDesign.textMuted),
              onPressed: prov.isScanning
                  ? null
                  : () {
                      _selectedPaths.removeWhere((p) =>
                          _selectionKey(p) == _selectionKey(folderPath));
                      prov.removeCustomScanFolder(folderPath);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
