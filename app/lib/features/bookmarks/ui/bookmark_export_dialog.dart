import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../data/bookmark_export_service.dart';
import '../domain/bookmark_models.dart';

/// Modal dialog providing multi-format bookmark export with live preview and clipboard copy.
class BookmarkExportDialog extends StatefulWidget {
  final List<MediaBookmark> bookmarks;
  final String mediaTitle;

  const BookmarkExportDialog({
    super.key,
    required this.bookmarks,
    required this.mediaTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required List<MediaBookmark> bookmarks,
    required String mediaTitle,
  }) {
    return showDialog(
      context: context,
      builder: (_) => BookmarkExportDialog(
        bookmarks: bookmarks,
        mediaTitle: mediaTitle,
      ),
    );
  }

  @override
  State<BookmarkExportDialog> createState() => _BookmarkExportDialogState();
}

class _BookmarkExportDialogState extends State<BookmarkExportDialog> {
  BookmarkExportFormat _selectedFormat = BookmarkExportFormat.json;

  static const Map<BookmarkExportFormat, String> _formatLabels = {
    BookmarkExportFormat.json: 'JSON',
    BookmarkExportFormat.vlcXspf: 'VLC (XSPF)',
    BookmarkExportFormat.markdown: 'Markdown',
    BookmarkExportFormat.csv: 'CSV',
    BookmarkExportFormat.ffmpegChapters: 'FFmpeg',
    BookmarkExportFormat.srt: 'SRT Subtitle',
  };

  static const Map<BookmarkExportFormat, String> _formatExtensions = {
    BookmarkExportFormat.json: '.json',
    BookmarkExportFormat.vlcXspf: '.xspf',
    BookmarkExportFormat.markdown: '.md',
    BookmarkExportFormat.csv: '.csv',
    BookmarkExportFormat.ffmpegChapters: '.txt',
    BookmarkExportFormat.srt: '.srt',
  };

  @override
  Widget build(BuildContext context) {
    final exportText = BookmarkExportService.exportToString(
      widget.bookmarks,
      _selectedFormat,
      mediaTitle: widget.mediaTitle,
    );

    return AlertDialog(
      backgroundColor: EDesign.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EDesign.r16),
        side: const BorderSide(color: EDesign.border),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: EDesign.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(EDesign.r8),
            ),
            child: const Icon(Icons.file_upload_outlined, color: EDesign.primary, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Bookmarks & Annotations',
                  style: TextStyle(
                    color: EDesign.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Industry standard formats for VLC, FFmpeg, and notes',
                  style: TextStyle(color: EDesign.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format Selector Chips
            const Text(
              'Select Format',
              style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: BookmarkExportFormat.values.map((fmt) {
                  final isSelected = _selectedFormat == fmt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        _formatLabels[fmt]!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : EDesign.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: EDesign.primary,
                      backgroundColor: EDesign.elevatedSurface,
                      side: BorderSide(
                        color: isSelected ? EDesign.primary : EDesign.border,
                        width: 0.8,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedFormat = fmt);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Live Output Preview Box
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Export Preview (${_formatExtensions[_selectedFormat]})',
                  style: const TextStyle(color: EDesign.textSecondary, fontSize: 11.5),
                ),
                Text(
                  '${widget.bookmarks.length} Bookmarks',
                  style: const TextStyle(color: EDesign.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F1A),
                borderRadius: BorderRadius.circular(EDesign.r10),
                border: Border.all(color: EDesign.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  exportText,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: EDesign.textMuted)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: EDesign.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EDesign.r8),
            ),
          ),
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy to Clipboard', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: exportText));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied ${_formatLabels[_selectedFormat]} bookmarks to clipboard!'),
                backgroundColor: EDesign.elevatedSurface,
                duration: const Duration(seconds: 2),
              ),
            );
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
