import 'package:flutter/material.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../data/network_media_service.dart';
import '../models/network_share.dart';
import 'add_network_share_sheet.dart';

/// Screen view for browsing configured local network storage locations (SMB, UPnP/DLNA) and live stream URLs.
class NetworkBrowserView extends StatefulWidget {
  final NetworkMediaService? service;
  final List<NetworkShare>? initialShares;
  final void Function(NetworkMediaItem item, String streamUrl) onPlayStream;

  const NetworkBrowserView({
    super.key,
    this.service,
    this.initialShares,
    required this.onPlayStream,
  });

  @override
  State<NetworkBrowserView> createState() => _NetworkBrowserViewState();
}

class _NetworkBrowserViewState extends State<NetworkBrowserView> {
  late final NetworkMediaService _service;
  late final List<NetworkShare> _shares;

  NetworkShare? _activeShare;
  String _currentSubPath = '';
  List<NetworkMediaItem> _currentItems = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NetworkMediaService();
    _shares = List.from(widget.initialShares ?? _service.registeredShares);
    for (final s in _shares) {
      _service.addShare(s);
    }
  }

  Future<void> _openShare(NetworkShare share, {String subPath = ''}) async {
    setState(() {
      _activeShare = share;
      _currentSubPath = subPath;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _service.browseShare(share, subPath: subPath);
      if (mounted) {
        setState(() {
          _currentItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load directory: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateBack() {
    if (_currentSubPath.isNotEmpty && _currentSubPath.contains('/')) {
      final parts = _currentSubPath.split('/')..removeLast();
      _openShare(_activeShare!, subPath: parts.join('/'));
    } else if (_currentSubPath.isNotEmpty) {
      _openShare(_activeShare!, subPath: '');
    } else {
      setState(() {
        _activeShare = null;
        _currentSubPath = '';
        _currentItems = [];
      });
    }
  }

  void _openAddSheet() {
    AddNetworkShareSheet.show(
      context,
      onShareAdded: (share) {
        setState(() {
          _shares.add(share);
          _service.addShare(share);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeShare != null) {
      return _buildShareExplorer();
    }
    return _buildSharesList();
  }

  Widget _buildSharesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Local Network & Streams', style: EDesign.h3),
                  Text('Browse SMB shares, UPnP/DLNA servers & streams', style: EDesign.caption),
                ],
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: EDesign.primary),
                icon: const Icon(Icons.add, color: Colors.black),
                tooltip: 'Add Network Location',
                onPressed: _openAddSheet,
              ),
            ],
          ),
        ),
        const Divider(color: EDesign.border, height: 1),
        Expanded(
          child: _shares.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 56, color: EDesign.textSecondary),
                      const SizedBox(height: 12),
                      Text('No network shares configured', style: EDesign.body.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text(
                        'Connect to a PC, NAS, DLNA server, or RTSP stream',
                        style: TextStyle(color: EDesign.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EDesign.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Network Location', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _openAddSheet,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  itemCount: _shares.length,
                  itemBuilder: (context, index) {
                    final share = _shares[index];
                    final protocolLabel = share.protocol == NetworkProtocol.smb
                        ? 'SMB'
                        : share.protocol == NetworkProtocol.upnpDlna
                            ? 'UPnP/DLNA'
                            : 'Stream';

                    final subtitleText = share.sharedPath.isNotEmpty
                        ? '$protocolLabel • ${share.host}/${share.sharedPath}'
                        : '$protocolLabel • ${share.host}';

                    return Card(
                      color: EDesign.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: EDesign.border),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: EDesign.primary.withValues(alpha: 0.15),
                          child: Icon(
                            share.protocol == NetworkProtocol.smb
                                ? Icons.dns_outlined
                                : share.protocol == NetworkProtocol.upnpDlna
                                    ? Icons.connected_tv_outlined
                                    : Icons.stream,
                            color: EDesign.primary,
                          ),
                        ),
                        title: Text(share.name, style: EDesign.body.copyWith(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          subtitleText,
                          style: const TextStyle(color: EDesign.textSecondary, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: EDesign.textSecondary),
                        onTap: () => _openShare(share),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildShareExplorer() {
    return Column(
      children: [
        // Navigation bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: EDesign.surface,
            border: Border(bottom: BorderSide(color: EDesign.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: EDesign.textPrimary),
                onPressed: _navigateBack,
              ),
              Expanded(
                child: Text(
                  '${_activeShare!.name}${_currentSubPath.isNotEmpty ? ' / $_currentSubPath' : ''}',
                  style: EDesign.body.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: EDesign.textSecondary),
                onPressed: () => _openShare(_activeShare!, subPath: _currentSubPath),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: EDesign.primary))
              : _errorMessage != null
                  ? Center(
                      child: Text(_errorMessage!, style: const TextStyle(color: EDesign.warning)),
                    )
                  : _currentItems.isEmpty
                      ? const Center(
                          child: Text('This folder is empty', style: TextStyle(color: EDesign.textSecondary)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: _currentItems.length,
                          separatorBuilder: (_, _) => const Divider(color: EDesign.border, height: 1),
                          itemBuilder: (context, index) {
                            final item = _currentItems[index];
                            if (item.isDirectory) {
                              return ListTile(
                                leading: const Icon(Icons.folder, color: Colors.amber),
                                title: Text(item.title, style: EDesign.body.copyWith(fontWeight: FontWeight.bold)),
                                trailing: const Icon(Icons.chevron_right, color: EDesign.textSecondary),
                                onTap: () => _openShare(_activeShare!, subPath: item.path),
                              );
                            }

                            return ListTile(
                              leading: Icon(
                                item.isVideo
                                    ? Icons.movie_outlined
                                    : item.isAudio
                                        ? Icons.headphones_outlined
                                        : Icons.insert_drive_file_outlined,
                                color: item.isVideo ? EDesign.primary : Colors.white70,
                              ),
                              title: Text(item.title, style: EDesign.body),
                              subtitle: item.sizeBytes != null && item.sizeBytes! > 0
                                  ? Text(
                                      '${(item.sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                                      style: const TextStyle(color: EDesign.textSecondary, fontSize: 12),
                                    )
                                  : null,
                              trailing: const Icon(Icons.play_circle_fill, color: EDesign.primary),
                              onTap: () {
                                final streamUrl = _service.resolveStreamUrl(item, share: _activeShare);
                                widget.onPlayStream(item, streamUrl);
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
