import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/online_stream_models.dart';
import '../data/online_stream_service.dart';

/// Modal dialog for entering online URLs, auto-extracting YouTube & generic streams,
/// selecting quality, and streaming with a 5-item recent history (VLC `Ctrl+N` parity).
class OnlineStreamSheet extends StatefulWidget {
  final OnlineStreamService service;
  final void Function(String streamUrl, String title) onPlayStream;
  final void Function(String streamUrl, String title)? onEnqueueStream;
  final SharedPreferences? prefs;

  const OnlineStreamSheet({
    super.key,
    required this.service,
    required this.onPlayStream,
    this.onEnqueueStream,
    this.prefs,
  });

  static Future<void> show(
    BuildContext context, {
    required OnlineStreamService service,
    required void Function(String streamUrl, String title) onPlayStream,
    void Function(String streamUrl, String title)? onEnqueueStream,
    SharedPreferences? prefs,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => OnlineStreamSheet(
        service: service,
        onPlayStream: onPlayStream,
        onEnqueueStream: onEnqueueStream,
        prefs: prefs,
      ),
    );
  }

  @override
  State<OnlineStreamSheet> createState() => _OnlineStreamSheetState();
}

class _OnlineStreamSheetState extends State<OnlineStreamSheet> {
  final TextEditingController _urlController = TextEditingController();
  OnlineStreamInfo? _extractedInfo;
  StreamFormat? _selectedFormat;
  bool _isExtracting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceUpdate);
    _urlController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _urlController.text = data.text!.trim();
      _handleExtract();
    }
  }

  Future<void> _handleExtract() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      final info = await widget.service.extractStreamInfo(url);
      if (mounted) {
        setState(() {
          _extractedInfo = info;
          _selectedFormat = info.bestFormat;
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to extract stream: $e';
          _isExtracting = false;
        });
      }
    }
  }

  Future<void> _playCurrentStream() async {
    if (_extractedInfo == null) {
      // Fallback: play raw URL directly if not extracted
      final raw = _urlController.text.trim();
      if (raw.isNotEmpty) {
        widget.onPlayStream(raw, raw);
        Navigator.of(context).pop();
      }
      return;
    }

    final targetUrl = _selectedFormat?.url ?? _extractedInfo!.resolvedStreamUrl;
    final title = _extractedInfo!.title;

    // Save to 5-item recent history
    await widget.service.addRecentStream(
      RecentStreamEntry(
        url: _extractedInfo!.originalUrl,
        title: title,
        author: _extractedInfo!.author,
        thumbnailUrl: _extractedInfo!.thumbnailUrl,
        timestamp: DateTime.now(),
      ),
      prefs: widget.prefs,
    );

    widget.onPlayStream(targetUrl, title);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _enqueueCurrentStream() async {
    if (_extractedInfo == null || widget.onEnqueueStream == null) return;

    final targetUrl = _selectedFormat?.url ?? _extractedInfo!.resolvedStreamUrl;
    final title = _extractedInfo!.title;

    await widget.service.addRecentStream(
      RecentStreamEntry(
        url: _extractedInfo!.originalUrl,
        title: title,
        author: _extractedInfo!.author,
        thumbnailUrl: _extractedInfo!.thumbnailUrl,
        timestamp: DateTime.now(),
      ),
      prefs: widget.prefs,
    );

    widget.onEnqueueStream!(targetUrl, title);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enqueued: $title'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _selectRecentStream(RecentStreamEntry entry) {
    _urlController.text = entry.url;
    _handleExtract();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentStreams = widget.service.recentStreams;

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
            // Top Drag Handle & Title Bar
            _buildHeader(theme),
            if (_isExtracting) const LinearProgressIndicator(minHeight: 2.5),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputSection(theme),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    if (_extractedInfo != null) ...[
                      const SizedBox(height: 16),
                      _buildPreviewCard(theme, _extractedInfo!),
                    ],
                    const SizedBox(height: 20),
                    _buildRecentStreamsSection(theme, recentStreams),
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
              const Icon(Icons.travel_explore_rounded, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Network Stream',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'VLC Parity • YouTube, HLS, DASH, Direct Video (Ctrl+N)',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('online_stream_close_button'),
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

  Widget _buildInputSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Media URL',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('online_stream_url_input'),
                controller: _urlController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/watch?v=... or https://...m3u8',
                  hintStyle: const TextStyle(color: Colors.white38),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: IconButton(
                    key: const Key('online_stream_paste_button'),
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    tooltip: 'Paste from Clipboard',
                    onPressed: _handlePaste,
                  ),
                ),
                onSubmitted: (_) => _handleExtract(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('online_stream_extract_button'),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Extract'),
              onPressed: _isExtracting ? null : _handleExtract,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewCard(ThemeData theme, OnlineStreamInfo info) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail or Type Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 100,
                    height: 60,
                    color: Colors.black45,
                    child: info.thumbnailUrl != null
                        ? Image.network(
                            info.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.ondemand_video, color: Colors.cyanAccent, size: 30),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.ondemand_video, color: Colors.cyanAccent, size: 30),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (info.isYouTube)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'YouTube',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              info.title,
                              key: const Key('online_stream_preview_title'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.author ?? 'Online Media Stream',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stream Quality Selector
            if (info.formats.isNotEmpty) ...[
              Row(
                children: [
                  const Text('Quality: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 8),
                  DropdownButton<StreamFormat>(
                    key: const Key('online_stream_quality_dropdown'),
                    value: _selectedFormat ?? info.formats.first,
                    dropdownColor: theme.colorScheme.surface,
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                    underline: const SizedBox(),
                    items: info.formats.map((fmt) {
                      return DropdownMenuItem<StreamFormat>(
                        value: fmt,
                        child: Text(
                          fmt.qualityLabel + (fmt.resolution != null ? ' (${fmt.resolution})' : ''),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedFormat = val);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onEnqueueStream != null) ...[
                  OutlinedButton.icon(
                    key: const Key('online_stream_enqueue_button'),
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: const Text('Enqueue'),
                    onPressed: _enqueueCurrentStream,
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  key: const Key('online_stream_play_button'),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Play Stream Now'),
                  onPressed: _playCurrentStream,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentStreamsSection(ThemeData theme, List<RecentStreamEntry> recentStreams) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Streams (${recentStreams.length}/${OnlineStreamService.kMaxHistory})',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (recentStreams.isNotEmpty)
              TextButton.icon(
                key: const Key('online_stream_clear_history_button'),
                icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.white54),
                label: const Text('Clear', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onPressed: () => widget.service.clearRecentHistory(prefs: widget.prefs),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (recentStreams.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No recent online streams.\nPasted links will appear here for fast replay (max 5).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentStreams.length,
            separatorBuilder: (_, index) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              final item = recentStreams[index];
              return ListTile(
                key: Key('recent_stream_tile_$index'),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                leading: const Icon(Icons.history_rounded, color: Colors.cyanAccent, size: 20),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  item.url,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  key: Key('recent_stream_play_$index'),
                  icon: const Icon(Icons.play_circle_outline, color: Colors.cyanAccent, size: 20),
                  tooltip: 'Play',
                  onPressed: () {
                    widget.onPlayStream(item.url, item.title);
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () => _selectRecentStream(item),
              );
            },
          ),
      ],
    );
  }
}
