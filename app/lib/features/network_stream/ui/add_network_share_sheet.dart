import 'package:flutter/material.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../models/network_share.dart';

/// Modal sheet for adding a new local network share (SMB, UPnP/DLNA) or custom stream URL (RTSP/HTTP).
class AddNetworkShareSheet extends StatefulWidget {
  final void Function(NetworkShare share) onShareAdded;

  const AddNetworkShareSheet({
    super.key,
    required this.onShareAdded,
  });

  /// Displays the AddNetworkShareSheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required void Function(NetworkShare share) onShareAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddNetworkShareSheet(onShareAdded: onShareAdded),
    );
  }

  @override
  State<AddNetworkShareSheet> createState() => _AddNetworkShareSheetState();
}

class _AddNetworkShareSheetState extends State<AddNetworkShareSheet> {
  NetworkProtocol _selectedProtocol = NetworkProtocol.smb;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isAnonymous = true;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _pathController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _saveAndConnect() {
    final rawHost = _hostController.text.trim();
    if (rawHost.isEmpty) return;

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : rawHost;

    // Parse protocol and clean host if user entered full URL like rtsp://... or smb://...
    String cleanHost = rawHost;
    NetworkProtocol protocol = _selectedProtocol;
    int port = NetworkShare.defaultPortFor(protocol);
    String sharedPath = _pathController.text.trim();

    if (rawHost.contains('://')) {
      final uri = Uri.tryParse(rawHost);
      if (uri != null) {
        if (uri.scheme == 'rtsp' || uri.scheme == 'http' || uri.scheme == 'https') {
          protocol = NetworkProtocol.http;
        } else if (uri.scheme == 'smb') {
          protocol = NetworkProtocol.smb;
        }
        cleanHost = uri.host.isNotEmpty ? uri.host : rawHost.split('://').last;
        if (uri.port > 0) port = uri.port;
        if (uri.path.isNotEmpty) {
          sharedPath = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
        }
      }
    }

    final share = NetworkShare(
      id: 'share_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      host: cleanHost,
      port: port,
      protocol: protocol,
      sharedPath: sharedPath,
      username: _isAnonymous ? null : _userController.text.trim(),
      password: _isAnonymous ? null : _passController.text.trim(),
      isAnonymous: _isAnonymous,
    );

    widget.onShareAdded(share);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
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
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Network Storage or Stream', style: EDesign.h3),
                  IconButton(
                    icon: const Icon(Icons.close, color: EDesign.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: EDesign.border),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                  // Protocol selection
                  Text('Protocol', style: EDesign.body.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Windows SMB'),
                        selected: _selectedProtocol == NetworkProtocol.smb,
                        selectedColor: EDesign.primary,
                        onSelected: (val) {
                          if (val) setState(() => _selectedProtocol = NetworkProtocol.smb);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('UPnP / DLNA'),
                        selected: _selectedProtocol == NetworkProtocol.upnpDlna,
                        selectedColor: EDesign.primary,
                        onSelected: (val) {
                          if (val) setState(() => _selectedProtocol = NetworkProtocol.upnpDlna);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Stream URL'),
                        selected: _selectedProtocol == NetworkProtocol.http,
                        selectedColor: EDesign.primary,
                        onSelected: (val) {
                          if (val) setState(() => _selectedProtocol = NetworkProtocol.http);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Friendly Name
                  Text('Display Name', style: EDesign.body.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('share_name_input'),
                    controller: _nameController,
                    style: const TextStyle(color: EDesign.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Living Room NAS / Movie Share',
                      hintStyle: const TextStyle(color: EDesign.textSecondary),
                      filled: true,
                      fillColor: EDesign.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Host / IP Address
                  Text('Host / IP / Stream URL', style: EDesign.body.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('share_host_input'),
                    controller: _hostController,
                    style: const TextStyle(color: EDesign.textPrimary),
                    decoration: InputDecoration(
                      hintText: _selectedProtocol == NetworkProtocol.smb
                          ? '192.168.1.100'
                          : 'rtsp://... or http://...:8200',
                      hintStyle: const TextStyle(color: EDesign.textSecondary),
                      filled: true,
                      fillColor: EDesign.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  if (_selectedProtocol == NetworkProtocol.smb) ...[
                    const SizedBox(height: 14),
                    Text('Shared Folder Name', style: EDesign.body.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _pathController,
                      style: const TextStyle(color: EDesign.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. video or movies',
                        hintStyle: const TextStyle(color: EDesign.textSecondary),
                        filled: true,
                        fillColor: EDesign.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Anonymous / Guest Access', style: EDesign.body),
                      value: _isAnonymous,
                      activeThumbColor: EDesign.primary,
                      onChanged: (val) => setState(() => _isAnonymous = val),
                    ),
                    if (!_isAnonymous) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _userController,
                        style: const TextStyle(color: EDesign.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: const TextStyle(color: EDesign.textSecondary),
                          filled: true,
                          fillColor: EDesign.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passController,
                        obscureText: true,
                        style: const TextStyle(color: EDesign.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: EDesign.textSecondary),
                          filled: true,
                          fillColor: EDesign.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EDesign.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveAndConnect,
                child: const Text('Save & Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
