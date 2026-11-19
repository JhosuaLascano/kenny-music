import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'settings_screen.dart';
import 'song_list_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onGoTo});
  final ValueChanged<int> onGoTo;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final empty = store.songs.isEmpty;
          var recent = store.recentSongs.take(4).toList();
          if (recent.isEmpty) recent = store.newest.take(4).toList();
          final albums = store.albums.take(12).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: kTabBottomSpace),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 34,
                        height: 34,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Kenny '),
                            TextSpan(
                              text: 'Music',
                              style: TextStyle(color: accent),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Agregar música',
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        builder: (_) => const SafeArea(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: AddMusicButtons(),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                    IconButton(
                      tooltip: 'Ajustes',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
              const ScanBanner(),
              if (empty) const EmptyLibrary(),
              if (!empty) ...[
                SectionTitle(
                  store.recentSongs.isEmpty ? 'Recién agregadas' : 'Recientes',
                  action: 'Ver todo',
                  onAction: () => onGoTo(2),
                ),
                for (var i = 0; i < recent.length; i++)
                  SongTile(
                    song: recent[i],
                    onTap: () => audio.playSongs(recent, start: i),
                  ),
                const SectionTitle('Para ti'),
                SizedBox(
                  height: 124,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _MoodCard(
                        color: accent,
                        icon: Icons.star_rounded,
                        label: 'Favoritas',
                        onTap: () => openList(
                          context,
                          'Favoritas',
                          () => store.favoriteSongs,
                        ),
                      ),
                      _MoodCard(
                        color: const Color(0xFF5B8DEF),
                        icon: Icons.shuffle_rounded,
                        label: 'Aleatorio',
                        onTap: () {
                          final all = store.allSongs;
                          audio.playSongs(
                            all,
                            start: DateTime.now().millisecond % all.length,
                            shuffle: true,
                          );
                          openPlayer(context);
                        },
                      ),
                      _MoodCard(
                        color: const Color(0xFFE2557A),
                        icon: Icons.bolt_rounded,
                        label: 'Más escuchadas',
                        onTap: () => openList(
                          context,
                          'Más escuchadas',
                          () => store.mostPlayed.take(50).toList(),
                        ),
                      ),
                      _MoodCard(
                        color: const Color(0xFF34D399),
                        icon: Icons.new_releases_rounded,
                        label: 'Recién agregadas',
                        onTap: () => openList(
                          context,
                          'Recién agregadas',
                          () => store.newest.take(50).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Álbumes y singles'),
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: albums.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => AlbumCard(group: albums[i]),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 34, color: const Color(0xFF0B0B0D)),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF0B0B0D),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.group, this.size = 140});
  final SongGroup group;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openList(
        context,
        group.name,
        () => _albumSongs(group),
        subtitle: group.subtitle,
      ),
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(song: group.first, size: size, radius: 12),
            const SizedBox(height: 8),
            Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              group.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

List<Song> _albumSongs(SongGroup g) =>
    store.songs.values
        .where((s) => s.album == g.name && s.artist == g.subtitle)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
