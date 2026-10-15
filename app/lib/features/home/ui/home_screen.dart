import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../ui/components/e_logo.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../library/domain/library_provider.dart';
import '../../library/ui/folder_detail_screen.dart';
import '../../../core/models/media_item.dart';
import '../../player/ui/player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: EDesign.appBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: EDesign.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Search movies, series, music...',
                      hintStyle: TextStyle(color: EDesign.textMuted),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  )
                : const ELogo(withText: true, size: 32),
            actions: [
              IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: EDesign.textPrimary,
                ),
                tooltip: _isSearching ? 'Close Search' : 'Search Media',
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
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
                const SizedBox(height: 28),
                if (_searchQuery.isNotEmpty)
                  _buildSearchResults(context, provider)
                else ...[
                  _buildContinueWatching(context, provider),
                  const SizedBox(height: 32),
                  _buildMyMedia(context, provider),
                  if (provider.favorites.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildFavoritesRail(context, provider),
                  ],
                ],
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
          final isActive = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? EDesign.primary.withValues(alpha: 0.15)
                      : EDesign.surface,
                  border: Border.all(
                    color: isActive ? EDesign.primary : EDesign.border,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isActive ? EDesign.primary : EDesign.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, LibraryProvider provider) {
    final matches = provider.allFiles
        .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Results (${matches.length})',
            style: EDesign.h3,
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: EDesign.cardDecoration(),
              child: Center(
                child: Text(
                  'No media matching "$_searchQuery"',
                  style: EDesign.secondaryStyle,
                ),
              ),
            )
          else
            ...matches.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: EDesign.cardDecoration(),
                child: ListTile(
                  leading: const Icon(Icons.play_circle_fill, color: EDesign.primary, size: 32),
                  title: Text(item.name, style: EDesign.body),
                  subtitle: Text(
                    EDesign.formatBytes(item.sizeBytes),
                    style: EDesign.caption,
                  ),
                  onTap: () {
                    provider.addRecent(item.path);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(mediaPath: item.path),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContinueWatching(BuildContext context, LibraryProvider provider) {
    final recent = provider.recentFiles.isNotEmpty ? provider.recentFiles.first : null;
    final double progressValue = (recent != null && recent.durationMs > 0)
        ? (recent.lastPositionMs / recent.durationMs).clamp(0.0, 1.0)
        : 0.0;

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
                style: EDesign.h3,
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
                decoration: EDesign.cardDecoration(
                  color: EDesign.elevatedSurface,
                  radius: EDesign.r18,
                  withGlow: true,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(EDesign.r18),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        EDesign.appBackground.withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          EDesign.buildBadge('CONTINUE', color: EDesign.primary),
                          EDesign.buildBadge(
                            EDesign.formatBytes(recent.sizeBytes),
                            color: EDesign.textSecondary,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: EDesign.primary.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: EDesign.primary.withValues(alpha: 0.5),
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
                          color: EDesign.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            progressValue > 0
                                ? '${(progressValue * 100).toStringAsFixed(0)}% watched'
                                : 'Recently Played',
                            style: const TextStyle(
                              color: EDesign.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 110,
                            child: LinearProgressIndicator(
                              value: progressValue,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(EDesign.primary),
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
              height: 110,
              decoration: EDesign.cardDecoration(radius: EDesign.r18),
              child: const Center(
                child: Text(
                  'No recent media found. Scan a folder in Library to begin.',
                  style: EDesign.secondaryStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMyMedia(BuildContext context, LibraryProvider provider) {
    int moviesCount = 0;
    int seriesCount = 0;
    int animeCount = 0;
    int musicCount = 0;

    final List<MediaItem> moviesList = [];
    final List<MediaItem> seriesList = [];
    final List<MediaItem> animeList = [];
    final List<MediaItem> musicList = [];

    for (var file in provider.allFiles) {
      final path = file.path.toLowerCase();
      if (path.endsWith('.mp3') ||
          path.endsWith('.flac') ||
          path.endsWith('.m4a') ||
          path.endsWith('.wav')) {
        musicCount++;
        musicList.add(file);
      } else if (path.contains('series') || path.contains('season')) {
        seriesCount++;
        seriesList.add(file);
      } else if (path.contains('anime')) {
        animeCount++;
        animeList.add(file);
      } else {
        moviesCount++;
        moviesList.add(file);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Media',
            style: EDesign.h3,
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.45,
            children: [
              _buildMediaCard(
                context,
                'Movies',
                '$moviesCount items',
                Icons.movie_outlined,
                EDesign.primaryStrong,
                moviesList,
              ),
              _buildMediaCard(
                context,
                'Series',
                '$seriesCount items',
                Icons.tv_outlined,
                EDesign.success,
                seriesList,
              ),
              _buildMediaCard(
                context,
                'Anime',
                '$animeCount items',
                Icons.animation,
                EDesign.warning,
                animeList,
              ),
              _buildMediaCard(
                context,
                'Music',
                '$musicCount items',
                Icons.music_note_outlined,
                EDesign.secondary,
                musicList,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    List<MediaItem> categoryItems,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(EDesign.r14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FolderDetailScreen(
              folderName: title,
              items: categoryItems,
            ),
          ),
        );
      },
      child: Container(
        decoration: EDesign.cardDecoration(radius: EDesign.r14),
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
                color: EDesign.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: EDesign.secondaryStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesRail(BuildContext context, LibraryProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Favorites', style: EDesign.h3),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: provider.favorites.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final fav = provider.favorites[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(EDesign.r14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(mediaPath: fav.path),
                      ),
                    );
                  },
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: EDesign.cardDecoration(),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite, color: EDesign.danger, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            fav.name,
                            style: EDesign.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
