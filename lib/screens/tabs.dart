import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../cover_color.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'home_tab.dart';
import 'playlist_screen.dart';
import 'search_tab.dart';
import 'settings_screen.dart';
import 'song_list_screen.dart';

/// Pestaña con el estilo de una playlist: fondo en degradado con el color de
/// una portada, título grande, botones redondos y contenido debajo.
class _TintedTab extends StatelessWidget {
  const _TintedTab({
    required this.title,
    required this.subtitle,
    required this.colorFrom,
    required this.actions,
    required this.slivers,
  });
  final String title;
  final String subtitle;
  final Song? colorFrom;
  final List<Widget> actions;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final file = colorFrom?.cover == null
        ? null
        : store.resolve(colorFrom!.cover!);
    return FutureBuilder<Color>(
      future: coverColor(file, const Color(0xFF4A4060)),
      initialData: cachedCoverColor(file),
      builder: (context, snap) {
        final b = HSLColor.fromColor(snap.data ?? const Color(0xFF4A4060));
        final top = b
            .withSaturation((b.saturation * 0.9).clamp(0.0, 0.6))
            .withLightness(0.3)
            .toColor();
        final mid = b
            .withSaturation((b.saturation * 0.8).clamp(0.0, 0.5))
            .withLightness(0.15)
            .toColor();
        final soft = b
            .withSaturation(b.saturation.clamp(0.0, 0.6))
            .withLightness(0.8)
            .toColor();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, mid, kBg],
              stops: const [0, 0.45, 0.9],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 15, color: soft),
                        ),
                        const SizedBox(height: 18),
                        Row(children: actions),
                      ],
                    ),
                  ),
                ),
                ...slivers,
                const SliverToBoxAdapter(
                  child: SizedBox(height: kTabBottomSpace),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Botón blanco grande (como "Reproducir" en la playlist).
Widget _pillButton(IconData icon, String label, VoidCallback? onTap) =>
    Expanded(
      child: SizedBox(
        height: 50,
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF111111),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );

/// Botón redondo oscuro translúcido.
Widget _circleButton(IconData icon, String tip, VoidCallback onTap) => Padding(
  padding: const EdgeInsets.only(left: 12),
  child: Semantics(
    button: true,
    label: tip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x33000000),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    ),
  ),
);

String _minutes(List<Song> songs) {
  final m = songs.fold<int>(0, (a, s) => a + s.durationMs) ~/ 60000;
  return m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60} min';
}

/// Fila grande con portada, título, detalle y flecha.
class _BigRow extends StatelessWidget {
  const _BigRow({
    required this.leading,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final Widget leading;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de color (Favoritas / Todas las canciones).
class _ColorCard extends StatelessWidget {
  const _ColorCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final List<Color> colors;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 104,
          padding: const EdgeInsets.all(14),
          // Vidrio neutro: sin colores genéricos, toma el tono del fondo.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0x1AFFFFFF),
            border: Border.all(color: const Color(0x29FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 26),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pestaña "Listas": favoritas, todas las canciones y playlists.
class ListsTab extends StatelessWidget {
  const ListsTab({super.key});

  Future<void> _newPlaylist(BuildContext context) async {
    final name = await promptText(
      context,
      title: 'Nueva playlist',
      action: 'Crear',
    );
    if (name == null) return;
    final p = store.createPlaylist(name);
    if (context.mounted) openPlaylist(context, p);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final firstList = store.playlists
            .map((p) => store.songsOf(p))
            .firstWhere((l) => l.isNotEmpty, orElse: () => const <Song>[]);
        return _TintedTab(
          title: 'Listas',
          subtitle:
              '${store.playlists.length} ${store.playlists.length == 1 ? 'playlist' : 'playlists'}',
          colorFrom: firstList.isNotEmpty
              ? firstList.first
              : (store.favoriteSongs.isNotEmpty
                    ? store.favoriteSongs.first
                    : null),
          actions: [
            _pillButton(
              CupertinoIcons.add,
              'Nueva playlist',
              () => _newPlaylist(context),
            ),
            _circleButton(CupertinoIcons.shuffle, 'Aleatorio con todo', () {
              final all = store.allSongs;
              if (all.isEmpty) return;
              audio.playSongs(
                all,
                start: DateTime.now().millisecond % all.length,
                shuffle: true,
                from: 'tu biblioteca',
              );
            }),
          ],
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    _ColorCard(
                      colors: const [Color(0xFFF59E0B), Color(0xFFB45309)],
                      icon: CupertinoIcons.star_fill,
                      title: 'Favoritas',
                      detail: '${store.favorites.length} canciones',
                      onTap: () => openList(
                        context,
                        'Favoritas',
                        () => store.favoriteSongs,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ColorCard(
                      colors: const [Color(0xFF6366F1), Color(0xFF3730A3)],
                      icon: CupertinoIcons.music_note_2,
                      title: 'Todas',
                      detail: '${store.songs.length} canciones',
                      onTap: () => openList(
                        context,
                        'Todas las canciones',
                        () => store.allSongs,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (store.playlists.isNotEmpty)
              const SliverToBoxAdapter(child: SectionTitle('Mis playlists')),
            SliverList.builder(
              itemCount: store.playlists.length,
              itemBuilder: (context, i) {
                final p = store.playlists[i];
                final songs = store.songsOf(p);
                return _BigRow(
                  leading: PlaylistCover(playlist: p, size: 64),
                  title: p.name,
                  detail: '${songs.length} canciones · ${_minutes(songs)}',
                  onTap: () => openPlaylist(context, p),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Pestaña "Carpeta": canciones agrupadas por la carpeta del celular.
class FolderTab extends StatelessWidget {
  const FolderTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final folders = store.folders;
        return _TintedTab(
          title: 'Carpetas',
          subtitle:
              '${folders.length} ${folders.length == 1 ? 'carpeta' : 'carpetas'} · ${store.songs.length} canciones',
          colorFrom: folders.isEmpty ? null : folders.first.first,
          actions: [
            _pillButton(
              Platform.isAndroid
                  ? CupertinoIcons.search
                  : CupertinoIcons.arrow_down_doc,
              Platform.isAndroid ? 'Buscar música' : 'Importar',
              () => Platform.isAndroid ? runScan(context) : runImport(context),
            ),
            if (Platform.isAndroid)
              _circleButton(
                CupertinoIcons.arrow_down_doc,
                'Importar archivos',
                () => runImport(context),
              ),
          ],
          slivers: [
            const SliverToBoxAdapter(child: ScanBanner()),
            if (store.songs.isEmpty)
              const SliverToBoxAdapter(child: EmptyLibrary()),
            SliverList.builder(
              itemCount: folders.length,
              itemBuilder: (context, i) {
                final f = folders[i];
                return _BigRow(
                  leading: SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      children: [
                        CoverArt(song: f.first, size: 64, radius: 12),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xB3000000),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              CupertinoIcons.folder_fill,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: f.name,
                  detail: '${f.subtitle} · ${_minutes(f.songs)}',
                  onTap: () => openList(
                    context,
                    f.name,
                    () => store.folders
                        .firstWhere((g) => g.name == f.name, orElse: () => f)
                        .songs,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Pestaña "Álbum": portadas grandes en cuadrícula.
class AlbumsTab extends StatelessWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final albums = store.albums;
        return _TintedTab(
          title: 'Álbumes',
          subtitle:
              '${albums.length} ${albums.length == 1 ? 'álbum' : 'álbumes'}',
          colorFrom: albums.isEmpty ? null : albums.first.first,
          actions: [
            _pillButton(
              CupertinoIcons.play_fill,
              'Reproducir todo',
              albums.isEmpty
                  ? null
                  : () => audio.playSongs([
                      for (final a in albums) ...a.songs,
                    ], from: 'Álbumes'),
            ),
            _circleButton(CupertinoIcons.shuffle, 'Aleatorio', () {
              final all = [for (final a in albums) ...a.songs];
              if (all.isEmpty) return;
              audio.playSongs(
                all,
                start: DateTime.now().millisecond % all.length,
                shuffle: true,
                from: 'Álbumes',
              );
            }),
          ],
          slivers: [
            if (store.songs.isEmpty)
              const SliverToBoxAdapter(child: EmptyLibrary()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverLayoutBuilder(
                builder: (context, c) {
                  final cols = c.crossAxisExtent > 600 ? 4 : 2;
                  final size = (c.crossAxisExtent - 16 * (cols - 1)) / cols;
                  return SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 16,
                      mainAxisExtent: size + 52,
                    ),
                    itemCount: albums.length,
                    itemBuilder: (context, i) =>
                        AlbumCard(group: albums[i], size: size),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Pestaña "Más": menú con Apariencia, Reproducción, Importar y más.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) =>
      MoreMenu(onSearch: () => openSearch(context));
}

void openSearch(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const Scaffold(body: SearchTab(active: true)),
    ),
  );
}
