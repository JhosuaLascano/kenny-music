import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../cover_color.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'add_songs_screen.dart';

/// Pantalla de una playlist. Su color sale de las portadas de la propia
/// playlist (no depende de los ajustes) y las canciones se pueden reordenar.
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key, required this.playlist});
  final Playlist playlist;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  bool _searching = false;
  String _q = '';

  Playlist get p => widget.playlist;

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  String _total(List<Song> songs) {
    final mins = songs.fold<int>(0, (a, s) => a + s.durationMs) ~/ 60000;
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60} h ${mins % 60} min';
  }

  String _dur(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _sortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (id, label) in const [
              ('title', 'Por título'),
              ('artist', 'Por artista'),
              ('recent', 'Recién agregadas primero'),
              ('duration', 'Por duración'),
            ])
              ListTile(
                title: Text(label),
                onTap: () {
                  Navigator.pop(c);
                  store.sortPlaylist(p, id);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _moreSheet() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Agregar canciones'),
              onTap: () {
                Navigator.pop(c);
                _addSongs();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Renombrar'),
              onTap: () async {
                Navigator.pop(c);
                final n = await promptText(
                  context,
                  title: 'Renombrar playlist',
                  initial: p.name,
                );
                if (n != null) store.renamePlaylist(p, n);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Borrar playlist'),
              onTap: () async {
                Navigator.pop(c);
                final ok = await confirm(
                  context,
                  'Borrar playlist',
                  'Se borrará "${p.name}". Las canciones siguen en tu biblioteca.',
                  'Borrar',
                );
                if (ok) {
                  store.deletePlaylist(p);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addSongs() =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => AddSongsScreen(playlist: p)));

  Widget _circle(
    IconData icon,
    String tip,
    VoidCallback onTap, {
    double size = 46,
  }) => Semantics(
    button: true,
    label: tip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x40000000),
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = store.songsOf(p);
        final q = _norm(_q.trim());
        final list = q.isEmpty
            ? all
            : all
                  .where(
                    (s) =>
                        _norm(s.title).contains(q) ||
                        _norm(s.artist).contains(q),
                  )
                  .toList();
        final coverFile = all.isEmpty || all.first.cover == null
            ? null
            : store.resolve(all.first.cover!);
        return FutureBuilder<Color>(
          future: coverColor(coverFile, const Color(0xFF4A3A5A)),
          initialData: cachedCoverColor(coverFile),
          builder: (context, snap) {
            final base = HSLColor.fromColor(
              snap.data ?? const Color(0xFF4A3A5A),
            );
            final top = base
                .withSaturation((base.saturation * 0.9).clamp(0.0, 0.6))
                .withLightness(0.3)
                .toColor();
            final mid = base
                .withSaturation((base.saturation * 0.8).clamp(0.0, 0.55))
                .withLightness(0.16)
                .toColor();
            final soft = base
                .withSaturation((base.saturation).clamp(0.0, 0.6))
                .withLightness(0.8)
                .toColor();
            return Scaffold(
              backgroundColor: kBg,
              body: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [top, mid, kBg],
                    stops: const [0, 0.5, 1],
                  ),
                ),
                child: Stack(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _header(all, soft)),
                          if (list.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  all.isEmpty
                                      ? 'Esta playlist está vacía. Toca + para agregar canciones.'
                                      : 'Sin resultados',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: soft),
                                ),
                              ),
                            ),
                          SliverReorderableList(
                            itemCount: list.length,
                            onReorderItem: (a, b) {
                              if (q.isEmpty) store.reorderPlaylist(p, a, b);
                            },
                            itemBuilder: (context, i) {
                              final s = list[i];
                              final playing = audio.current?.id == s.id;
                              return Material(
                                key: ValueKey('${s.id}-$i'),
                                type: MaterialType.transparency,
                                child: InkWell(
                                  onTap: () => audio.playSongs(
                                    list,
                                    start: i,
                                    from: p.name,
                                  ),
                                  onLongPress: () =>
                                      showSongMenu(context, s, playlist: p),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      7,
                                      8,
                                      7,
                                    ),
                                    child: Row(
                                      children: [
                                        CoverArt(song: s, size: 48, radius: 6),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: playing
                                                      ? FontWeight.w800
                                                      : FontWeight.w500,
                                                  color: playing
                                                      ? accentOf(context)
                                                      : Colors.white,
                                                ),
                                              ),
                                              Text(
                                                s.artist,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: soft,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (s.durationMs > 0)
                                          Text(
                                            _dur(s.durationMs),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        if (q.isEmpty)
                                          ReorderableDragStartListener(
                                            index: i,
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                              child: Icon(
                                                Icons.drag_handle_rounded,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          )
                                        else
                                          const SizedBox(width: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 130),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
                      child: const MiniPlayer(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _header(List<Song> all, Color soft) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              _circle(
                CupertinoIcons.chevron_back,
                'Volver',
                () => Navigator.pop(context),
              ),
              const Spacer(),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0x40000000),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Buscar en la playlist',
                      onPressed: () => setState(() {
                        _searching = !_searching;
                        if (!_searching) _q = '';
                      }),
                      icon: const Icon(
                        CupertinoIcons.search,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ordenar',
                      onPressed: _sortSheet,
                      icon: const Icon(
                        CupertinoIcons.sort_down,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Más opciones',
                      onPressed: _moreSheet,
                      icon: const Icon(
                        CupertinoIcons.ellipsis,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Buscar en "${p.name}"',
                  prefixIcon: const Icon(CupertinoIcons.search),
                  filled: true,
                  fillColor: const Color(0x40000000),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 30,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: PlaylistCover(playlist: p, size: 250),
          ),
          const SizedBox(height: 18),
          Text(
            p.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${all.length} ${all.length == 1 ? 'canción' : 'canciones'}',
            style: TextStyle(fontSize: 17, color: soft),
          ),
          const SizedBox(height: 4),
          Text(
            'Playlist · ${all.length} ${all.length == 1 ? 'canción' : 'canciones'} · ${_total(all)}',
            style: TextStyle(fontSize: 13, color: soft),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _circle(CupertinoIcons.shuffle, 'Aleatorio', () {
                if (all.isEmpty) return;
                audio.playSongs(
                  all,
                  start: DateTime.now().millisecond % all.length,
                  shuffle: true,
                  from: p.name,
                );
              }, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: all.isEmpty
                        ? null
                        : () => audio.playSongs(all, from: p.name),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111111),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    icon: const Icon(CupertinoIcons.play_fill, size: 20),
                    label: const Text(
                      'Reproducir',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _circle(
                CupertinoIcons.add,
                'Agregar canciones',
                _addSongs,
                size: 52,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

void openPlaylist(BuildContext context, Playlist p) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: p)));
}
