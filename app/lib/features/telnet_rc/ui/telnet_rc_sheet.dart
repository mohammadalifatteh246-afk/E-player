import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../domain/telnet_rc_models.dart';
import '../data/telnet_rc_service.dart';

/// Cyberpunk Modal Sheet for Telnet / TCP Socket CLI Remote Control (VLC rc.c Parity).
/// Provides live server status, CRT matrix console log, and an interactive command bar.
class TelnetRcSheet extends StatefulWidget {
  final TelnetRcService service;

  const TelnetRcSheet({super.key, required this.service});

  static Future<void> show(BuildContext context, TelnetRcService service) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TelnetRcSheet(service: service),
    );
  }

  @override
  State<TelnetRcSheet> createState() => _TelnetRcSheetState();
}

class _TelnetRcSheetState extends State<TelnetRcSheet> {
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceUpdate);
    _cmdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleServer(bool start) async {
    if (start) {
      await widget.service.start();
    } else {
      await widget.service.stop();
    }
    if (mounted) setState(() {});
  }

  void _submitCommand() {
    final text = _cmdController.text.trim();
    if (text.isEmpty) return;
    _cmdController.clear();
    widget.service.executeCommand(text);
  }

  void _executeQuickCommand(String cmd) {
    widget.service.executeCommand(cmd);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.service.status;
    final isOnline = status.isRunning;
    final logs = widget.service.logs;
    final connectCmd = 'nc ${status.host} ${status.port}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: EDesign.surface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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

            // Header Row: Icon, Title, and Server Toggle Switch
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
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOnline ? EDesign.primaryCyan : EDesign.border,
                    ),
                  ),
                  child: Icon(
                    Icons.terminal_rounded,
                    color: isOnline ? EDesign.primaryCyan : EDesign.textMuted,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CLI REMOTE CONTROL',
                        style: TextStyle(
                          color: EDesign.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? EDesign.success : EDesign.textMuted,
                              boxShadow: isOnline
                                  ? [
                                      BoxShadow(
                                        color: EDesign.success.withValues(alpha: 0.6),
                                        blurRadius: 6,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline
                                ? 'ONLINE • ${status.host}:${status.port} (${widget.service.activeClientsCount} connected)'
                                : 'OFFLINE • Port ${status.port}',
                            style: TextStyle(
                              color: isOnline ? EDesign.success : EDesign.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const Key('telnet_server_toggle'),
                  value: isOnline,
                  activeThumbColor: EDesign.primaryCyan,
                  activeTrackColor: EDesign.primaryCyan.withValues(alpha: 0.3),
                  onChanged: _toggleServer,
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: EDesign.border, height: 1),
            const SizedBox(height: 12),

            // Connection Command Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: EDesign.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EDesign.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.code_rounded, color: EDesign.primaryCyan, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isOnline ? connectCmd : 'Start server to connect via Telnet / Netcat',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: isOnline ? EDesign.textPrimary : EDesign.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isOnline)
                    IconButton(
                      key: const Key('copy_telnet_cmd_button'),
                      icon: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        color: _copied ? EDesign.success : EDesign.primaryCyan,
                        size: 18,
                      ),
                      tooltip: 'Copy command',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: connectCmd));
                        setState(() => _copied = true);
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _copied = false);
                        });
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Section Header: Terminal Logs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CRT TERMINAL LOG MONITOR',
                  style: TextStyle(
                    color: EDesign.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                TextButton.icon(
                  key: const Key('clear_terminal_logs_button'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: EDesign.textMuted,
                  ),
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text('Clear Log', style: TextStyle(fontSize: 11)),
                  onPressed: widget.service.clearLogs,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Terminal Viewport
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOnline
                        ? EDesign.primaryCyan.withValues(alpha: 0.4)
                        : EDesign.border,
                  ),
                ),
                child: logs.isEmpty
                    ? Center(
                        child: Text(
                          isOnline
                              ? 'Waiting for commands on port ${status.port}...\nType a command below or connect via `$connectCmd`'
                              : 'Telnet Server is stopped. Toggle switch above to start.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: EDesign.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          Color logColor;
                          String prefix;

                          switch (log.direction) {
                            case TelnetLogDirection.incoming:
                              logColor = EDesign.primaryCyan;
                              prefix = '> ';
                              break;
                            case TelnetLogDirection.outgoing:
                              logColor = const Color(0xFF64FFDA);
                              prefix = '  ';
                              break;
                            case TelnetLogDirection.system:
                              logColor = const Color(0xFFFFD166);
                              prefix = '# ';
                              break;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${log.formattedTime} $prefix${log.text}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: logColor,
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 10),

            // Quick 1-Tap Command Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickChip('status'),
                  _buildQuickChip('pause'),
                  _buildQuickChip('seek +30'),
                  _buildQuickChip('seek -15'),
                  _buildQuickChip('volume 150'),
                  _buildQuickChip('volup'),
                  _buildQuickChip('step'),
                  _buildQuickChip('help'),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Command Input Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('telnet_cmd_input'),
                    controller: _cmdController,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: EDesign.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      prefixText: '> ',
                      prefixStyle: const TextStyle(
                        fontFamily: 'monospace',
                        color: EDesign.primaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                      hintText: 'Enter command (e.g. status, seek +30, volume 150)...',
                      hintStyle: const TextStyle(color: EDesign.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: EDesign.elevatedSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: EDesign.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: EDesign.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: EDesign.primaryCyan),
                      ),
                    ),
                    onSubmitted: (_) => _submitCommand(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('telnet_cmd_send_button'),
                  style: IconButton.styleFrom(
                    backgroundColor: EDesign.primaryCyan,
                    foregroundColor: EDesign.appBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 20),
                  onPressed: _submitCommand,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String cmd) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        key: Key('quick_chip_$cmd'),
        label: Text(cmd),
        labelStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: EDesign.primaryCyan,
        ),
        backgroundColor: EDesign.elevatedSurface,
        side: BorderSide(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        onPressed: () => _executeQuickCommand(cmd),
      ),
    );
  }
}
