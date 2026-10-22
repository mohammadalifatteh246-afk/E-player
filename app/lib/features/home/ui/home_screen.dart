import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

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
import '../domain/media_group_service.dart';

/// Screen 2: Responsive Cyber-Stitch Home Screen (Android & Desktop)
/// Features compact card architecture based on user-spec wireframe:
/// 1. Top Bar with dedicated Filter control & search integration
/// 2. Compact History card (responsive, thumb-safe, max height ~150px)
/// 3. Compact "Create Group (+)" action card with group creation dialog
/// 4. Compact "Videos (+)" action card with folder/file ingest triggers
/// 5. Compact 4-category Bento media grid (Movies, Series, Anime, Music)
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

  // Active filter state
  SortField _currentSort = SortField.date;
  SortOrder _currentOrder = SortOrder.descending;

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
    return Consumer2<LibraryProvider, MediaGroupService>(
      builder: (context, provider, groupService, child) {
        return Scaffold(
          backgroundColor: EDesign.appBackground,
          appBar: _buildAppBar(context, provider),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 850;
              final maxContentWidth = isDesktop ? 1200.0 : double.infinity;
              final horizontalPadding = isDesktop ? 32.0 : 16.0;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Quick Category Chips
                        _buildCategoryChips(),
                        const SizedBox(height: 16),

                        // Search Results or Normal Content
                        if (_isSearching && _searchQuery.isNotEmpty)
                          _buildSearchResults(context, provider)
                        else ...[
                          // 2. Section: History (Compact & Responsive)
                          _buildHistorySection(context, provider, isDesktop),
                          const SizedBox(height: 20),

                          // 3. Section: Create Group & Videos (Quick Actions based on sketch)
                          _buildActionCardsRow(context, provider, groupService, isDesktop),
                          const SizedBox(height: 24),

                          // 4. Custom Groups Carousel (if user created any)
                          if (groupService.groups.isNotEmpty) ...[
                            _buildCustomGroupsSection(context, groupService, provider, isDesktop),
                            const SizedBox(height: 24),
                          ],

                          // 5. Section: Media Categories (Compact Bento Grid)
                          _buildCompactMediaGrid(context, provider, isDesktop),
                          const SizedBox(height: 24),

                          // 6. Favorites Rail (if any exist)
                          if (provider.favorites.isNotEmpty) ...[
                            _buildFavoritesRail(context, provider, isDesktop),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- APP BAR ---
  PreferredSizeWidget _buildAppBar(BuildContext context, LibraryProvider provider) {
    return AppBar(
      backgroundColor: EDesign.appBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      title: _isSearching
          ? Container(
              height: 40,
              decoration: BoxDecoration(
                color: EDesign.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: EDesign.border),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: EDesign.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search videos, audio, series...',
                  hintStyle: const TextStyle(color: EDesign.textMuted, fontSize: 13),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(10),
                    child: EVectorIcon(name: 'search', size: 16, color: EDesign.primary),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: EDesign.textSecondary),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
            )
          : Row(
              children: [
                const EPlayerLogo(height: 26, markOnly: true),
                const SizedBox(width: 10),
                const Text(
                  'E-Player',
                  style: TextStyle(
                    color: EDesign.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: EDesign.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EDesign.primary.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: EDesign.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        if (!_isSearching) ...[
          // Filter Button (matches wireframe 'filter' on top right)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showFilterSheet(context, provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: EDesign.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: EDesign.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EVectorIcon(name: 'filter', size: 14, color: EDesign.primary),
                    SizedBox(width: 6),
                    Text(
                      'Filter',
                      style: TextStyle(
                        color: EDesign.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const EVectorIcon(name: 'search', size: 19, color: EDesign.textPrimary),
            tooltip: 'Search Media',
            onPressed: () => setState(() => _isSearching = true),
          ),
          IconButton(
            icon: const EVectorIcon(name: 'cast', size: 19, color: EDesign.textPrimary),
            tooltip: 'Cast Media',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CastingScreen()),
              );
            },
          ),
          IconButton(
            icon: const EVectorIcon(name: 'settings', size: 19, color: EDesign.textPrimary),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  // --- 1. CATEGORY CHIPS ---
  Widget _buildCategoryChips() {
    final categories = ['All', 'History', 'Videos', 'Groups', 'Audio', 'Favorites'];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isActive = _selectedCategory == cat;

          return InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () {
              setState(() => _selectedCategory = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? EDesign.primary : EDesign.surface,
                border: Border.all(
                  color: isActive ? EDesign.primary : EDesign.border,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(17),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: EDesign.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isActive ? Colors.black : EDesign.textSecondary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 2. HISTORY SECTION (COMPACT RESUME) ---
  Widget _buildHistorySection(BuildContext context, LibraryProvider provider, bool isDesktop) {
    if (_selectedCategory != 'All' && _selectedCategory != 'History') {
      return const SizedBox.shrink();
    }

    final recent = provider.recentFiles.isNotEmpty ? provider.recentFiles.first : null;
    final bool hasRealRecent = recent != null;

    final String title = hasRealRecent ? recent.name : 'The Last Horizon (4K Remaster)';
    final int positionMs = hasRealRecent ? recent.lastPositionMs : 5056000;
    final int durationMs = hasRealRecent && recent.durationMs > 0 ? recent.durationMs : 8130000;
    final double progressValue = (durationMs > 0) ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.62;
    final String timeLabel = '${_formatDuration(positionMs)} / ${_formatDuration(durationMs)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                EVectorIcon(name: 'history', size: 16, color: EDesign.primary),
                SizedBox(width: 8),
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: EDesign.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            if (provider.recentFiles.length > 1)
              Text(
                '${provider.recentFiles.length} recent',
                style: const TextStyle(
                  fontSize: 12,
                  color: EDesign.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Compact History Container (Max Height ~130-150px)
        InkWell(
          borderRadius: BorderRadius.circular(14),
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
            height: isDesktop ? 130 : 120,
            decoration: BoxDecoration(
              color: EDesign.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: EDesign.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                // 16:9 Compact Thumbnail Preview
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const Image(
                        image: AssetImage('assets/thumbnails/demo_landscape.png'),
                        fit: BoxFit.cover,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      // Mini Play Button Badge
                      Center(
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: EDesign.primary,
                            boxShadow: [
                              BoxShadow(
                                color: EDesign.primary.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 22,
                          ),
                        ),
                      ),
                      // Resolution Pill
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '4K HDR',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: EDesign.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Meta & Progress Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: EDesign.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'RESUME WATCHING',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: EDesign.primary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: EDesign.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),

                        // Progress Bar & Duration
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  timeLabel,
                                  style: const TextStyle(
                                    color: EDesign.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${(progressValue * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: EDesign.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progressValue,
                                minHeight: 3,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation<Color>(EDesign.primary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 3. ACTION CARDS: CREATE GROUP (+) & VIDEOS (+) ---
  Widget _buildActionCardsRow(
    BuildContext context,
    LibraryProvider provider,
    MediaGroupService groupService,
    bool isDesktop,
  ) {
    if (_selectedCategory != 'All' && _selectedCategory != 'Groups' && _selectedCategory != 'Videos') {
      return const SizedBox.shrink();
    }

    // Two compact action cards side by side (matches user reference wireframe)
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Row(
          children: [
            // Card 1: Create Group (+)
            SizedBox(
              width: cardWidth,
              child: _buildTacticalActionCard(
                title: 'Create Group',
                subtitle: '${groupService.groups.length} groups created',
                iconName: 'group',
                accentColor: const Color(0xFF00E5FF),
                onTap: () => _showCreateGroupDialog(context, groupService),
                onPlusTap: () => _showCreateGroupDialog(context, groupService),
              ),
            ),
            const SizedBox(width: 12),

            // Card 2: Videos (+)
            SizedBox(
              width: cardWidth,
              child: _buildTacticalActionCard(
                title: 'Videos',
                subtitle: '${provider.allFiles.length} media indexed',
                iconName: 'video',
                accentColor: const Color(0xFF21D79A),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderDetailScreen(
                        folderName: 'All Videos',
                        items: provider.allFiles,
                      ),
                    ),
                  );
                },
                onPlusTap: () => _showAddVideosSheet(context, provider),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTacticalActionCard({
    required String title,
    required String subtitle,
    required String iconName,
    required Color accentColor,
    required VoidCallback onTap,
    required VoidCallback onPlusTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EDesign.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EDesign.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon & Tactical (+) Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: EVectorIcon(name: iconName, size: 18, color: accentColor),
                ),

                // Tactical Plus Button in Rounded Box (As drawn in sketch)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onPlusTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.2),
                    ),
                    child: Center(
                      child: EVectorIcon(name: 'plus', size: 14, color: accentColor),
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Labels
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: EDesign.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: EDesign.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. CUSTOM USER GROUPS SECTION ---
  Widget _buildCustomGroupsSection(
    BuildContext context,
    MediaGroupService groupService,
    LibraryProvider provider,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Groups & Playlists',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: EDesign.textPrimary,
              ),
            ),
            IconButton(
              icon: const EVectorIcon(name: 'plus', size: 16, color: EDesign.primary),
              tooltip: 'Create New Group',
              onPressed: () => _showCreateGroupDialog(context, groupService),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 85,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: groupService.groups.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final group = groupService.groups[index];
              final groupItems = provider.allFiles.where((f) => group.itemPaths.contains(f.path)).toList();

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderDetailScreen(
                        folderName: group.title,
                        items: groupItems.isNotEmpty ? groupItems : provider.allFiles.take(8).toList(),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EDesign.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: group.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: group.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: EVectorIcon(name: group.iconName, size: 20, color: group.color),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              group.title,
                              style: const TextStyle(
                                color: EDesign.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${group.itemPaths.length} items',
                              style: const TextStyle(
                                color: EDesign.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
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
    );
  }

  // --- 5. COMPACT BENTO MEDIA GRID ---
  Widget _buildCompactMediaGrid(BuildContext context, LibraryProvider provider, bool isDesktop) {
    if (_selectedCategory != 'All' && _selectedCategory != 'Videos' && _selectedCategory != 'Audio') {
      return const SizedBox.shrink();
    }

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
      if (path.endsWith('.mp3') || path.endsWith('.flac') || path.endsWith('.m4a') || path.endsWith('.wav')) {
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

    final displayMovies = moviesCount > 0 ? moviesCount : 24;
    final displaySeries = seriesCount > 0 ? seriesCount : 12;
    final displayAnime = animeCount > 0 ? animeCount : 18;
    final displayMusic = musicCount > 0 ? musicCount : 32;

    final crossAxisCount = isDesktop ? 4 : 2;
    final childAspectRatio = isDesktop ? 1.8 : 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Media Library',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EDesign.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: childAspectRatio,
          children: [
            _buildCompactCategoryCard(
              title: 'Movies',
              subtitle: '$displayMovies items',
              iconName: 'video',
              accentColor: EDesign.primaryStrong,
              thumbnailAsset: 'assets/thumbnails/demo_city.png',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FolderDetailScreen(folderName: 'Movies', items: moviesList),
                  ),
                );
              },
            ),
            _buildCompactCategoryCard(
              title: 'Series',
              subtitle: '$displaySeries items',
              iconName: 'star',
              accentColor: EDesign.success,
              thumbnailAsset: 'assets/thumbnails/demo_documentary.png',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FolderDetailScreen(folderName: 'Series', items: seriesList),
                  ),
                );
              },
            ),
            _buildCompactCategoryCard(
              title: 'Anime',
              subtitle: '$displayAnime items',
              iconName: 'heart',
              accentColor: EDesign.warning,
              thumbnailAsset: 'assets/thumbnails/demo_anime.png',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FolderDetailScreen(folderName: 'Anime', items: animeList),
                  ),
                );
              },
            ),
            _buildCompactCategoryCard(
              title: 'Music',
              subtitle: '$displayMusic items',
              iconName: 'audio',
              accentColor: EDesign.secondary,
              thumbnailAsset: 'assets/thumbnails/demo_music.png',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FolderDetailScreen(folderName: 'Music', items: musicList),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactCategoryCard({
    required String title,
    required String subtitle,
    required String iconName,
    required Color accentColor,
    required String thumbnailAsset,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: EDesign.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EDesign.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0.15,
              child: Image.asset(thumbnailAsset, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: EVectorIcon(name: iconName, size: 16, color: accentColor),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: EDesign.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: EDesign.textMuted,
                          fontSize: 10,
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

  // --- 6. FAVORITES RAIL ---
  Widget _buildFavoritesRail(BuildContext context, LibraryProvider provider, bool isDesktop) {
    if (_selectedCategory != 'All' && _selectedCategory != 'Favorites') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Favorites',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EDesign.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: provider.favorites.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = provider.favorites[index];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)),
                  );
                },
                child: Container(
                  width: 130,
                  decoration: BoxDecoration(
                    color: EDesign.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EDesign.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const Image(
                              image: AssetImage('assets/thumbnails/demo_landscape.png'),
                              fit: BoxFit.cover,
                            ),
                            Center(
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.6),
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            color: EDesign.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
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
    );
  }

  // --- SEARCH RESULTS VIEW ---
  Widget _buildSearchResults(BuildContext context, LibraryProvider provider) {
    final filtered = provider.allFiles.where((f) {
      return f.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              const EVectorIcon(name: 'search', size: 36, color: EDesign.textMuted),
              const SizedBox(height: 12),
              Text(
                'No media matching "$_searchQuery"',
                style: const TextStyle(color: EDesign.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const Divider(color: EDesign.border, height: 1),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: EDesign.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: EVectorIcon(name: 'video', size: 16, color: EDesign.primary),
            ),
          ),
          title: Text(
            item.name,
            style: const TextStyle(color: EDesign.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            p.dirname(item.path),
            style: const TextStyle(color: EDesign.textMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.play_circle_fill_rounded, color: EDesign.primary, size: 24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlayerScreen(mediaPath: item.path)),
            );
          },
        );
      },
    );
  }

  // --- MODALS & DIALOGS ---

  /// Opens the Cyber-Stitch Filter Sheet (triggered by top right 'filter' button)
  void _showFilterSheet(BuildContext context, LibraryProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.elevatedBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          EVectorIcon(name: 'filter', size: 18, color: EDesign.primary),
                          SizedBox(width: 8),
                          Text('Filter & Sort Library', style: EDesign.h3),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: EDesign.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Sort By', style: TextStyle(color: EDesign.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('Recently Played', _currentSort == SortField.date, () {
                        setModalState(() => _currentSort = SortField.date);
                        provider.setSort(SortField.date, _currentOrder);
                      }),
                      _buildFilterChip('Name (A-Z)', _currentSort == SortField.name, () {
                        setModalState(() => _currentSort = SortField.name);
                        provider.setSort(SortField.name, _currentOrder);
                      }),
                      _buildFilterChip('Duration', _currentSort == SortField.duration, () {
                        setModalState(() => _currentSort = SortField.duration);
                        provider.setSort(SortField.duration, _currentOrder);
                      }),
                      _buildFilterChip('File Size', _currentSort == SortField.size, () {
                        setModalState(() => _currentSort = SortField.size);
                        provider.setSort(SortField.size, _currentOrder);
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Order', style: TextStyle(color: EDesign.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFilterChip('Descending (Newest / Largest)', _currentOrder == SortOrder.descending, () {
                        setModalState(() => _currentOrder = SortOrder.descending);
                        provider.setSort(_currentSort, SortOrder.descending);
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Ascending', _currentOrder == SortOrder.ascending, () {
                        setModalState(() => _currentOrder = SortOrder.ascending);
                        provider.setSort(_currentSort, SortOrder.ascending);
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: EDesign.primary,
      backgroundColor: EDesign.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : EDesign.textPrimary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: isSelected ? EDesign.primary : EDesign.border),
    );
  }

  /// Opens the Create Group Dialog (triggered by Create Group '+' button)
  void _showCreateGroupDialog(BuildContext context, MediaGroupService groupService) {
    final titleController = TextEditingController();
    Color selectedColor = const Color(0xFF00E5FF);
    final colors = [
      const Color(0xFF00E5FF),
      const Color(0xFF7B42FF),
      const Color(0xFF21D79A),
      const Color(0xFFFFB547),
      const Color(0xFFFF5C72),
      const Color(0xFFE741FF),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: EDesign.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: EDesign.border),
              ),
              title: const Row(
                children: [
                  EVectorIcon(name: 'group', size: 20, color: EDesign.primary),
                  SizedBox(width: 8),
                  Text('Create New Group', style: TextStyle(color: EDesign.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Group Title', style: TextStyle(color: EDesign.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    style: const TextStyle(color: EDesign.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. 4K Anime, Study Beats...',
                      hintStyle: const TextStyle(color: EDesign.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: EDesign.appBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: EDesign.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: EDesign.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: EDesign.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Accent Color', style: TextStyle(color: EDesign.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: colors.map((col) {
                      final isPicked = selectedColor == col;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedColor = col),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPicked ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: EDesign.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EDesign.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final name = titleController.text.trim();
                    if (name.isNotEmpty) {
                      await groupService.createGroup(
                        title: name,
                        color: selectedColor,
                      );
                      if (context.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Opens the Add Videos action sheet (triggered by Videos '+' button)
  void _showAddVideosSheet(BuildContext context, LibraryProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EDesign.elevatedBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  EVectorIcon(name: 'video', size: 18, color: EDesign.success),
                  SizedBox(width: 8),
                  Text('Add Videos to Library', style: EDesign.h3),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EDesign.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const EVectorIcon(name: 'folder', size: 20, color: EDesign.primary),
                ),
                title: const Text('Scan Folder', style: TextStyle(color: EDesign.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: const Text('Auto-detect all video and audio files in directory', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await provider.scanDirectory();
                },
              ),
              const Divider(color: EDesign.border, height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EDesign.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const EVectorIcon(name: 'video', size: 20, color: EDesign.success),
                ),
                title: const Text('Add Single Video File', style: TextStyle(color: EDesign.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: const Text('Pick MKV, MP4, AVI, WebM file directly', style: TextStyle(color: EDesign.textMuted, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await provider.pickFile();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
