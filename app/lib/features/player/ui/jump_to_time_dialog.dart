library;

import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../domain/jump_to_time_models.dart';

/// Modal dialog for precision timestamp seeking (VLC `goto_time.cpp` / Ctrl+T parity).
class JumpToTimeDialog extends StatefulWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final void Function(Duration target) onSeek;

  const JumpToTimeDialog({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
  });

  static Future<void> show(
    BuildContext context, {
    required Duration currentPosition,
    required Duration totalDuration,
    required void Function(Duration target) onSeek,
  }) {
    return showDialog(
      context: context,
      builder: (context) => JumpToTimeDialog(
        currentPosition: currentPosition,
        totalDuration: totalDuration,
        onSeek: onSeek,
      ),
    );
  }

  @override
  State<JumpToTimeDialog> createState() => _JumpToTimeDialogState();
}

class _JumpToTimeDialogState extends State<JumpToTimeDialog> {
  final TextEditingController _controller = TextEditingController();
  Duration? _previewTarget;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _previewTarget = null;
        _hasError = false;
      });
      return;
    }

    final parsed = JumpToTimeParser.parse(
      text,
      totalDuration: widget.totalDuration,
      currentPosition: widget.currentPosition,
    );

    setState(() {
      _previewTarget = parsed;
      _hasError = parsed == null;
    });
  }

  void _submit() {
    final target = _previewTarget;
    if (target != null) {
      widget.onSeek(target);
      Navigator.of(context).pop();
    }
  }

  void _applyQuickOffset(String expr) {
    _controller.text = expr;
    _onTextChanged();
  }

  @override
  Widget build(BuildContext context) {
    final currentStr = JumpToTimeParser.format(widget.currentPosition);
    final totalStr = JumpToTimeParser.format(widget.totalDuration);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: EDesign.surface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(EDesign.r24),
          border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.75),
              blurRadius: 32,
              spreadRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header with Icon & Hotkey Badge
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
                    borderRadius: BorderRadius.circular(EDesign.r12),
                    border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    color: EDesign.primaryCyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'JUMP TO TIME',
                        style: TextStyle(
                          color: EDesign.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Current: $currentStr  •  Total: $totalStr',
                        style: const TextStyle(
                          color: EDesign.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: EDesign.elevatedSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: EDesign.border),
                  ),
                  child: const Text(
                    'Ctrl+T',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: EDesign.primaryCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Input Field
            TextField(
              key: const Key('jump_to_time_input'),
              controller: _controller,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: EDesign.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: EDesign.elevatedSurface,
                hintText: 'e.g. 01:23:45, 15m, 50%, +10m',
                hintStyle: const TextStyle(color: EDesign.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.timer_outlined, color: EDesign.primaryCyan, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  borderSide: const BorderSide(color: EDesign.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  borderSide: BorderSide(
                    color: _hasError ? EDesign.danger : EDesign.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  borderSide: BorderSide(
                    color: _hasError ? EDesign.danger : EDesign.primaryCyan,
                    width: 1.5,
                  ),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: 8),

            // Live Target Feedback Preview
            if (_previewTarget != null)
              Text(
                'Target: ${JumpToTimeParser.format(_previewTarget!)}',
                key: const Key('jump_preview_target'),
                style: const TextStyle(
                  color: EDesign.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (_hasError)
              const Text(
                'Invalid timestamp format (use HH:MM:SS, MM:SS, 50% or +10m)',
                key: Key('jump_preview_error'),
                style: TextStyle(color: EDesign.danger, fontSize: 12),
              )
            else
              const SizedBox(height: 14),

            const SizedBox(height: 12),

            // Quick Jump Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildQuickChip('Start', '00:00:00'),
                _buildQuickChip('-10 min', '-10m'),
                _buildQuickChip('+10 min', '+10m'),
                _buildQuickChip('50% (Half)', '50%'),
                _buildQuickChip('End -5 min', '-5m'),
              ],
            ),

            const SizedBox(height: 20),

            // Dialog Actions (Cancel & Jump)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('jump_cancel_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: EDesign.textMuted)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  key: const Key('jump_submit_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.primaryCyan,
                    foregroundColor: EDesign.appBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EDesign.r10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Jump', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _previewTarget == null ? null : _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, String expr) {
    return ActionChip(
      key: Key('quick_jump_$expr'),
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 11, color: EDesign.textPrimary),
      backgroundColor: EDesign.elevatedSurface,
      side: const BorderSide(color: EDesign.border),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      onPressed: () => _applyQuickOffset(expr),
    );
  }
}
