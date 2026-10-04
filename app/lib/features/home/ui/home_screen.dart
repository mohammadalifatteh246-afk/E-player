import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../ui/components/e_logo.dart';
import '../../library/domain/library_provider.dart';
import '../../../core/models/media_item.dart';
import '../../player/ui/player_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF09090E),
          appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const ELogo(withText: true, size: 32),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildCategoryChips(),
            const SizedBox(height: 32),
            _buildContinueWatching(context, provider),
            const SizedBox(height: 32),
            _buildMyMedia(provider),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['All', 'Videos', 'Folders', 'Network'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: categories.map((cat) {
          final isActive = cat == 'All';
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.transparent,
                border: Border.all(
                  color: isActive ? const Color(0xFF00E5FF) : Colors.white24,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isActive ? const Color(0xFF00E5FF) : Colors.white70,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContinueWatching(BuildContext context, LibraryProvider provider) {
    final recent = provider.recentFiles.isNotEmpty ? provider.recentFiles.first : null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Continue Watching',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          if (recent != null)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(mediaPath: recent.path),
                  ),
                );
              },
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF1A1A24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF09090E).withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        recent.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Recently Played',
                            style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 100,
                            child: LinearProgressIndicator(
                              value: 0.0,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF1A1A24),
              ),
              child: const Center(
                child: Text('No recent media found.', style: TextStyle(color: Colors.white54)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMyMedia(LibraryProvider provider) {
    int moviesCount = 0;
    int seriesCount = 0;
    int animeCount = 0;
    int musicCount = 0;

    for (var file in provider.allFiles) {
      final path = file.path.toLowerCase();
      if (path.contains('movie')) {
        moviesCount++;
      } else if (path.contains('series') || path.contains('season')) {
        seriesCount++;
      } else if (path.contains('anime')) {
        animeCount++;
      } else if (path.endsWith('.mp3') || path.endsWith('.flac') || path.endsWith('.m4a') || path.endsWith('.wav')) {
        musicCount++;
      } else {
        // Default assignment for demo
        moviesCount++;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Media',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildMediaCard('Movies', ' items', Icons.movie_outlined, const Color(0xFF2979FF)),
              _buildMediaCard('Series', ' items', Icons.tv_outlined, const Color(0xFF00C853)),
              _buildMediaCard('Anime', ' items', Icons.animation, const Color(0xFFFF3D00)),
              _buildMediaCard('Music', ' items', Icons.music_note_outlined, const Color(0xFFAA00FF)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
