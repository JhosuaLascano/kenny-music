import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Lista de canciones genérica: álbum, artista, playlist, favoritas, etc.
class SongListScreen extends StatelessWidget {
  const SongListScreen({
    super.key,
    required this.title,
    required this.songs,
    this.subtitle,
    this.playlist,
  });

  final String title;
  final String? subtitle;

  /// Se vuelve a calcular cada vez que cambia la biblioteca.
  final List<Song> Function() songs;
  final Playlist? playlist;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = songs();
        final p = playlist;
        return Scaffold(
          appBar: AppBar(
            title: Text(p?.name ?? title),
            actions: [
              if (p != null)
                PopupMenuButton<String>(
                  tooltip: 'Opciones de la playlist',
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final n = await promptText(
                        context,
                        title: 'Renombrar playlist',
                        initial: p.name,
                      );
                      if (n != null) store.renamePlaylist(p, n);
                    } else if (v == 'delete') {
                      final ok = await confirm(
                        context,
                        'Borrar playlist',
                        'Se borrará "${p.name}". Las canciones siguen en tu biblioteca.',
                        'Borrar',
                      );
                      if (ok) {
                        store.deletePlaylist(p);
                        if (context.mounted) Navigator.pop(context);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Borrar playlist'),
                    ),
                  ],
                ),
            ],
          ),
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              subtitle ??
                                  '${list.length} ${list.length == 1 ? 'canción' : 'canciones'}',
                              style: const TextStyle(color: kMuted),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Aleatorio',
                            onPressed: list.isEmpty
                                ? null
                                : () => audio.playSongs(
                                    list,
                                    start:
                                        DateTime.now().millisecond %
                                        list.length,
                                    shuffle: true,
                                  ),
                            icon: const Icon(Icons.shuffle_rounded),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: 'Reproducir todo',
                            onPressed: list.isEmpty
                                ? null
                                : () => audio.playSongs(list),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (list.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          p != null
                              ? 'Esta playlist está vacía. Agrega canciones desde el menú "…" de cualquier canción.'
                              : 'No hay canciones aquí.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kMuted),
                        ),
                      ),
                    ),
                  if (p != null && list.isNotEmpty)
                    SliverReorderableList(
                      itemCount: list.length,
                      onReorderItem: (a, b) => store.reorderPlaylist(p, a, b),
                      itemBuilder: (context, i) =>
                          ReorderableDelayedDragStartListener(
                            key: ValueKey('${list[i].id}-$i'),
                            index: i,
                            child: Material(
                              color: kBg,
                              child: SongTile(
                                song: list[i],
                                playlist: p,
                                onTap: () => audio.playSongs(list, start: i),
                              ),
                            ),
                          ),
                    )
                  else
                    SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) => SongTile(
                        song: list[i],
                        onTap: () => audio.playSongs(list, start: i),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
                child: const MiniPlayer(),
              ),
            ],
          ),
        );
      },
    );
  }
}

void openList(
  BuildContext context,
  String title,
  List<Song> Function() songs, {
  String? subtitle,
  Playlist? playlist,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SongListScreen(
        title: title,
        songs: songs,
        subtitle: subtitle,
        playlist: playlist,
      ),
    ),
  );
}
