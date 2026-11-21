import 'package:flutter/material.dart';
import '../models/dlna_models.dart';
import '../models/network_share.dart';
import '../data/dlna_service.dart';

/// Bottom sheet dialog for discovering, browsing, and streaming from DLNA / UPnP Media Servers.
class DlnaServerBrowserSheet extends StatefulWidget {
  final DlnaService dlnaService;
  final ValueChanged<NetworkMediaItem> onPlayMediaItem;
  final ValueChanged<NetworkMediaItem>? onEnqueueMediaItem;

  const DlnaServerBrowserSheet({
    super.key,
    required this.dlnaService,
    required this.onPlayMediaItem,
    this.onEnqueueMediaItem,
  });

  @override
  State<DlnaServerBrowserSheet> createState() => _DlnaServerBrowserSheetState();
}

class _DlnaServerBrowserSheetState extends State<DlnaServerBrowserSheet> {
  DlnaMediaServer? _selectedServer;
  final List<_BreadcrumbNode> _breadcrumbs = [];
  List<NetworkMediaItem> _currentItems = [];
  bool _isLoadingItems = false;
  String? _browseError;
  bool _showManualConnect = false;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.dlnaService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    widget.dlnaService.removeListener(_onServiceUpdate);
    _urlController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _selectServer(DlnaMediaServer server) async {
    setState(() {
      _selectedServer = server;
      _breadcrumbs.clear();
      _breadcrumbs.add(_BreadcrumbNode(id: '0', title: 'Root'));
      _browseError = null;
    });
    await _loadContainer(server, '0');
  }

  Future<void> _loadContainer(DlnaMediaServer server, String containerId) async {
    setState(() {
      _isLoadingItems = true;
      _browseError = null;
    });
    try {
      final res = await widget.dlnaService.browseContainer(server, objectId: containerId);
      if (mounted) {
        setState(() {
          _currentItems = res.items;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _browseError = 'Failed to load folder: $e';
          _isLoadingItems = false;
        });
      }
    }
  }

  Future<void> _navigateIntoFolder(NetworkMediaItem item) async {
    if (_selectedServer == null) return;
    setState(() {
      _breadcrumbs.add(_BreadcrumbNode(id: item.id, title: item.title));
    });
    await _loadContainer(_selectedServer!, item.id);
  }

  Future<void> _navigateBack() async {
    if (_breadcrumbs.length <= 1) {
      // Back to server list
      setState(() {
        _selectedServer = null;
        _breadcrumbs.clear();
        _currentItems.clear();
        _browseError = null;
      });
      return;
    }
    setState(() {
      _breadcrumbs.removeLast();
    });
    final parent = _breadcrumbs.last;
    if (_selectedServer != null) {
      await _loadContainer(_selectedServer!, parent.id);
    }
  }

  Future<void> _handleManualConnect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoadingItems = true;
      _browseError = null;
    });

    try {
      final server = await widget.dlnaService.connectToUrl(url);
      if (mounted) {
        setState(() {
          _isLoadingItems = false;
          _showManualConnect = false;
          _urlController.clear();
        });
        if (server != null) {
          _selectServer(server);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingItems = false;
          _browseError = 'Failed to connect: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servers = widget.dlnaService.servers;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
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
            if (widget.dlnaService.isScanning || _isLoadingItems)
              const LinearProgressIndicator(minHeight: 2.5),
            const Divider(height: 1),

            // Main Content Area
            Expanded(
              child: _selectedServer == null
                  ? _buildServerListView(theme, servers)
                  : _buildFolderBrowserView(theme),
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
              if (_selectedServer != null)
                IconButton(
                  key: const Key('dlna_browser_back_button'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Go back',
                  onPressed: _navigateBack,
                )
              else
                const Icon(Icons.settings_input_antenna, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedServer == null
                          ? 'DLNA / UPnP Media Servers'
                          : _selectedServer!.friendlyName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _selectedServer == null
                          ? 'VLC Parity • Ingest local network streams'
                          : _breadcrumbs.map((b) => b.title).join(' / '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_selectedServer == null) ...[
                IconButton(
                  key: const Key('dlna_scan_button'),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Scan Network (SSDP)',
                  onPressed: widget.dlnaService.isScanning
                      ? null
                      : () => widget.dlnaService.startDiscovery(),
                ),
                IconButton(
                  key: const Key('dlna_manual_connect_button'),
                  icon: Icon(_showManualConnect ? Icons.close : Icons.add_link),
                  tooltip: 'Direct URL / IP Connect',
                  onPressed: () {
                    setState(() {
                      _showManualConnect = !_showManualConnect;
                    });
                  },
                ),
              ],
              IconButton(
                key: const Key('dlna_browser_close_button'),
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

  Widget _buildServerListView(ThemeData theme, List<DlnaMediaServer> servers) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showManualConnect) _buildManualConnectCard(theme),
          if (_browseError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _browseError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discovered Servers (${servers.length})',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (servers.isNotEmpty)
                TextButton.icon(
                  onPressed: () => widget.dlnaService.clearServers(),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white54),
                  label: const Text('Clear', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (servers.isEmpty)
            _buildEmptyServersState(theme)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: servers.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final srv = servers[index];
                return _buildServerCard(theme, srv);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildManualConnectCard(ThemeData theme) {
    return Card(
      color: Colors.white.withValues(alpha: 0.06),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Direct Server Connect',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter UPnP Device XML Descriptor URL (e.g. http://192.168.1.50:8200/rootDesc.xml)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('dlna_url_input'),
                    controller: _urlController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'http://192.168.1.X:port/desc.xml',
                      hintStyle: const TextStyle(color: Colors.white38),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('dlna_url_connect_btn'),
                  onPressed: _handleManualConnect,
                  child: const Text('Connect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyServersState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_tethering_off, size: 48, color: Colors.white30),
            const SizedBox(height: 12),
            const Text(
              'No DLNA / UPnP Media Servers Found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Make sure Plex, Kodi, Synology NAS, or MiniDLNA is running on your LAN.\nTap Refresh to scan SSDP multicast or enter URL manually.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Local Network'),
              onPressed: () => widget.dlnaService.startDiscovery(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerCard(ThemeData theme, DlnaMediaServer srv) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        key: Key('dlna_server_tile_${srv.id}'),
        leading: CircleAvatar(
          backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
          child: const Icon(Icons.dns, color: Colors.cyanAccent),
        ),
        title: Text(
          srv.friendlyName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${srv.manufacturer ?? 'DLNA Server'} • ${srv.host}:${srv.port}',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () => _selectServer(srv),
      ),
    );
  }

  Widget _buildFolderBrowserView(ThemeData theme) {
    if (_browseError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_browseError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  if (_breadcrumbs.isNotEmpty && _selectedServer != null) {
                    _loadContainer(_selectedServer!, _breadcrumbs.last.id);
                  }
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentItems.isEmpty && !_isLoadingItems) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 44, color: Colors.white30),
            SizedBox(height: 8),
            Text('Folder is empty', style: TextStyle(color: Colors.white60)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _currentItems.length,
      separatorBuilder: (_, index) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, index) {
        final item = _currentItems[index];
        if (item.isDirectory) {
          return ListTile(
            key: Key('dlna_item_folder_${item.id}'),
            leading: const Icon(Icons.folder, color: Colors.amberAccent),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => _navigateIntoFolder(item),
          );
        }

        // Media Stream Item
        return ListTile(
          key: Key('dlna_item_media_${item.id}'),
          leading: Icon(
            item.title.endsWith('.mp3') || item.title.endsWith('.flac') || item.title.endsWith('.m4a')
                ? Icons.audio_file
                : Icons.movie_outlined,
            color: Colors.cyanAccent,
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${_formatDuration(item.duration)} • ${_formatSize(item.sizeBytes)}',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onEnqueueMediaItem != null)
                IconButton(
                  key: Key('dlna_enqueue_${item.id}'),
                  icon: const Icon(Icons.playlist_add, size: 20),
                  tooltip: 'Enqueue in Playlist',
                  onPressed: () {
                    widget.onEnqueueMediaItem!(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Enqueued: ${item.title}'), duration: const Duration(seconds: 1)),
                    );
                  },
                ),
              IconButton(
                key: Key('dlna_play_${item.id}'),
                icon: const Icon(Icons.play_circle_fill, size: 28, color: Colors.cyanAccent),
                tooltip: 'Play Stream Now',
                onPressed: () {
                  widget.onPlayMediaItem(item);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null || d == Duration.zero) return 'Stream';
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mins:$secs' : '$mins:$secs';
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Live/Direct';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

class _BreadcrumbNode {
  final String id;
  final String title;

  const _BreadcrumbNode({required this.id, required this.title});
}
