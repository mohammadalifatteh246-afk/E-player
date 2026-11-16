import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../data/subtitle_sync_calculator.dart';
import '../models/subtitle_sync_models.dart';

/// Modal bottom sheet providing a 2-Point Subtitle Synchronization wizard (VLC subsync paradigm).
///
/// Enables precision AV dialogue alignment and frame-rate drift correction (e.g. PAL 25fps to Film 23.976fps).
class SubtitleAutoSyncSheet extends StatefulWidget {
  final Player? player;
  final double currentDelay;
  final double currentSpeed;
  final void Function(double delaySeconds, double speedFactor) onApply;
  final VoidCallback? onReset;

  const SubtitleAutoSyncSheet({
    super.key,
    this.player,
    this.currentDelay = 0.0,
    this.currentSpeed = 1.0,
    required this.onApply,
    this.onReset,
  });

  @override
  State<SubtitleAutoSyncSheet> createState() => _SubtitleAutoSyncSheetState();
}

class _SubtitleAutoSyncSheetState extends State<SubtitleAutoSyncSheet> {
  // Point 1 (Anchor)
  Duration _p1Audio = Duration.zero;
  Duration _p1Sub = Duration.zero;

  // Point 2 (Drift Correction)
  bool _enablePoint2 = true;
  Duration _p2Audio = const Duration(minutes: 10);
  Duration _p2Sub = const Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    final pos = widget.player?.state.position ?? Duration.zero;
    _p1Audio = pos;
    // By default, assume current subtitle offset: sub = audio - currentDelay
    final currentOffsetMicros = (widget.currentDelay * 1e6).round();
    _p1Sub = Duration(
      microseconds: (_p1Audio.inMicroseconds - currentOffsetMicros).clamp(0, 86400000000),
    );

    // Initial point 2 estimate: 10 minutes later (or 5 minutes later)
    _p2Audio = _p1Audio + const Duration(minutes: 10);
    _p2Sub = _p1Sub + const Duration(minutes: 10);
  }

  SubtitleSyncResult _computeResult() {
    final p1 = SubtitleSyncPoint(
      audioTime: _p1Audio,
      subtitleTime: _p1Sub,
      label: 'Anchor 1',
    );

    final p2 = _enablePoint2
        ? SubtitleSyncPoint(
            audioTime: _p2Audio,
            subtitleTime: _p2Sub,
            label: 'Anchor 2',
          )
        : null;

    return SubtitleSyncCalculator.calculate(point1: p1, point2: p2);
  }

  void _captureCurrentPosition(bool isAudio, int pointNum) {
    final currentPos = widget.player?.state.position ?? Duration.zero;
    setState(() {
      if (pointNum == 1) {
        if (isAudio) {
          _p1Audio = currentPos;
        } else {
          _p1Sub = currentPos;
        }
      } else {
        if (isAudio) {
          _p2Audio = currentPos;
        } else {
          _p2Sub = currentPos;
        }
      }
    });
  }

  void _nudge(bool isAudio, int pointNum, Duration delta) {
    setState(() {
      if (pointNum == 1) {
        if (isAudio) {
          _p1Audio = _clampDuration(_p1Audio + delta);
        } else {
          _p1Sub = _clampDuration(_p1Sub + delta);
        }
      } else {
        if (isAudio) {
          _p2Audio = _clampDuration(_p2Audio + delta);
        } else {
          _p2Sub = _clampDuration(_p2Sub + delta);
        }
      }
    });
  }

  Duration _clampDuration(Duration d) {
    if (d.isNegative) return Duration.zero;
    return d;
  }

  static String _formatDuration(Duration d) {
    final negative = d.isNegative;
    final abs = d.abs();
    final hours = abs.inHours;
    final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (abs.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (abs.inMilliseconds % 1000).toString().padLeft(3, '0');
    final sign = negative ? '-' : '';
    if (hours > 0) {
      return '$sign${hours.toString().padLeft(2, '0')}:$minutes:$seconds.$millis';
    }
    return '$sign$minutes:$seconds.$millis';
  }

  @override
  Widget build(BuildContext context) {
    final result = _computeResult();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(EDesign.r24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: EDesign.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: EDesign.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(EDesign.r10),
                ),
                child: const Icon(Icons.auto_fix_high, color: EDesign.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2-Point Subtitle Auto-Sync',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'VLC subsync algorithm: Speech offset & framerate drift alignment',
                      style: TextStyle(color: EDesign.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: EDesign.textMuted, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable Points and Calculation Area
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EDesign.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(EDesign.r12),
                    border: Border.all(
                      color: EDesign.primary.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: EDesign.primary, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Point 1 fixes constant sync shift. Point 2 (later in the media) calculates '
                          'and corrects gradual framerate stretch/drift (PAL 25fps to Film 23.976fps).',
                          style: TextStyle(color: EDesign.textSecondary, fontSize: 11.5, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Anchor Point 1
                _buildPointCard(
                  pointNum: 1,
                  title: 'Point 1: Reference Anchor',
                  subtitle: 'Early dialogue scene in the media',
                  audioTime: _p1Audio,
                  subTime: _p1Sub,
                ),
                const SizedBox(height: 14),

                // Anchor Point 2 (Drift Correction)
                _buildPoint2Card(),
                const SizedBox(height: 14),

                // Real-time calculation summary card
                _buildResultSummaryCard(result),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Action buttons at bottom
          Row(
            children: [
              if (widget.onReset != null) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EDesign.textMuted,
                    side: const BorderSide(color: EDesign.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset', style: TextStyle(fontSize: 13)),
                  onPressed: () {
                    widget.onReset!();
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EDesign.r12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text(
                    'Apply Sync to Subtitles',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    widget.onApply(result.delaySeconds, result.speedFactor);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointCard({
    required int pointNum,
    required String title,
    required String subtitle,
    required Duration audioTime,
    required Duration subTime,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedBackground,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: EDesign.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: EDesign.primary.withValues(alpha: 0.2),
                child: Text(
                  '$pointNum',
                  style: const TextStyle(
                    color: EDesign.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: EDesign.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Speech Audio Row
          _buildTimeField(
            label: 'Spoken Dialogue Audio Time',
            icon: Icons.record_voice_over_outlined,
            time: audioTime,
            isAudio: true,
            pointNum: pointNum,
          ),
          const SizedBox(height: 10),

          // Subtitle Displayed Row
          _buildTimeField(
            label: 'Subtitle Line Rendered Time',
            icon: Icons.subtitles_outlined,
            time: subTime,
            isAudio: false,
            pointNum: pointNum,
          ),
        ],
      ),
    );
  }

  Widget _buildPoint2Card() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedBackground,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(
          color: _enablePoint2 ? EDesign.primary.withValues(alpha: 0.4) : EDesign.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: _enablePoint2
                    ? EDesign.primary.withValues(alpha: 0.2)
                    : EDesign.border,
                child: Text(
                  '2',
                  style: TextStyle(
                    color: _enablePoint2 ? EDesign.primary : EDesign.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Point 2: Drift Correction (Later Scene)',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Corrects subtitles getting progressively out-of-sync',
                      style: TextStyle(color: EDesign.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _enablePoint2,
                activeThumbColor: EDesign.primary,
                activeTrackColor: EDesign.primary.withValues(alpha: 0.5),
                onChanged: (val) => setState(() => _enablePoint2 = val),
              ),
            ],
          ),
          if (_enablePoint2) ...[
            const SizedBox(height: 12),
            _buildTimeField(
              label: 'Spoken Dialogue Audio Time',
              icon: Icons.record_voice_over_outlined,
              time: _p2Audio,
              isAudio: true,
              pointNum: 2,
            ),
            const SizedBox(height: 10),
            _buildTimeField(
              label: 'Subtitle Line Rendered Time',
              icon: Icons.subtitles_outlined,
              time: _p2Sub,
              isAudio: false,
              pointNum: 2,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required IconData icon,
    required Duration time,
    required bool isAudio,
    required int pointNum,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r10),
        border: Border.all(color: EDesign.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: EDesign.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: EDesign.textSecondary, fontSize: 11),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _captureCurrentPosition(isAudio, pointNum),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: EDesign.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location, color: EDesign.primary, size: 11),
                      SizedBox(width: 4),
                      Text(
                        'Use Current Time',
                        style: TextStyle(
                          color: EDesign.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _formatDuration(time),
                style: const TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              _buildSmallNudge('-1s', () => _nudge(isAudio, pointNum, const Duration(seconds: -1))),
              const SizedBox(width: 4),
              _buildSmallNudge('-100ms', () => _nudge(isAudio, pointNum, const Duration(milliseconds: -100))),
              const SizedBox(width: 4),
              _buildSmallNudge('+100ms', () => _nudge(isAudio, pointNum, const Duration(milliseconds: 100))),
              const SizedBox(width: 4),
              _buildSmallNudge('+1s', () => _nudge(isAudio, pointNum, const Duration(seconds: 1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallNudge(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: EDesign.elevatedBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: EDesign.border, width: 0.6),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: EDesign.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildResultSummaryCard(SubtitleSyncResult result) {
    final statusColor = result.hasDriftCorrection ? EDesign.success : EDesign.primary;
    final driftLabel = result.hasDriftCorrection
        ? '2-Point Drift Aligned'
        : '1-Point Constant Offset';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EDesign.elevatedSurface,
        borderRadius: BorderRadius.circular(EDesign.r16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Calculated Sync Output',
                style: TextStyle(
                  color: EDesign.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  driftLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Delay Offset',
                  value: '${result.delaySeconds >= 0 ? '+' : ''}${result.delaySeconds.toStringAsFixed(3)}s',
                  icon: Icons.timer_outlined,
                  color: EDesign.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'Subtitle Speed',
                  value: '${result.speedFactor.toStringAsFixed(4)}x',
                  icon: Icons.speed,
                  color: result.hasDriftCorrection ? EDesign.success : EDesign.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EDesign.surface,
        borderRadius: BorderRadius.circular(EDesign.r10),
        border: Border.all(color: EDesign.border, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: EDesign.textMuted, fontSize: 10),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
