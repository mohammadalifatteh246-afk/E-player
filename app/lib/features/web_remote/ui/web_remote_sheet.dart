import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../data/qr_code_generator.dart';
import '../data/web_remote_service.dart';

/// Modal bottom sheet allowing users to view the Web Remote URL,
/// scan the generated Cyberpunk QR Code, and start/stop the remote server.
class WebRemoteSheet extends StatefulWidget {
  final WebRemoteService service;

  const WebRemoteSheet({super.key, required this.service});

  static Future<void> show(BuildContext context, WebRemoteService service) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => WebRemoteSheet(service: service),
    );
  }

  @override
  State<WebRemoteSheet> createState() => _WebRemoteSheetState();
}

class _WebRemoteSheetState extends State<WebRemoteSheet> {
  late bool _isRunning;
  String _currentUrl = '';
  List<List<bool>> _qrMatrix = [];
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _isRunning = widget.service.isRunning;
    _currentUrl = widget.service.url;
    _generateQr();
  }

  void _generateQr() {
    if (_isRunning && _currentUrl.isNotEmpty) {
      _qrMatrix = QrCodeGenerator.generateMatrix(_currentUrl);
    } else {
      _qrMatrix = [];
    }
  }

  Future<void> _toggleServer(bool value) async {
    if (value) {
      final success = await widget.service.start();
      if (mounted) {
        setState(() {
          _isRunning = success;
          _currentUrl = widget.service.url;
          _generateQr();
        });
      }
    } else {
      await widget.service.stop();
      if (mounted) {
        setState(() {
          _isRunning = false;
          _qrMatrix = [];
        });
      }
    }
  }

  void _copyUrl() {
    if (_currentUrl.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _currentUrl));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: EDesign.surface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EDesign.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.phonelink_rounded, color: EDesign.primaryCyan, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Web Remote Control',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isRunning ? 'Active on port ${widget.service.port}' : 'Server stopped',
                      style: const TextStyle(
                        color: EDesign.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_isRunning ? EDesign.success : EDesign.textMuted).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isRunning ? EDesign.success : EDesign.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRunning ? EDesign.success : EDesign.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isRunning ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        color: _isRunning ? EDesign.success : EDesign.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // QR Code Card or Inactive placeholder
          if (_isRunning && _qrMatrix.isNotEmpty)
            Center(
              child: Container(
                key: const Key('web_remote_qr_container'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EDesign.appBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: EDesign.primaryCyan.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CustomPaint(
                  size: const Size(200, 200),
                  painter: QrCodePainter(
                    matrix: _qrMatrix,
                    moduleColor: EDesign.primaryCyan,
                    backgroundColor: EDesign.appBackground,
                    padding: 8,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: EDesign.appBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: EDesign.border),
              ),
              child: const Center(
                child: Text(
                  'Web Remote is turned off.\nToggle below to activate Wi-Fi remote.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: EDesign.textSecondary, fontSize: 13),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Wi-Fi URL Box
          if (_isRunning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: EDesign.elevatedBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EDesign.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_rounded, color: EDesign.primaryCyan, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentUrl,
                      style: const TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('web_remote_copy_button'),
                    icon: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 16,
                      color: _copied ? EDesign.success : EDesign.primaryCyan,
                    ),
                    label: Text(
                      _copied ? 'Copied' : 'Copy',
                      style: TextStyle(
                        color: _copied ? EDesign.success : EDesign.primaryCyan,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: _copyUrl,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Instructions & Toggle Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Scan with any phone camera on this Wi-Fi network.',
                  style: TextStyle(color: EDesign.textMuted, fontSize: 12),
                ),
              ),
              Switch(
                key: const Key('web_remote_toggle_switch'),
                value: _isRunning,
                activeThumbColor: EDesign.primaryCyan,
                activeTrackColor: EDesign.primaryCyan.withValues(alpha: 0.4),
                onChanged: _toggleServer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
