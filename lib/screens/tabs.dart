import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'explore_tab.dart';
import 'home_shell.dart';
import 'search_tab.dart';
import 'settings_screen.dart';
import 'song_list_screen.dart';

Widget _title(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
  child: Text(
    text,
    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
  ),
);

Widget _iconBox(BuildContext context, IconData icon, {bool accent = false}) =>
    Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accent ? accentOf(context) : const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: accent ? Colors.black : Colors.white),
    );

/// Pestaña "Listas": favoritas, todas las canciones y playlists.
class ListsTab extends StatelessWidget {
  const ListsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: kTabBottomSpace),
          children: [
            _title('Listas'),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: _iconBox(context, CupertinoIcons.add, accent: true),
              title: const Text(
                'Nueva playlist',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                final name = await promptText(
                  context,
                  title: 'Nueva playlist',
                  action: 'Crear',
                );
                if (name != null) store.createPlaylist(name);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: _iconBox(context, CupertinoIcons.star_fill),
              title: const Text('Favoritas'),
              subtitle: Text(
                '${store.favorites.length} canciones',
                style: const TextStyle(color: Colors.white60),
              ),
              onTap: () =>
                  openList(context, 'Favoritas', () => store.favoriteSongs),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: _iconBox(context, CupertinoIcons.music_note_2),
              title: const Text('Todas las canciones'),
              subtitle: Text(
                '${store.songs.length} canciones',
                style: const TextStyle(color: Colors.white60),
              ),
              onTap: () => openList(
                context,
                'Todas las canciones',
                () => store.allSongs,
              ),
            ),
            if (store.playlists.isNotEmpty) const SectionTitle('Mis playlists'),
            for (final p in store.playlists)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: PlaylistCover(playlist: p),
                title: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${store.songsOf(p).length} canciones',
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Opciones',
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final n = await promptText(
                        context,
                        title: 'Renombrar playlist',
                        initial: p.name,
                      );
                      if (n != null) store.renamePlaylist(p, n);
                    } else {
                      final ok = await confirm(
                        context,
                        'Borrar playlist',
                        'Se borrará "${p.name}". Las canciones siguen en tu biblioteca.',
                        'Borrar',
                      );
                      if (ok) store.deletePlaylist(p);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                    PopupMenuItem(value: 'delete', child: Text('Borrar')),
                  ],
                ),
                onTap: () => openList(
                  context,
                  p.name,
                  () => store.songsOf(p),
                  playlist: p,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pestaña "Carpeta": canciones agrupadas por la carpeta del celular.
class FolderTab extends StatelessWidget {
  const FolderTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final folders = store.folders;
          return ListView(
            padding: const EdgeInsets.only(bottom: kTabBottomSpace),
            children: [
              _title('Carpetas'),
              const ScanBanner(),
              if (store.songs.isEmpty) const EmptyLibrary(),
              for (final f in folders)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: _iconBox(context, CupertinoIcons.folder_fill),
                  title: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    f.subtitle,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: kMuted,
                  ),
                  onTap: () => openList(
                    context,
                    f.name,
                    () => store.folders
                        .firstWhere((g) => g.name == f.name, orElse: () => f)
                        .songs,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Pestaña "Álbum".
class AlbumsTab extends StatelessWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context) =>
      const ExploreTab(initialMode: 1, title: 'Álbumes');
}

/// Pestaña "Más": buscar, artistas, agregar música y ajustes.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    Widget link(IconData icon, String label, VoidCallback onTap) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _iconBox(context, icon),
      title: Text(label),
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        size: 18,
        color: kMuted,
      ),
      onTap: onTap,
    );
    return SettingsScreen(
      embedded: true,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 10),
            child: Text(
              'Más',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
          link(CupertinoIcons.search, 'Buscar', () => openSearch(context)),
          link(
            CupertinoIcons.person_2_fill,
            'Artistas',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: ExploreTab(initialMode: 0, title: 'Artistas'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

void openSearch(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const Scaffold(body: SearchTab(active: true)),
    ),
  );
}
