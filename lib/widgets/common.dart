import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../scanner.dart';
import '../screens/player_screen.dart';
import '../theme.dart';

Color accentOf(BuildContext context) => Theme.of(context).colorScheme.primary;

const _placeholderPairs = [
  [Color(0xFF6D28D9), Color(0xFFDB2777)],
  [Color(0xFF065F46), Color(0xFF65A30D)],
  [Color(0xFF9A3412), Color(0xFFD97706)],
  [Color(0xFF1E3A8A), Color(0xFF0284C7)],
  [Color(0xFF7F1D1D), Color(0xFF1E3A8A)],
  [Color(0xFF0E7490), Color(0xFF164E63)],
];

/// Portada de la canción (o un degradado con una nota si no tiene).
class CoverArt extends StatelessWidget {
  const CoverArt({super.key, required this.song, this.size = 48, this.radius = 8});
  final Song? song;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = song?.cover;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final ph = _placeholder();
    if (c == null) return ph;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(store.resolve(c)),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * dpr).round(),
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => ph,
      ),
    );
  }

  Widget _placeholder() {
    final pair = _placeholderPairs[(song?.id.hashCode ?? 0).abs() % _placeholderPairs.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: pair),
      ),
      child: Icon(Icons.music_note_rounded, color: Colors.white70, size: size * 0.42),
    );
  }
}

/// Fila de canción con estrella de favorito y menú.
class SongTile extends StatelessWidget {
  const SongTile({super.key, required this.song, required this.onTap, this.playlist});
  final Song song;
  final VoidCallback onTap;
  final Playlist? playlist;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([store, audio.changes]),
      builder: (context, _) {
        final playing = audio.current?.id == song.id;
        final fav = store.isFavorite(song.id);
        return InkWell(
          onTap: onTap,
          onLongPress: () => showSongMenu(context, song, playlist: playlist),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 4, 6),
            child: Row(
              children: [
                CoverArt(song: song),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: playing ? accent : kText)),
                      const SizedBox(height: 2),
                      Text(song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: kMuted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: fav ? 'Quitar de favoritas' : 'Agregar a favoritas',
                  onPressed: () => store.toggleFavorite(song.id),
                  icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded,
                      color: fav ? accent : const Color(0xFF71717A)),
                ),
                IconButton(
                  tooltip: 'Más opciones',
                  onPressed: () => showSongMenu(context, song, playlist: playlist),
                  icon: const Icon(Icons.more_vert_rounded, color: kMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}

Future<String?> promptText(BuildContext context,
    {required String title, String initial = '', String action = 'Guardar'}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nombre'),
        onSubmitted: (v) => Navigator.pop(c, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: Text(action)),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}

Future<bool> confirm(BuildContext context, String title, String body, String action) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
      ],
    ),
  );
  return r ?? false;
}

/// Menú de una canción.
void showSongMenu(BuildContext context, Song song, {Playlist? playlist}) {
  showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CoverArt(song: song, size: 44),
            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.playlist_play_rounded),
            title: const Text('Reproducir a continuación'),
            onTap: () {
              Navigator.pop(c);
              audio.playNext(song);
              toast(context, 'Sonará a continuación');
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: const Text('Agregar a la cola'),
            onTap: () {
              Navigator.pop(c);
              audio.addToQueue(song);
              toast(context, 'Agregada a la cola');
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('Agregar a una playlist'),
            onTap: () {
              Navigator.pop(c);
              showAddToPlaylist(context, [song.id]);
            },
          ),
          if (playlist != null)
            ListTile(
              leading: const Icon(Icons.playlist_remove_rounded),
              title: Text('Quitar de "${playlist.name}"'),
              onTap: () {
                Navigator.pop(c);
                store.removeFromPlaylist(playlist, song.id);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Quitar de la biblioteca'),
            onTap: () async {
              Navigator.pop(c);
              final imported = song.path.startsWith('app:');
              final ok = await confirm(
                  context,
                  'Quitar canción',
                  imported
                      ? 'Se borrará "${song.title}" de Kenny Music.'
                      : 'Se quitará "${song.title}" de la biblioteca. El archivo sigue en tu celular y volverá a aparecer si buscas música de nuevo.',
                  'Quitar');
              if (ok) {
                audio.forgetSong(song.id);
                store.removeSong(song.id);
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// Hoja para elegir a qué playlist agregar canciones.
void showAddToPlaylist(BuildContext context, List<String> ids) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Agregar a playlist',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: kSurface2, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add_rounded),
              ),
              title: const Text('Nueva playlist'),
              onTap: () async {
                Navigator.pop(c);
                final name = await promptText(context, title: 'Nueva playlist', action: 'Crear');
                if (name == null) return;
                final p = store.createPlaylist(name);
                store.addToPlaylist(p, ids);
                if (context.mounted) toast(context, 'Agregada a "$name"');
              },
            ),
            for (final p in store.playlists)
              ListTile(
                leading: PlaylistCover(playlist: p, size: 44),
                title: Text(p.name),
                subtitle: Text('${p.songIds.length} canciones'),
                onTap: () {
                  Navigator.pop(c);
                  final n = store.addToPlaylist(p, ids);
                  toast(context, n == 0 ? 'Ya estaba en "${p.name}"' : 'Agregada a "${p.name}"');
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class PlaylistCover extends StatelessWidget {
  const PlaylistCover({super.key, required this.playlist, this.size = 48});
  final Playlist playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final songs = store.songsOf(playlist);
    if (songs.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.queue_music_rounded, color: kMuted, size: size * 0.45),
      );
    }
    return CoverArt(song: songs.first, size: size);
  }
}

/// Fondo de vidrio translúcido (estilo "liquid glass").
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 33, this.dark = false});
  final Widget child;
  final double radius;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 30, offset: Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              color: dark ? const Color(0xB826262B) : null,
              gradient: dark
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33FFFFFF), Color(0x14FFFFFF)],
                    ),
              border: Border.all(color: dark ? const Color(0x24FFFFFF) : const Color(0x38FFFFFF)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.grid_view_rounded, 'Explorar'),
    (Icons.library_music_rounded, 'Biblioteca'),
    (Icons.search_rounded, 'Buscar'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return Glass(
      child: SizedBox(
        height: 66,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: _items[i].$2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: i == index ? const Color(0x24FFFFFF) : Colors.transparent,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_items[i].$1, size: 24, color: i == index ? accent : kMuted),
                            const SizedBox(height: 2),
                            Text(_items[i].$2,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: i == index ? accent : kMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void openPlayer(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
    pageBuilder: (_, _, _) => const PlayerScreen(),
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (_, a, _, child) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ));
}

/// Mini-reproductor flotante.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return StreamBuilder<MediaItem?>(
      stream: audio.mediaItem,
      builder: (context, snap) {
        final song = audio.current;
        if (snap.data == null || song == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => openPlayer(context),
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -200) openPlayer(context);
          },
          child: Glass(
            radius: 20,
            dark: true,
            child: SizedBox(
              height: 62,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                    child: Row(
                      children: [
                        CoverArt(song: song, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: kMuted)),
                            ],
                          ),
                        ),
                        StreamBuilder<PlaybackState>(
                          stream: audio.playbackState,
                          builder: (context, s) {
                            final playing = s.data?.playing ?? false;
                            return IconButton(
                              tooltip: playing ? 'Pausar' : 'Reproducir',
                              onPressed: audio.togglePlay,
                              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 30),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Siguiente',
                          onPressed: audio.skipToNext,
                          icon: const Icon(Icons.skip_next_rounded, size: 30),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 0,
                    child: StreamBuilder<Duration>(
                      stream: audio.positionTicks,
                      builder: (context, _) {
                        final d = audio.duration?.inMilliseconds ?? 0;
                        final p = audio.position.inMilliseconds;
                        return LinearProgressIndicator(
                          value: d > 0 ? (p / d).clamp(0.0, 1.0) : 0,
                          minHeight: 2,
                          color: accent,
                          backgroundColor: const Color(0xFF3F3F46),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Mensaje cuando todavía no hay música, con botones para agregarla.
class EmptyLibrary extends StatelessWidget {
  const EmptyLibrary({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aún no hay música',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              Platform.isAndroid
                  ? 'Kenny Music busca las canciones que ya tienes en el celular (mp3, m4a, flac, wav).'
                  : 'Elige canciones desde la app Archivos (mp3, m4a, flac, wav). Se copian dentro de Kenny Music.',
              style: const TextStyle(color: kMuted),
            ),
            const SizedBox(height: 16),
            const AddMusicButtons(),
          ],
        ),
      ),
    );
  }
}

class AddMusicButtons extends StatelessWidget {
  const AddMusicButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (Platform.isAndroid)
          FilledButton.icon(
            onPressed: () => runScan(context),
            icon: const Icon(Icons.travel_explore_rounded),
            label: const Text('Buscar música en el celular'),
          ),
        (Platform.isAndroid ? OutlinedButton.icon : FilledButton.icon)(
          onPressed: () => runImport(context),
          icon: const Icon(Icons.file_open_rounded),
          label: const Text('Importar archivos'),
        ),
      ],
    );
  }
}

Future<void> runScan(BuildContext context) async {
  final n = await scanDevice();
  if (!context.mounted) return;
  toast(
      context,
      n < 0
          ? 'Sin permiso para leer la música. Actívalo en los ajustes del celular.'
          : n == 0
              ? 'No hay canciones nuevas'
              : 'Se agregaron $n canciones');
}

Future<void> runImport(BuildContext context) async {
  final n = await importFiles();
  if (!context.mounted || n == null) return;
  toast(context, n == 0 ? 'No se importó ninguna canción' : 'Se importaron $n canciones');
}

/// Aviso de "buscando…" mientras se leen canciones.
class ScanBanner extends StatelessWidget {
  const ScanBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.scanning) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text(store.scanMessage ?? 'Buscando…')),
            ],
          ),
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 8),
      child: Row(
        children: [
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: const TextStyle(color: kMuted)),
            ),
        ],
      ),
    );
  }
}
