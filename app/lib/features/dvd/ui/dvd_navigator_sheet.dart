import 'package:flutter/material.dart';
import '../../../../ui/theme/e_design_tokens.dart';
import '../domain/dvd_models.dart';

/// Cyberpunk Modal Sheet for DVD Title & Chapter Navigation (VLC dvdnav.c parity).
class DvdNavigatorSheet extends StatefulWidget {
  final DvdMediaInfo dvdInfo;
  final ValueChanged<DvdTitle> onSelectTitle;
  final ValueChanged<DvdChapter> onSeekToChapter;

  const DvdNavigatorSheet({
    super.key,
    required this.dvdInfo,
    required this.onSelectTitle,
    required this.onSeekToChapter,
  });

  static Future<void> show(
    BuildContext context, {
    required DvdMediaInfo dvdInfo,
    required ValueChanged<DvdTitle> onSelectTitle,
    required ValueChanged<DvdChapter> onSeekToChapter,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DvdNavigatorSheet(
        dvdInfo: dvdInfo,
        onSelectTitle: onSelectTitle,
        onSeekToChapter: onSeekToChapter,
      ),
    );
  }

  @override
  State<DvdNavigatorSheet> createState() => _DvdNavigatorSheetState();
}

class _DvdNavigatorSheetState extends State<DvdNavigatorSheet> {
  late DvdMediaInfo _dvdInfo;

  @override
  void initState() {
    super.initState();
    _dvdInfo = widget.dvdInfo;
  }

  @override
  Widget build(BuildContext context) {
    final currentTitle = _dvdInfo.currentTitle;
    final chapters = currentTitle?.chapters ?? [];
    final audioTracks = currentTitle?.audioTracks ?? [];
    final subTracks = currentTitle?.subtitleTracks ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
        child: SingleChildScrollView(
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

              // Disc Header
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
                      border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.album_rounded, color: EDesign.primaryCyan, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _dvdInfo.volumeLabel,
                                style: const TextStyle(
                                  color: EDesign.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: EDesign.primaryCyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: EDesign.primaryCyan.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                _dvdInfo.sourceType.label,
                                style: const TextStyle(color: EDesign.primaryCyan, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total Duration: ${_dvdInfo.formattedTotalDuration} • ${_dvdInfo.titles.length} Title(s)',
                          style: const TextStyle(color: EDesign.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // SECTION 1: TITLE SELECTOR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DVD TITLES (VTS)',
                    style: TextStyle(
                      color: EDesign.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (currentTitle != null && currentTitle.isMainFeature)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: EDesign.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: EDesign.warning.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'MAIN FEATURE',
                        style: TextStyle(color: EDesign.warning, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dvdInfo.titles.map((title) {
                  final isSelected = title.titleIndex == _dvdInfo.selectedTitleIndex;
                  return ChoiceChip(
                    key: Key('dvd_title_chip_${title.titleIndex}'),
                    avatar: Icon(
                      title.isMainFeature ? Icons.movie_filter_rounded : Icons.video_collection_rounded,
                      size: 16,
                      color: isSelected ? EDesign.primaryCyan : EDesign.textMuted,
                    ),
                    label: Text('Title ${title.titleIndex} (${title.formattedDuration})'),
                    selected: isSelected,
                    selectedColor: EDesign.primaryCyan.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      color: isSelected ? EDesign.primaryCyan : EDesign.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _dvdInfo.selectedTitleIndex = title.titleIndex;
                          _dvdInfo.selectedChapterIndex = 1;
                        });
                        widget.onSelectTitle(title);
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),
              const Divider(color: EDesign.border, height: 1),
              const SizedBox(height: 14),

              // SECTION 2: AUDIO & SUBTITLE STREAMS
              if (audioTracks.isNotEmpty || subTracks.isNotEmpty) ...[
                const Text(
                  'DISC AUDIO & SUBTITLE STREAMS',
                  style: TextStyle(
                    color: EDesign.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...audioTracks.map((a) => Chip(
                          avatar: const Icon(Icons.audiotrack_rounded, size: 14, color: EDesign.primaryCyan),
                          label: Text(a.label),
                          backgroundColor: EDesign.elevatedSurface,
                          labelStyle: const TextStyle(color: EDesign.textPrimary, fontSize: 11),
                        )),
                    ...subTracks.map((s) => Chip(
                          avatar: const Icon(Icons.subtitles_rounded, size: 14, color: EDesign.secondary),
                          label: Text(s.label),
                          backgroundColor: EDesign.elevatedSurface,
                          labelStyle: const TextStyle(color: EDesign.textPrimary, fontSize: 11),
                        )),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: EDesign.border, height: 1),
                const SizedBox(height: 14),
              ],

              // SECTION 3: CHAPTERS GRID (PTT)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CHAPTERS & SCENES',
                    style: TextStyle(
                      color: EDesign.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${chapters.length} Chapters',
                    style: const TextStyle(color: EDesign.textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (chapters.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No chapter markers found for this title.', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: chapters.length,
                  separatorBuilder: (_, index) => const Divider(color: EDesign.border, height: 1),
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final isCurrent = chapter.chapterIndex == _dvdInfo.selectedChapterIndex;

                    return ListTile(
                      key: Key('dvd_chapter_tile_${chapter.chapterIndex}'),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent ? EDesign.primaryCyan.withValues(alpha: 0.25) : EDesign.elevatedSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent ? EDesign.primaryCyan : EDesign.border,
                          ),
                        ),
                        child: Text(
                          '${chapter.chapterIndex}',
                          style: TextStyle(
                            color: isCurrent ? EDesign.primaryCyan : EDesign.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(
                        chapter.label,
                        style: TextStyle(
                          color: isCurrent ? EDesign.primaryCyan : EDesign.textPrimary,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'Start: ${chapter.formattedTime}',
                        style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.play_circle_fill_rounded,
                          color: isCurrent ? EDesign.primaryCyan : EDesign.textSecondary,
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            _dvdInfo.selectedChapterIndex = chapter.chapterIndex;
                          });
                          widget.onSeekToChapter(chapter);
                          Navigator.pop(context);
                        },
                      ),
                      onTap: () {
                        setState(() {
                          _dvdInfo.selectedChapterIndex = chapter.chapterIndex;
                        });
                        widget.onSeekToChapter(chapter);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
