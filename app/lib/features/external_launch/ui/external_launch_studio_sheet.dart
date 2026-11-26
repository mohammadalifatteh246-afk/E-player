import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ui/theme/e_design_tokens.dart';
import '../data/external_launch_service.dart';
import '../domain/external_launch_models.dart';

/// Cyberpunk Modal Studio Sheet for OS File Associations, Android ACTION_VIEW Intents,
/// Windows CLI Single-Instance IPC, and Live External Launch Testing.
class ExternalLaunchStudioSheet extends StatefulWidget {
  final ExternalLaunchService? service;

  const ExternalLaunchStudioSheet({
    super.key,
    this.service,
  });

  static Future<void> show(
    BuildContext context, {
    ExternalLaunchService? service,
  }) {
    final effective = service ?? context.read<ExternalLaunchService>();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ExternalLaunchStudioSheet(service: effective),
    );
  }

  @override
  State<ExternalLaunchStudioSheet> createState() =>
      _ExternalLaunchStudioSheetState();
}

class _ExternalLaunchStudioSheetState extends State<ExternalLaunchStudioSheet> {
  ExternalLaunchService? _service;
  final TextEditingController _testController = TextEditingController();
  String? _statusMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = widget.service ?? ExternalLaunchService.instance;
    if (_service != next) {
      _service?.removeListener(_onServiceUpdated);
      _service = next;
      _service?.addListener(_onServiceUpdated);
    }
  }

  @override
  void dispose() {
    _service?.removeListener(_onServiceUpdated);
    _testController.dispose();
    super.dispose();
  }

  void _onServiceUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _handleRegisterAssoc(ExternalLaunchService service) async {
    final ok = await service.registerWindowsFileAssociations(
      customExePath: null,
    );
    if (!mounted) return;
    setState(() {
      _statusMessage = ok
          ? 'Registered E-Player with Windows "Open With" (HKCU) cleanly.'
          : 'Registry registration only applies on Windows desktop.';
    });
  }

  Future<void> _handleUnregisterAssoc(ExternalLaunchService service) async {
    final ok = await service.unregisterWindowsFileAssociations();
    if (!mounted) return;
    setState(() {
      _statusMessage = ok
          ? 'Removed per-user Windows file associations cleanly.'
          : 'Registry cleanup skipped on this platform.';
    });
  }

  void _runSimulatedLaunch(ExternalLaunchService service) {
    final raw = _testController.text.trim();
    if (raw.isEmpty) return;
    final req = service.triggerSimulatedLaunch(
      raw,
      sourcePlatform: 'studio_simulator',
    );
    if (req == null) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _service ?? ExternalLaunchService.instance;
    final diag = service.getDiagnostics();
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
          border:
              Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.78),
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
                  // Drag handle
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
                          Icons.rocket_launch_rounded,
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
                              'External Launch & OS Studio',
                              style: TextStyle(
                                color: EDesign.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Android ACTION_VIEW Intents & Windows CLI Single-Instance',
                              style: TextStyle(
                                color: EDesign.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('ext_studio_close_btn'),
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

                  // 1. OS Integration Diagnostics Strip
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDiagPill(
                        icon: Icons.android_rounded,
                        label: 'Android ACTION_VIEW: Ready',
                        color: EDesign.success,
                        key: const Key('ext_diag_android'),
                      ),
                      _buildDiagPill(
                        icon: Icons.terminal_rounded,
                        label: 'Windows CLI & IPC: Ready',
                        color: EDesign.primaryCyan,
                        key: const Key('ext_diag_windows'),
                      ),
                      _buildDiagPill(
                        icon: Icons.app_registration_rounded,
                        label: diag.windowsFileAssociationRegistered
                            ? 'Open With: Registered'
                            : 'Open With: Stand-By',
                        color: diag.windowsFileAssociationRegistered
                            ? EDesign.success
                            : EDesign.warning,
                        key: const Key('ext_diag_assoc'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Launch Behavior & Single-Instance Toggles
                  const Text(
                    'LAUNCH & SINGLE-INSTANCE ENGINE',
                    style: TextStyle(
                      color: EDesign.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                          key: const Key('ext_studio_single_instance_switch'),
                          dense: true,
                          title: const Text(
                            'Single-Instance IPC Mode',
                            style: TextStyle(
                              color: EDesign.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Route new external files into existing player window (WM_COPYDATA / singleTop)',
                            style: TextStyle(
                                color: EDesign.textMuted, fontSize: 11),
                          ),
                          value: service.singleInstanceMode,
                          activeThumbColor: EDesign.primaryCyan,
                          onChanged: (val) =>
                              service.setSingleInstanceMode(val),
                        ),
                        const Divider(color: EDesign.border, height: 1),
                        SwitchListTile(
                          key: const Key('ext_studio_autoplay_streams_switch'),
                          dense: true,
                          title: const Text(
                            'Auto-Play External Stream URLs',
                            style: TextStyle(
                              color: EDesign.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Launch HTTP, RTSP, HLS & SMB links immediately when opened outside app',
                            style: TextStyle(
                                color: EDesign.textMuted, fontSize: 11),
                          ),
                          value: service.autoPlayStreams,
                          activeThumbColor: EDesign.primaryCyan,
                          onChanged: (val) => service.setAutoPlayStreams(val),
                        ),
                        const Divider(color: EDesign.border, height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'When Already Playing a Video',
                                style: TextStyle(
                                  color: EDesign.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    key: const Key('ext_behavior_play_now'),
                                    label: const Text('Play Immediately'),
                                    selected: service.warmLaunchBehavior ==
                                        WarmLaunchBehavior.playImmediately,
                                    onSelected: (_) =>
                                        service.setWarmLaunchBehavior(
                                            WarmLaunchBehavior.playImmediately),
                                    selectedColor: EDesign.primaryCyan,
                                    backgroundColor: EDesign.elevatedSurface,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: service.warmLaunchBehavior ==
                                              WarmLaunchBehavior
                                                  .playImmediately
                                          ? Colors.black
                                          : EDesign.textPrimary,
                                    ),
                                  ),
                                  ChoiceChip(
                                    key: const Key('ext_behavior_enqueue'),
                                    label: const Text('Enqueue to Playlist'),
                                    selected: service.warmLaunchBehavior ==
                                        WarmLaunchBehavior.enqueueToPlaylist,
                                    onSelected: (_) =>
                                        service.setWarmLaunchBehavior(
                                            WarmLaunchBehavior
                                                .enqueueToPlaylist),
                                    selectedColor: EDesign.primaryCyan,
                                    backgroundColor: EDesign.elevatedSurface,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: service.warmLaunchBehavior ==
                                              WarmLaunchBehavior
                                                  .enqueueToPlaylist
                                          ? Colors.black
                                          : EDesign.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Windows Explorer "Open With" Association Card
                  const Text(
                    'WINDOWS EXPLORER "OPEN WITH" INTEGRATION',
                    style: TextStyle(
                      color: EDesign.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: EDesign.elevatedSurface,
                      borderRadius: BorderRadius.circular(EDesign.r12),
                      border: Border.all(color: EDesign.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supported Extensions (${diag.registeredExtensions.length}): ${diag.registeredExtensions.take(8).join(', ')}...',
                          style: const TextStyle(
                            color: EDesign.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              key: const Key('ext_studio_register_btn'),
                              onPressed: service.isBusyUpdatingRegistry
                                  ? null
                                  : () => _handleRegisterAssoc(service),
                              icon: const Icon(Icons.link_rounded, size: 16),
                              label: Text(
                                service.isBusyUpdatingRegistry
                                    ? 'Updating...'
                                    : 'Register Windows Open-With',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: EDesign.primaryCyan,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(EDesign.r8),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const Key('ext_studio_unregister_btn'),
                              onPressed: service.isBusyUpdatingRegistry
                                  ? null
                                  : () => _handleUnregisterAssoc(service),
                              icon: const Icon(Icons.link_off_rounded,
                                  size: 16),
                              label: const Text('Unregister'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: EDesign.textSecondary,
                                side: const BorderSide(color: EDesign.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(EDesign.r8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage!,
                            key: const Key('ext_studio_status_msg'),
                            style: const TextStyle(
                              color: EDesign.primaryCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Live External Launch Simulator / CLI Tester
                  const Text(
                    'TEST EXTERNAL FILE OR URI LAUNCH',
                    style: TextStyle(
                      color: EDesign.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('ext_studio_test_input'),
                          controller: _testController,
                          style: const TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 12,
                            fontFamily: 'Consolas',
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText:
                                r'e.g. D:\Movies\film.mkv or rtsp://...',
                            hintStyle: TextStyle(
                              color: EDesign.textMuted.withValues(alpha: 0.65),
                              fontSize: 11,
                            ),
                            filled: true,
                            fillColor: EDesign.elevatedSurface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(EDesign.r8),
                              borderSide:
                                  const BorderSide(color: EDesign.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(EDesign.r8),
                              borderSide:
                                  const BorderSide(color: EDesign.primaryCyan),
                            ),
                          ),
                          onSubmitted: (_) => _runSimulatedLaunch(service),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        key: const Key('ext_studio_test_btn'),
                        onPressed: () => _runSimulatedLaunch(service),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Launch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EDesign.success,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(EDesign.r8),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 5. Recent External Launch History
                  if (service.history.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          'INCOMING LAUNCH LOG',
                          style: TextStyle(
                            color: EDesign.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          key: const Key('ext_studio_clear_log_btn'),
                          onPressed: service.clearHistory,
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                                color: EDesign.textMuted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    ...service.history.take(5).map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: EDesign.elevatedBackground,
                            borderRadius: BorderRadius.circular(EDesign.r8),
                            border: Border.all(color: EDesign.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: EDesign.primaryCyan
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.kindBadgeLabel,
                                  style: const TextStyle(
                                    color: EDesign.primaryCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.displayName,
                                      style: const TextStyle(
                                        color: EDesign.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${item.sourcePlatform} • ${item.uri}',
                                      style: const TextStyle(
                                        color: EDesign.textMuted,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagPill({
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
}
