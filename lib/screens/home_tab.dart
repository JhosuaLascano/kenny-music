import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'tabs.dart';
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
          final all = store.allSongs; // orden alfabético
          final albums = store.albums.take(12).toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            tooltip: 'Buscar',
                            onPressed: () => openSearch(context),
                            icon: const Icon(Icons.search_rounded),
                          ),
                        ],
                      ),
                    ),
                    const ScanBanner(),
                    if (empty) const EmptyLibrary(),
                    if (!empty) ...[
                      // Estilo "Destacados": tarjetas grandes deslizables.
                      if (store.homeLayout == 'featured') ...[
                        const SectionTitle('Destacadas'),
                        _FeaturedCarousel(
                          songs:
                              (store.mostPlayed.isNotEmpty
                                      ? store.mostPlayed
                                      : store.newest)
                                  .take(8)
                                  .toList(),
                        ),
                      ],
                      const StatsPanel(),
                      const SectionTitle('Álbumes y singles'),
                      SizedBox(
                        height: 190,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: albums.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, i) =>
                              AlbumCard(group: albums[i]),
                        ),
                      ),
                      SectionTitle(
                        'Toda la música',
                        action: 'Aleatorio',
                        onAction: () => audio.playSongs(
                          all,
                          start: DateTime.now().millisecond % all.length,
                          shuffle: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (store.homeLayout == 'grid')
                // Estilo "Cuadrícula": portadas de 3 en 3.
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.74,
                        ),
                    itemCount: all.length,
                    itemBuilder: (context, i) => _GridSong(
                      song: all[i],
                      onTap: () => audio.playSongs(all, start: i),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: all.length,
                  itemBuilder: (context, i) => SongTile(
                    song: all[i],
                    onTap: () => audio.playSongs(all, start: i),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: kTabBottomSpace),
              ),
            ],
          );
        },
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

/// Panel "Tu música": la canción que más escuchas y los minutos escuchados.
class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final top = store.mostPlayed.isEmpty ? null : store.mostPlayed.first;
    String fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );
    Widget stat(String value, String label, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x12FFFFFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x24FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TU MÚSICA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: top == null
                  ? null
                  : () => audio.playSongs(store.mostPlayed.take(50).toList()),
              child: Row(
                children: [
                  CoverArt(song: top, size: 72, radius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'La que más escuchas',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          top?.title ?? 'Todavía nada',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          top == null
                              ? 'Pon una canción para empezar'
                              : '${top.artist} · ${store.plays[top.id]} '
                                    '${store.plays[top.id] == 1 ? 'vez' : 'veces'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                stat(fmt(store.listenMinutes), 'minutos escuchados', accent),
                const SizedBox(width: 10),
                stat(
                  '${fmt(store.weekMinutes)} min',
                  'esta semana',
                  Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Canción en la cuadrícula del inicio.
class _GridSong extends StatelessWidget {
  const _GridSong({required this.song, required this.onTap});
  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => showSongMenu(context, song),
      child: LayoutBuilder(
        builder: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(song: song, size: c.maxWidth, radius: 10),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: kMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjetas grandes deslizables (estilo "Destacados").
class _FeaturedCarousel extends StatelessWidget {
  const _FeaturedCarousel({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => audio.playSongs(songs, start: i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                CoverArt(song: songs[i], size: 220, radius: 0),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xB3000000)],
                        stops: [0.45, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        songs[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        songs[i].artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
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
    );
  }
}
