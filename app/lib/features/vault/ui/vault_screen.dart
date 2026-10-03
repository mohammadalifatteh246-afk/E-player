import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../domain/vault_service.dart';
import '../../player/ui/player_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _isLoading = false;
  List<File> _vaultItems = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final service = context.read<VaultService>();
    if (service.isUnlocked) {
      final items = await service.getVaultItems();
      setState(() {
        _vaultItems = items;
      });
    }
  }

  Future<void> _unlock() async {
    final service = context.read<VaultService>();
    final unlocked = await service.authenticate();
    if (unlocked) {
      _loadItems();
    }
  }

  Future<void> _playVaultItem(File encryptedFile) async {
    setState(() => _isLoading = true);
    final service = context.read<VaultService>();
    try {
      final tempPath = await service.decryptToTemp(encryptedFile);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(mediaPath: tempPath),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decrypt: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultService = context.watch<VaultService>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Private Vault'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (vaultService.isUnlocked)
            IconButton(
              icon: const Icon(Icons.lock),
              tooltip: 'Lock Vault',
              onPressed: () {
                vaultService.lock();
                setState(() => _vaultItems = []);
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : !vaultService.isUnlocked
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, size: 80, color: Colors.white54),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Unlock Vault', style: TextStyle(fontSize: 18)),
                        onPressed: _unlock,
                      ),
                    ],
                  ),
                )
              : _vaultItems.isEmpty
                  ? const Center(
                      child: Text(
                        'Vault is empty',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _vaultItems.length,
                      itemBuilder: (context, index) {
                        final file = _vaultItems[index];
                        final baseName = p.basename(file.path).replaceAll('.enc', '');
                        final nameParts = baseName.split('_');
                        final displayName = nameParts.length > 1 ? nameParts.sublist(1).join('_') : baseName;

                        return ListTile(
                          leading: const Icon(Icons.lock, color: Colors.blueAccent),
                          title: Text(
                            displayName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: const Icon(Icons.play_circle_fill, color: Colors.white54),
                          onTap: () => _playVaultItem(file),
                        );
                      },
                    ),
    );
  }
}
