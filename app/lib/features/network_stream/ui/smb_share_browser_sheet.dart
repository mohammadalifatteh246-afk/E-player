import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../domain/smb_models.dart';
import '../data/smb_service.dart';

/// Cyberpunk Modal Sheet for SMB / Windows Network Share Ingestion (VLC smb2.c & dsm Parity).
class SmbShareBrowserSheet extends StatefulWidget {
  final SmbShareService smbService;
  final void Function(String mrl) onPlayMrl;

  const SmbShareBrowserSheet({
    super.key,
    required this.smbService,
    required this.onPlayMrl,
  });

  /// Presents the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required SmbShareService smbService,
    required void Function(String mrl) onPlayMrl,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SmbShareBrowserSheet(
        smbService: smbService,
        onPlayMrl: onPlayMrl,
      ),
    );
  }

  @override
  State<SmbShareBrowserSheet> createState() => _SmbShareBrowserSheetState();
}

class _SmbShareBrowserSheetState extends State<SmbShareBrowserSheet> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '445');
  final TextEditingController _shareController = TextEditingController();
  final TextEditingController _subPathController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _isAnonymous = false;
  bool _obscurePassword = true;
  bool _isProbing = false;
  bool? _probeSuccess;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget.smbService.addListener(_onServiceUpdate);

    // If there is a recent share, pre-fill from newest
    if (widget.smbService.recentShares.isNotEmpty) {
      _applyConfig(widget.smbService.recentShares.first.config);
    }
  }

  @override
  void dispose() {
    widget.smbService.removeListener(_onServiceUpdate);
    _hostController.dispose();
    _portController.dispose();
    _shareController.dispose();
    _subPathController.dispose();
    _domainController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _applyConfig(SmbShareConfig config) {
    _hostController.text = config.host;
    _portController.text = config.port.toString();
    _shareController.text = config.shareName;
    _subPathController.text = config.subPath;
    _domainController.text = config.domain ?? '';
    _userController.text = config.username ?? '';
    _isAnonymous = config.isAnonymous;
    _probeSuccess = null;
    _errorMessage = null;
    setState(() {});
  }

  SmbShareConfig _buildCurrentConfig() {
    final portNum = int.tryParse(_portController.text.trim()) ?? 445;
    return SmbShareConfig(
      host: _hostController.text.trim(),
      port: portNum,
      shareName: _shareController.text.trim(),
      subPath: _subPathController.text.trim(),
      domain: _domainController.text.trim().isNotEmpty ? _domainController.text.trim() : null,
      username: _userController.text.trim().isNotEmpty ? _userController.text.trim() : null,
      password: _passController.text.isNotEmpty ? _passController.text : null,
      isAnonymous: _isAnonymous,
    );
  }

  Future<void> _probeConnection() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a host or IP address to probe';
      });
      return;
    }

    final port = int.tryParse(_portController.text.trim()) ?? 445;
    setState(() {
      _isProbing = true;
      _probeSuccess = null;
      _errorMessage = null;
    });

    final success = await widget.smbService.probeHost(host, port: port);
    if (!mounted) return;

    setState(() {
      _isProbing = false;
      _probeSuccess = success;
      if (!success) {
        _errorMessage = 'Port $port unreachable on $host';
      }
    });
  }

  Future<void> _submitConnect() async {
    final host = _hostController.text.trim();
    final share = _shareController.text.trim();

    if (host.isEmpty) {
      setState(() => _errorMessage = 'Host / IP address cannot be empty');
      return;
    }
    if (share.isEmpty) {
      setState(() => _errorMessage = 'Share folder name cannot be empty');
      return;
    }

    final config = _buildCurrentConfig();
    await widget.smbService.saveRecentShare(config);

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onPlayMrl(config.toMrl());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final config = _buildCurrentConfig();
    final safeMrl = config.toSafeDisplayMrl();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: EDesign.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(EDesign.r16)),
          border: Border.all(color: EDesign.border, width: 1),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: EDesign.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Title Bar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EDesign.primaryCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(EDesign.r8),
                      ),
                      child: const Icon(
                        Icons.lan_rounded,
                        color: EDesign.primaryCyan,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SMB / Windows Network Share',
                            style: TextStyle(
                              color: EDesign.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'VLC smb2.c & dsm LAN Share Ingestion (Ctrl+Shift+M)',
                            style: TextStyle(
                              color: EDesign.textSecondary.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: EDesign.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Recent Shares Chips
                if (widget.smbService.recentShares.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 14, color: EDesign.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Recent Shares',
                        style: TextStyle(
                          color: EDesign.textSecondary.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        key: const Key('smb_clear_history_button'),
                        onPressed: () => widget.smbService.clearRecentShares(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Clear', style: TextStyle(fontSize: 11, color: EDesign.textMuted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: widget.smbService.recentShares.map((recent) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            key: Key('smb_recent_${recent.config.host}_${recent.config.shareName}'),
                            label: Text(recent.config.displayTitle),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: EDesign.primaryCyan,
                              fontFamily: 'Consolas',
                            ),
                            backgroundColor: EDesign.elevatedSurface,
                            side: const BorderSide(color: EDesign.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(EDesign.r8),
                            ),
                            onPressed: () => _applyConfig(recent.config),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Host & Port Fields
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        controller: _hostController,
                        key: const Key('smb_host_input'),
                        label: 'Server Host / IP',
                        hint: 'e.g. 192.168.1.100 or nas.local',
                        icon: Icons.dns_rounded,
                        onChanged: (_) => setState(() => _probeSuccess = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        controller: _portController,
                        key: const Key('smb_port_input'),
                        label: 'Port',
                        hint: '445',
                        icon: Icons.tag_rounded,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() => _probeSuccess = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. Share Name & SubPath Fields
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _shareController,
                        key: const Key('smb_share_input'),
                        label: 'Share Name',
                        hint: 'e.g. Media, Videos, Public',
                        icon: Icons.folder_rounded,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        controller: _subPathController,
                        key: const Key('smb_path_input'),
                        label: 'File / Subpath (Optional)',
                        hint: 'e.g. movies/sample.mkv',
                        icon: Icons.insert_drive_file_rounded,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 6. Anonymous Toggle Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: EDesign.elevatedSurface,
                    borderRadius: BorderRadius.circular(EDesign.r8),
                    border: Border.all(color: EDesign.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.no_accounts_rounded, size: 18, color: EDesign.textSecondary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Anonymous / Guest Login',
                          style: TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        key: const Key('smb_anonymous_switch'),
                        value: _isAnonymous,
                        activeThumbColor: EDesign.primaryCyan,
                        activeTrackColor: EDesign.primaryCyan.withValues(alpha: 0.4),
                        onChanged: (val) {
                          setState(() {
                            _isAnonymous = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 7. Credentials Section (Domain, Username, Password)
                if (!_isAnonymous) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _domainController,
                          key: const Key('smb_domain_input'),
                          label: 'Domain / Workgroup',
                          hint: 'e.g. WORKGROUP',
                          icon: Icons.domain_rounded,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _userController,
                          key: const Key('smb_user_input'),
                          label: 'Username',
                          hint: 'e.g. admin or alice',
                          icon: Icons.person_rounded,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _passController,
                    key: const Key('smb_pass_input'),
                    label: 'Password',
                    hint: 'Share password',
                    icon: Icons.lock_rounded,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: EDesign.textMuted,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],

                // 8. Probe Connectivity Bar
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('smb_probe_button'),
                      onPressed: _isProbing ? null : _probeConnection,
                      icon: _isProbing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: EDesign.primaryCyan),
                            )
                          : const Icon(Icons.wifi_find_rounded, size: 16),
                      label: Text(_isProbing ? 'Probing...' : 'Test Port 445'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EDesign.primaryCyan,
                        side: const BorderSide(color: EDesign.primaryCyan),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EDesign.r8)),
                      ),
                    ),
                    if (_probeSuccess != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _probeSuccess! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 16,
                            color: _probeSuccess! ? EDesign.success : EDesign.danger,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _probeSuccess! ? 'Reachable (Port Open)' : 'Unreachable / Timeout',
                            key: const Key('smb_probe_status'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _probeSuccess! ? EDesign.success : EDesign.danger,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // 9. Error Message
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    key: const Key('smb_error_text'),
                    style: const TextStyle(color: EDesign.danger, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],

                // 10. Live Generated MRL Preview Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EDesign.appBackground,
                    borderRadius: BorderRadius.circular(EDesign.r8),
                    border: Border.all(color: EDesign.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.link_rounded, size: 14, color: EDesign.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Generated VLC MRL',
                            style: TextStyle(
                              fontSize: 11,
                              color: EDesign.textSecondary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        safeMrl,
                        key: const Key('smb_mrl_preview'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: EDesign.primaryCyan,
                          fontFamily: 'Consolas',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 11. Action Buttons
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      key: const Key('smb_cancel_button'),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Cancel', style: TextStyle(color: EDesign.textMuted)),
                    ),
                    ElevatedButton.icon(
                      key: const Key('smb_connect_button'),
                      onPressed: _submitConnect,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Connect & Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EDesign.primaryCyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(EDesign.r8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required Key key,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: EDesign.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          key: key,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: EDesign.textPrimary, fontSize: 13, fontFamily: 'Consolas'),
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(color: EDesign.textMuted.withValues(alpha: 0.6), fontSize: 12),
            prefixIcon: Icon(icon, size: 16, color: EDesign.textMuted),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: EDesign.elevatedSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(EDesign.r8),
              borderSide: const BorderSide(color: EDesign.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(EDesign.r8),
              borderSide: const BorderSide(color: EDesign.primaryCyan),
            ),
          ),
        ),
      ],
    );
  }
}
