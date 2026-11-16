import 'package:flutter/material.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../domain/bookmark_models.dart';

/// Modal dialog for authoring or updating bookmark annotations, tags, colors, and notes.
class BookmarkEditDialog extends StatefulWidget {
  final MediaBookmark bookmark;
  final void Function(MediaBookmark updated) onSave;

  const BookmarkEditDialog({
    super.key,
    required this.bookmark,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required MediaBookmark bookmark,
    required void Function(MediaBookmark updated) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (_) => BookmarkEditDialog(
        bookmark: bookmark,
        onSave: onSave,
      ),
    );
  }

  @override
  State<BookmarkEditDialog> createState() => _BookmarkEditDialogState();
}

class _BookmarkEditDialogState extends State<BookmarkEditDialog> {
  late TextEditingController _labelController;
  late TextEditingController _noteController;
  late String _selectedCategory;
  String? _selectedColorHex;

  static const List<String> _categories = [
    'general',
    'highlight',
    'important',
    'study',
    'review',
  ];

  static const List<String> _colorOptions = [
    '#19BFFF', // Cyan
    '#69F0AE', // Mint
    '#FFEB3B', // Yellow
    '#FF9800', // Amber
    '#FF5252', // Coral Red
    '#E040FB', // Purple
  ];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.bookmark.label);
    _noteController = TextEditingController(text: widget.bookmark.note ?? '');
    _selectedCategory = widget.bookmark.category;
    _selectedColorHex = widget.bookmark.colorHex;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.amber;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    }
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.bookmark_border_rounded, color: EDesign.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bookmark Annotation',
                  style: TextStyle(
                    color: EDesign.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Timestamp: ${widget.bookmark.formattedRange}',
                  style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label / Title
              const Text(
                'Label / Title',
                style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _labelController,
                style: const TextStyle(color: EDesign.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Key Scene, Guitar Solo',
                  hintStyle: const TextStyle(color: EDesign.textMuted),
                  filled: true,
                  fillColor: EDesign.elevatedSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(EDesign.r8),
                    borderSide: const BorderSide(color: EDesign.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),

              // Category Selector
              const Text(
                'Category',
                style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(
                      cat.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
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
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Color Tag
              const Text(
                'Color Tag',
                style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: _colorOptions.map((hex) {
                  final color = _hexToColor(hex);
                  final isSelected = _selectedColorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Multi-line Detailed Notes
              const Text(
                'Annotation Note (Markdown Supported)',
                style: TextStyle(color: EDesign.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 4,
                style: const TextStyle(color: EDesign.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add detailed commentary, study notes, or observations...',
                  hintStyle: const TextStyle(color: EDesign.textMuted),
                  filled: true,
                  fillColor: EDesign.elevatedSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(EDesign.r8),
                    borderSide: const BorderSide(color: EDesign.border),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: EDesign.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: EDesign.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EDesign.r8),
            ),
          ),
          onPressed: () {
            final updated = widget.bookmark.copyWith(
              label: _labelController.text.trim().isNotEmpty
                  ? _labelController.text.trim()
                  : widget.bookmark.label,
              note: _noteController.text.trim().isNotEmpty
                  ? _noteController.text.trim()
                  : null,
              category: _selectedCategory,
              colorHex: _selectedColorHex,
            );
            widget.onSave(updated);
            Navigator.pop(context);
          },
          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
