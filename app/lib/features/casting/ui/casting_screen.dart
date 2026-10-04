import 'package:flutter/material.dart';

class CastingScreen extends StatefulWidget {
  const CastingScreen({super.key});

  @override
  State<CastingScreen> createState() => _CastingScreenState();
}

class _CastingScreenState extends State<CastingScreen> {
  bool _isNetworkStream = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Network & Casting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTabToggle(),
            const SizedBox(height: 24),
            _buildUrlInput(),
            const SizedBox(height: 32),
            _buildSectionTitle('Recent Streams'),
            const SizedBox(height: 12),
            _buildRecentStream('https://example.com/stream.mkv'),
            _buildRecentStream('rtsp://192.168.1.10/live'),
            _buildRecentStream('ftp://fileserver/movie.mkv'),
            const SizedBox(height: 32),
            _buildSectionTitle('Available Devices'),
            const SizedBox(height: 12),
            _buildDeviceItem('Chromecast', 'Living Room', Icons.cast),
            _buildDeviceItem('Smart TV', '', Icons.tv),
          ],
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isNetworkStream = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isNetworkStream ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _isNetworkStream ? Border.all(color: const Color(0xFF00E5FF)) : Border.all(color: Colors.transparent),
                ),
                alignment: Alignment.center,
                child: Text('Network Stream', style: TextStyle(color: _isNetworkStream ? const Color(0xFF00E5FF) : Colors.white70, fontWeight: _isNetworkStream ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isNetworkStream = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isNetworkStream ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: !_isNetworkStream ? Border.all(color: const Color(0xFF00E5FF)) : Border.all(color: Colors.transparent),
                ),
                alignment: Alignment.center,
                child: Text('Cast', style: TextStyle(color: !_isNetworkStream ? const Color(0xFF00E5FF) : Colors.white70, fontWeight: !_isNetworkStream ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter URL (HTTP/FTP)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A24),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              foregroundColor: Colors.white,
            ),
            child: const Text('Open', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildRecentStream(String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: Icon(Icons.public, color: Colors.white.withValues(alpha: 0.5)),
        title: Text(url, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        trailing: Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildDeviceItem(String name, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white.withValues(alpha: 0.5)),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
