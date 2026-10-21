import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../widgets/e_player_logo.dart';
import '../../../widgets/e_player_components.dart';
import '../../../ui/theme/e_design_tokens.dart';
import '../../library/domain/library_provider.dart';
import '../../library/domain/media_search_engine.dart';
import '../../library/ui/folder_detail_screen.dart';
import '../../../core/models/media_item.dart';
import '../../player/ui/player_screen.dart';
import '../../casting/ui/casting_screen.dart';
import '../../settings/ui/settings_screen.dart';

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

  String _formatDuration(int ms) {
    if (ms <= 0) return '00:00';
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: EDesign.appBackground,
          appBar: _buildAppBar(context),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildCategoryChips(),
                const SizedBox(height: 24),
                if (_isSearching && _searchQuery.isNotEmpty)
                  _buildSearchResults(context, provider)
                else ...[
                  _buildContinueWatching(context, provider),
                  const SizedBox(height: 28),
                  _buildMyMedia(context, provider),
                  if (provider.favorites.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildFavoritesRail(context, provider),
                  ],
                ],
                const SizedBox(height: 36),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: EDesign.appBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
      title: _isSearching
          ? Container(
              height: 42,
              decoration: BoxDecoration(
                color: EDesign.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EDesign.border),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: EDesign.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search movies, series, anime...',
                  hintStyle: TextStyle(color: EDesign.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: EDesign.textSecondary, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
            )
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                EPlayerLogo(height: 26, markOnly: true),
                SizedBox(width: 8),
                Text(
                  'E-Player',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: EDesign.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
      actions: [
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.close, color: EDesign.textPrimary, size: 22),
            tooltip: 'Close Search',
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          )
        else ...[
          IconButton(
            icon: const EVectorIcon(name: 'cast', size: 20, color: EDesign.textPrimary),
            tooltip: 'Cast Media',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CastingScreen()),
              );
            },
          ),
          IconButton(
            icon: const EVectorIcon(name: 'search', size: 20, color: EDesign.textPrimary),
            tooltip: 'Search Media',
            onPressed: () {
              setState(() => _isSearching = true);
            },
          ),
          IconButton(
            icon: const EVectorIcon(name: 'settings', size: 20, color: EDesign.textPrimary),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['All', 'Videos', 'Folders', 'Network'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: categories.map((cat) {
          final isActive = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() => _selectedCategory = cat);
                if (cat == 'Network') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CastingScreen()),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? EDesign.primary : EDesign.surface,
                  border: Border.all(
                    color: isActive ? EDesign.primary : EDesign.border,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: EDesign.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isActive ? Colors.black : EDesign.textSecondary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
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
    final bool hasRealRecent = recent != null;

    final String title = hasRealRecent ? recent.name : 'The Last Horizon.mkv';
    final int positionMs = hasRealRecent ? recent.lastPositionMs : 5056000; // ~01:24:16
    final int durationMs = hasRealRecent && recent.durationMs > 0 ? recent.durationMs : 8130000; // ~02:15:30
    final double progressValue = (durationMs > 0) ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.62;
    final String timeLabel = '${_formatDuration(positionMs)} / ${_formatDuration(durationMs)}';

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
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: EDesign.textPrimary,
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.5), size: 22),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(EDesign.r18),
            onTap: () {
              if (hasRealRecent) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: recent.path)),
                );
              } else if (provider.allFiles.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: provider.allFiles.first.path)),
                );
              } else {
                const demoPath = 'D:\\E-player\\test.mp4';
                if (File(demoPath).existsSync()) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlayerScreen(mediaPath: demoPath)),
                  );
                }
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(EDesign.r18),
                border: Border.all(color: EDesign.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cinematic Mountain Backdrop
                    const Image(
                      image: AssetImage('assets/thumbnails/demo_landscape.png'),
                      fit: BoxFit.cover,
                    ),

                    // Multi-stop Gradient Vignette
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.45, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.black.withValues(alpha: 0.45),
                            EDesign.appBackground.withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                    ),

                    // Top Badges
                    Positioned(
                      top: 14,
                      left: 14,
                      right: 14,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: EDesign.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: EDesign.primary.withValues(alpha: 0.7)),
                            ),
                            child: const Text(
                              'CONTINUE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: EDesign.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Text(
                              '4K',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Center Glowing Play Button
                    Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: EDesign.primary,
                          boxShadow: [
                            BoxShadow(
                              color: EDesign.primary.withValues(alpha: 0.65),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 32,
                        ),
                      ),
                    ),

                    // Bottom Metadata & Scrubber
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: EDesign.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                timeLabel,
                                style: const TextStyle(
                                  color: EDesign.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${(progressValue * 100).toInt()}% watched',
                                style: const TextStyle(
                                  color: EDesign.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progressValue,
                              minHeight: 3.5,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(EDesign.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

    final displayMoviesCount = moviesCount > 0 ? moviesCount : 24;
    final displaySeriesCount = seriesCount > 0 ? seriesCount : 12;
    final displayAnimeCount = animeCount > 0 ? animeCount : 18;
    final displayMusicCount = musicCount > 0 ? musicCount : 32;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Media',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: EDesign.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.42,
            children: [
              _buildBentoMediaCard(
                context: context,
                title: 'Movies',
                subtitle: '$displayMoviesCount items',
                iconName: 'video',
                accentColor: EDesign.primaryStrong,
                thumbnailAsset: 'assets/thumbnails/demo_city.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderDetailScreen(
                        folderName: 'Movies',
                        items: moviesList,
                      ),
                    ),
                  );
                },
              ),
              _buildBentoMediaCard(
                context: context,
                title: 'Series',
                subtitle: '$displaySeriesCount items',
                iconName: 'star',
                accentColor: EDesign.success,
                thumbnailAsset: 'assets/thumbnails/demo_documentary.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderDetailScreen(
                        folderName: 'Series',
                        items: seriesList,
                      ),
                    ),
                  );
                },
              ),
              _buildBentoMediaCard(
                context: context,
                title: 'Anime',
                subtitle: '$displayAnimeCount items',
                iconName: 'heart',
                accentColor: EDesign.warning,
                thumbnailAsset: 'assets/thumbnails/demo_anime.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderDetailScreen(
                        folderName: 'Anime',
                        items: animeList,
                      ),
                    ),
                  );
                },
              ),
              _buildBentoMediaCard(
                context: context,
                title: 'Music',
                subtitle: '$displayMusicCount items',
                iconName: 'audio',
                accentColor: EDesign.secondary,
                thumbnailAsset: 'assets/thumbnails/demo_music.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderDetailScreen(
                        folderName: 'Music',
                        items: musicList,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoMediaCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String iconName,
    required Color accentColor,
    required String thumbnailAsset,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(EDesign.r16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(EDesign.r16),
          border: Border.all(color: EDesign.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Darkened Artwork Scrim
            Image(
              image: AssetImage(thumbnailAsset),
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    EDesign.surface.withValues(alpha: 0.88),
                    EDesign.appBackground.withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),

            // Card Foreground Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                    ),
                    alignment: Alignment.center,
                    child: EVectorIcon(
                      name: iconName,
                      size: 18,
                      color: accentColor,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: EDesign.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: EDesign.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, LibraryProvider provider) {
    final matches = provider.allFiles
        .where((i) => MediaSearchEngine.matchesQuery(i, _searchQuery))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Results (${matches.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: EDesign.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (matches.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: EDesign.surface,
                borderRadius: BorderRadius.circular(EDesign.r14),
                border: Border.all(color: EDesign.border),
              ),
              child: Center(
                child: Text(
                  'No media matching "$_searchQuery"',
                  style: const TextStyle(color: EDesign.textSecondary),
                ),
              ),
            )
          else
            ...matches.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: EDesign.surface,
                  borderRadius: BorderRadius.circular(EDesign.r12),
                  border: Border.all(color: EDesign.border),
                ),
                child: ListTile(
                  leading: const Icon(Icons.play_circle_fill, color: EDesign.primary, size: 32),
                  title: Text(item.name, style: const TextStyle(color: EDesign.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    EDesign.formatBytes(item.sizeBytes),
                    style: const TextStyle(color: EDesign.textMuted, fontSize: 12),
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

  Widget _buildFavoritesRail(BuildContext context, LibraryProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Favorites',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: EDesign.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: provider.favorites.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                    width: 190,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EDesign.surface,
                      borderRadius: BorderRadius.circular(EDesign.r14),
                      border: Border.all(color: EDesign.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite, color: EDesign.danger, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            fav.name,
                            style: const TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
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
