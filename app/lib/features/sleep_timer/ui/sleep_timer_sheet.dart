import 'package:flutter/material.dart';
import '../models/sleep_timer_models.dart';
import '../data/sleep_timer_controller.dart';

/// Modal bottom sheet for configuring sleep countdowns, power management,
/// and smooth audio fade-out (VLC sleep timer parity).
class SleepTimerSheet extends StatefulWidget {
  final SleepTimerController controller;

  const SleepTimerSheet({
    super.key,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required SleepTimerController controller,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SleepTimerSheet(controller: controller),
    );
  }

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  int _selectedMinutes = 30;
  bool _atEndOfTrack = false;
  SleepTimerAction _selectedAction = SleepTimerAction.pausePlayback;
  bool _smoothFadeOut = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    if (widget.controller.isActive) {
      _selectedAction = widget.controller.state.action;
      _smoothFadeOut = widget.controller.state.smoothFadeOut;
      _atEndOfTrack = widget.controller.state.atEndOfTrack;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _startTimer() {
    if (_atEndOfTrack) {
      widget.controller.startEndOfTrackTimer(
        action: _selectedAction,
        smoothFadeOut: _smoothFadeOut,
      );
    } else {
      widget.controller.startTimer(
        duration: Duration(minutes: _selectedMinutes),
        action: _selectedAction,
        smoothFadeOut: _smoothFadeOut,
      );
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = widget.controller.isActive;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            _buildHeader(theme),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isActive) ...[
                      _buildActiveBannerCard(theme),
                      const SizedBox(height: 16),
                    ],
                    _buildPresetSection(theme),
                    const SizedBox(height: 16),
                    _buildActionSection(theme),
                    const SizedBox(height: 16),
                    _buildOptionsSection(theme),
                    const SizedBox(height: 20),
                    _buildStartButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.bedtime_rounded, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sleep Timer & Power Manager',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'VLC Parity • Auto-pause, Quit E-Player, PC Sleep/Shutdown',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('sleep_timer_close_button'),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBannerCard(ThemeData theme) {
    final state = widget.controller.state;

    return Card(
      color: Colors.cyanAccent.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.cyanAccent, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Active: ${state.formattedRemaining}',
                      key: const Key('sleep_timer_active_countdown_text'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ],
                ),
                Text(
                  state.action.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.progress.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Colors.white12,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  key: const Key('sleep_timer_extend_10m_btn'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+10 Min'),
                  onPressed: () => widget.controller.extendTimer(const Duration(minutes: 10)),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  key: const Key('sleep_timer_cancel_btn'),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel Timer'),
                  style: FilledButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: () => widget.controller.cancelTimer(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSection(ThemeData theme) {
    const presets = [15, 30, 45, 60, 90, 120];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Timer Duration',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...presets.map((min) {
              final isSelected = !_atEndOfTrack && _selectedMinutes == min;
              return ChoiceChip(
                key: Key('sleep_timer_preset_$min'),
                label: Text('$min min'),
                selected: isSelected,
                selectedColor: Colors.cyanAccent.withValues(alpha: 0.25),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedMinutes = min;
                      _atEndOfTrack = false;
                    });
                  }
                },
              );
            }),
            ChoiceChip(
              key: const Key('sleep_timer_preset_end_of_track'),
              label: const Text('End of Track'),
              selected: _atEndOfTrack,
              selectedColor: Colors.amberAccent.withValues(alpha: 0.25),
              onSelected: (val) {
                if (val) {
                  setState(() => _atEndOfTrack = true);
                }
              },
            ),
          ],
        ),
        if (!_atEndOfTrack) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _selectedMinutes.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  label: '$_selectedMinutes min',
                  onChanged: (val) {
                    setState(() {
                      _selectedMinutes = val.round();
                      _atEndOfTrack = false;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '$_selectedMinutes min',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When Timer Expires',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 8),
        ...SleepTimerAction.values.map((action) {
          final isSelected = _selectedAction == action;
          return Card(
            color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected ? Colors.cyanAccent : Colors.white10,
                width: isSelected ? 1.2 : 0.8,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              key: Key('sleep_timer_action_${action.name}'),
              dense: true,
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? Colors.cyanAccent : Colors.white54,
                size: 20,
              ),
              title: Text(action.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(action.description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              onTap: () => setState(() => _selectedAction = action),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOptionsSection(ThemeData theme) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        key: const Key('sleep_timer_fade_switch'),
        title: const Text('Smooth Audio Fade-Out', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: const Text('Gradually reduces sound volume during the final 30 seconds', style: TextStyle(color: Colors.white54, fontSize: 11)),
        value: _smoothFadeOut,
        activeThumbColor: Colors.cyanAccent,
        onChanged: (val) => setState(() => _smoothFadeOut = val),
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        key: const Key('sleep_timer_start_button'),
        icon: const Icon(Icons.play_circle_fill_rounded),
        label: Text(
          _atEndOfTrack ? 'Set Timer (At End of Track)' : 'Start Sleep Timer ($_selectedMinutes min)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: _startTimer,
      ),
    );
  }
}
