import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'song_list_screen.dart';

/// Biblioteca: todas las canciones, playlists y favoritas.
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  int _mode = 0; // 0 canciones, 1 playlists, 2 favoritas

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final songs = _mode == 2 ? store.favoriteSongs : store.allSongs;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Biblioteca',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final (i, label) in const [
                            (0, 'Canciones'),
                            (1, 'Playlists'),
                            (2, 'Favoritas'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: _mode == i,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _mode = i),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: ScanBanner()),
              if (_mode == 1) ..._playlists(context) else ..._songs(context, songs),
              const SliverToBoxAdapter(child: SizedBox(height: kTabBottomSpace)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _songs(BuildContext context, List songs) {
    if (store.songs.isEmpty) return [const SliverToBoxAdapter(child: EmptyLibrary())];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _mode == 2 && songs.isEmpty
                      ? 'Toca la estrella de una canción para guardarla aquí.'
                      : '${songs.length} canciones',
                  style: const TextStyle(color: kMuted),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Aleatorio',
                onPressed: songs.isEmpty
                    ? null
                    : () => audio.playSongs(songs.cast(),
                        start: DateTime.now().millisecond % songs.length, shuffle: true),
                icon: const Icon(Icons.shuffle_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Reproducir todo',
                onPressed: songs.isEmpty ? null : () => audio.playSongs(songs.cast()),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
      SliverList.builder(
        itemCount: songs.length,
        itemBuilder: (context, i) =>
            SongTile(song: songs[i], onTap: () => audio.playSongs(songs.cast(), start: i)),
      ),
    ];
  }

  List<Widget> _playlists(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentOf(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.black),
          ),
          title: const Text('Nueva playlist', style: TextStyle(fontWeight: FontWeight.w600)),
          onTap: () async {
            final name = await promptText(context, title: 'Nueva playlist', action: 'Crear');
            if (name != null) store.createPlaylist(name);
          },
        ),
      ),
      SliverList.builder(
        itemCount: store.playlists.length,
        itemBuilder: (context, i) {
          final p = store.playlists[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: PlaylistCover(playlist: p),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${store.songsOf(p).length} canciones',
                style: const TextStyle(color: kMuted)),
            trailing: PopupMenuButton<String>(
              tooltip: 'Opciones',
              onSelected: (v) async {
                if (v == 'rename') {
                  final n = await promptText(context, title: 'Renombrar playlist', initial: p.name);
                  if (n != null) store.renamePlaylist(p, n);
                } else {
                  final ok = await confirm(context, 'Borrar playlist',
                      'Se borrará "${p.name}". Las canciones siguen en tu biblioteca.', 'Borrar');
                  if (ok) store.deletePlaylist(p);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                PopupMenuItem(value: 'delete', child: Text('Borrar')),
              ],
            ),
            onTap: () => openList(context, p.name, () => store.songsOf(p), playlist: p),
          );
        },
      ),
    ];
  }
}
