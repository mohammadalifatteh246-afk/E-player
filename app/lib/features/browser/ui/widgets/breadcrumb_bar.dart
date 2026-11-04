import 'package:flutter/material.dart';
import '../../../../theme/e_player_colors.dart';
import '../../domain/file_system_service.dart';

/// Responsive horizontal scrolling breadcrumb navigation bar.
class BreadcrumbBar extends StatefulWidget {
  final List<BreadcrumbSegment> segments;
  final ValueChanged<String> onSegmentSelected;

  const BreadcrumbBar({
    super.key,
    required this.segments,
    required this.onSegmentSelected,
  });

  @override
  State<BreadcrumbBar> createState() => _BreadcrumbBarState();
}

class _BreadcrumbBarState extends State<BreadcrumbBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant BreadcrumbBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.segments.length != oldWidget.segments.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: EPlayerColors.backgroundElevated,
        border: Border(
          bottom: BorderSide(color: EPlayerColors.border, width: 1),
        ),
      ),
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.segments.length,
        separatorBuilder: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: EPlayerColors.textMuted,
            ),
          ),
        ),
        itemBuilder: (context, index) {
          final segment = widget.segments[index];
          final isLast = index == widget.segments.length - 1;

          return Center(
            child: InkWell(
              onTap: isLast ? null : () => widget.onSegmentSelected(segment.path),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 0) ...[
                      const Icon(
                        Icons.storage_rounded,
                        size: 15,
                        color: EPlayerColors.primary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      segment.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
                        color: isLast
                            ? EPlayerColors.textPrimary
                            : EPlayerColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
