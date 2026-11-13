import 'dart:io';
import 'package:flutter/material.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../data/opensubtitles_service.dart';
import '../models/subtitle_result.dart';

/// Glassmorphic bottom sheet for in-app OpenSubtitles / VLSub search and 1-tap download
class OnlineSubtitlesSheet extends StatefulWidget {
  final File? videoFile;
  final String? videoTitle;
  final OpenSubtitlesService? service;
  final void Function(File downloadedFile, SubtitleResult subtitle) onSubtitleLoaded;

  const OnlineSubtitlesSheet({
    super.key,
    this.videoFile,
    this.videoTitle,
    this.service,
    required this.onSubtitleLoaded,
  });

  /// Displays the online subtitle search sheet as a modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    File? videoFile,
    String? videoTitle,
    OpenSubtitlesService? service,
    required void Function(File downloadedFile, SubtitleResult subtitle) onSubtitleLoaded,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => OnlineSubtitlesSheet(
        videoFile: videoFile,
        videoTitle: videoTitle,
        service: service,
        onSubtitleLoaded: onSubtitleLoaded,
      ),
    );
  }

  @override
  State<OnlineSubtitlesSheet> createState() => _OnlineSubtitlesSheetState();
}

class _OnlineSubtitlesSheetState extends State<OnlineSubtitlesSheet> {
  late final OpenSubtitlesService _service;
  late final TextEditingController _searchController;
  bool _isLoading = true;
  String? _errorMessage;
  List<SubtitleResult> _results = [];
  String? _computedHash;
  String _selectedLanguage = 'en';

  static const Map<String, String> _languages = {
    'en': 'English',
    'hi': 'Hindi',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'ar': 'Arabic',
    'ja': 'Japanese',
    'all': 'All Languages',
  };

  @override
  void initState() {
    super.initState();
    _service = widget.service ??
        OpenSubtitlesService(
          baseUrl: 'https://api.opensubtitles.com/api/v1',
          apiKey: 'eplayer_prod_api_key',
        );

    final initialQuery = widget.videoTitle ??
        (widget.videoFile != null
            ? widget.videoFile!.path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.[^.]+$'), '')
            : '');

    _searchController = TextEditingController(text: initialQuery);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performInitialSearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performInitialSearch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. If physical file exists, calculate MovieHash first
      if (widget.videoFile != null && widget.videoFile!.existsSync()) {
        try {
          final hashRes = await _service.computeMovieHash(widget.videoFile!);
          _computedHash = hashRes.hash;
          final hashResults = await _service.searchByHash(
            movieHash: hashRes.hash,
            byteSize: hashRes.byteSize,
            language: _selectedLanguage == 'all' ? null : _selectedLanguage,
          );
          if (hashResults.isNotEmpty) {
            setState(() {
              _results = hashResults;
              _isLoading = false;
            });
            return;
          }
        } catch (_) {}
      }

      // 2. Fall back to title query search
      if (_searchController.text.trim().isNotEmpty) {
        final queryResults = await _service.searchByQuery(
          query: _searchController.text.trim(),
          language: _selectedLanguage == 'all' ? null : _selectedLanguage,
        );
        setState(() {
          _results = queryResults;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load subtitles: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadAndAttach(SubtitleResult sub) async {
    setState(() => _isLoading = true);
    try {
      final tempDir = Directory.systemTemp;
      final targetPath = '${tempDir.path}/eplayer_${sub.id}_${sub.language}.srt';
      final file = await _service.downloadSubtitleToFile(
        subtitle: sub,
        targetFile: File(targetPath),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        widget.onSubtitleLoaded(file, sub);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Download error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        margin: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: EDesign.appBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: EDesign.border),
        ),
        child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: EDesign.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_download_outlined, color: EDesign.primary, size: 22),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Online Subtitles (VLSub)', style: EDesign.h3),
                        if (_computedHash != null)
                          Text('MovieHash: $_computedHash', style: EDesign.caption),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: EDesign.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Search & Filter Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: EDesign.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search movie / episode title...',
                      hintStyle: const TextStyle(color: EDesign.textSecondary),
                      filled: true,
                      fillColor: EDesign.surface,
                      prefixIcon: const Icon(Icons.search, color: EDesign.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: EDesign.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: EDesign.border),
                      ),
                    ),
                    onSubmitted: (_) => _performInitialSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: EDesign.primary),
                  onPressed: _performInitialSearch,
                  icon: const Icon(Icons.arrow_forward, color: Colors.black),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Languages Pill Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _languages.entries.map((e) {
                final isSelected = _selectedLanguage == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: isSelected,
                    selectedColor: EDesign.primary,
                    backgroundColor: EDesign.surface,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : EDesign.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedLanguage = e.key);
                        _performInitialSearch();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: EDesign.border, height: 1),
          // Results list or status
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: EDesign.primary))
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: EDesign.warning),
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Text(
                              'No subtitles found. Try modifying search query.',
                              style: TextStyle(color: EDesign.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, _) => const Divider(color: EDesign.border, height: 1),
                            itemBuilder: (context, index) {
                              final sub = _results[index];
                              return Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: EDesign.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: EDesign.primary.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      sub.language.toUpperCase(),
                                      style: const TextStyle(
                                        color: EDesign.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    sub.languageName.isNotEmpty ? sub.languageName : sub.language,
                                    style: const TextStyle(color: EDesign.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${sub.fileName.isNotEmpty ? sub.fileName : (sub.movieTitle ?? "Subtitle")} • ${sub.downloadCount} downloads',
                                    style: const TextStyle(color: EDesign.textSecondary, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (sub.rating > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '★ ${sub.rating.toStringAsFixed(1)}',
                                            style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      const Icon(Icons.download_rounded, color: EDesign.primary),
                                    ],
                                  ),
                                  onTap: () => _downloadAndAttach(sub),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    ),
  );
}
}
