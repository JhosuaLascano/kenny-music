import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../scanner.dart';
import '../screens/player_screen.dart' show openPlayerScreen;
import '../theme.dart';
import 'marquee.dart';

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
  const CoverArt({
    super.key,
    required this.song,
    this.size = 48,
    this.radius = 8,
  });
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
    final pair =
        _placeholderPairs[(song?.id.hashCode ?? 0).abs() %
            _placeholderPairs.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pair,
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white70,
        size: size * 0.42,
      ),
    );
  }
}

/// Fila de canción con estrella de favorito y menú.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.playlist,
  });
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
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: playing ? accent : kText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: kMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: fav ? 'Quitar de favoritas' : 'Agregar a favoritas',
                  onPressed: () => store.toggleFavorite(song.id),
                  icon: Icon(
                    fav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: fav ? accent : const Color(0xFF71717A),
                  ),
                ),
                IconButton(
                  tooltip: 'Más opciones',
                  onPressed: () =>
                      showSongMenu(context, song, playlist: playlist),
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
    ..showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String action = 'Guardar',
}) {
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
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctrl.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body,
  String action,
) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(action),
        ),
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
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
                'Quitar',
              );
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Agregar a playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kSurface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_rounded),
              ),
              title: const Text('Nueva playlist'),
              onTap: () async {
                Navigator.pop(c);
                final name = await promptText(
                  context,
                  title: 'Nueva playlist',
                  action: 'Crear',
                );
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
                  toast(
                    context,
                    n == 0
                        ? 'Ya estaba en "${p.name}"'
                        : 'Agregada a "${p.name}"',
                  );
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
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.queue_music_rounded,
          color: kMuted,
          size: size * 0.45,
        ),
      );
    }
    // Con 4 canciones o más: mosaico 2×2 con las portadas de las 4 primeras.
    if (songs.length < 4) return CoverArt(song: songs.first, size: size);
    final h = size / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size > 100 ? 16 : 8),
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          children: [
            for (final row in [0, 2])
              Row(
                children: [
                  for (final i in [row, row + 1])
                    CoverArt(song: songs[i], size: h, radius: 0),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Vidrio translúcido (estilo "liquid glass"): difumina lo que pasa por
/// detrás y deja ver sus colores.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 33,
    this.dark = false,
    this.blur = true,
  });
  final Widget child;
  final double radius;
  final bool dark;

  /// false = transparente de verdad (se ve lo de atrás sin difuminar).
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    if (!blur) return _liquid(r);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [Color(0x47303036), Color(0x38202024)]
                    : const [Color(0x17FFFFFF), Color(0x06FFFFFF)],
              ),
              border: Border.all(color: const Color(0x2EFFFFFF), width: 0.8),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Estilo "gota de agua": lo de atrás se ve casi nítido y con colores más
  /// vivos (como a través del agua), con un borde de luz, un reflejo arriba y
  /// un brillo suave abajo para que se distinga del fondo.
  Widget _liquid(BorderRadius r) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          // Vidrio esmerilado oscuro: difumina lo de atrás y aviva un poco el color.
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: CustomPaint(
            foregroundPainter: LiquidRimPainter(radius: radius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x8C2C2C31),
                    Color(0x8C232327),
                    Color(0x8C1C1C20),
                  ],
                  stops: [0, 0.6, 1],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Borde de luz y reflejos de la gota de agua.
class LiquidRimPainter extends CustomPainter {
  LiquidRimPainter({required this.radius, this.strong = false});
  final double radius;
  final bool strong;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(
      rect.deflate(0.7),
      Radius.circular(radius),
    );

    // Borde: brilla arriba a la izquierda, se apaga y vuelve a brillar abajo a la derecha.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 1.8 : 1.3
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: strong ? 0.95 : 0.32),
          Colors.white.withValues(alpha: strong ? 0.12 : 0.14),
          Colors.white.withValues(alpha: strong ? 0.12 : 0.14),
          Colors.white.withValues(alpha: strong ? 0.6 : 0.22),
        ],
        stops: const [0, 0.35, 0.7, 1],
      ).createShader(rect);
    canvas.drawRRect(rr, rim);

    // Reflejo ovalado arriba (como la luz sobre una gota).
    final hl = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * (strong ? 0.5 : 0.42),
      size.height * 0.32,
    );
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawOval(
      hl,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: strong ? 0.42 : 0.07),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(hl),
    );
    // Brillo suave abajo (la luz que atraviesa la gota).
    final low = Rect.fromLTWH(
      0,
      size.height * 0.7,
      size.width,
      size.height * 0.3,
    );
    canvas.drawRect(
      low,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: strong ? 0.2 : 0.03),
          ],
        ).createShader(low),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(LiquidRimPainter old) =>
      old.radius != radius || old.strong != strong;
}

/// Barra de navegación de vidrio transparente. Al deslizar el dedo aparece
/// una gota de vidrio más grande que agranda el ícono que está debajo; la
/// pestaña cambia recién al soltar.
class GlassNavBar extends StatefulWidget {
  const GlassNavBar({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const items = [
    (CupertinoIcons.house_fill, 'Inicio'),
    (CupertinoIcons.music_note_list, 'Listas'),
    (CupertinoIcons.folder_fill, 'Carpeta'),
    (CupertinoIcons.music_albums_fill, 'Álbum'),
    (CupertinoIcons.square_grid_2x2_fill, 'Más'),
  ];

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar> {
  double? _fingerX; // dónde está el dedo mientras se arrastra
  double _stretch = 0; // cuánto se estira la gota según la velocidad del dedo
  bool _pressed = false;
  static const _pad = 5.0;
  static const _h = 62.0;

  int _indexAt(double x, double itemW) =>
      ((x - _pad) / itemW).floor().clamp(0, GlassNavBar.items.length - 1);

  void _finish(double x, double itemW) {
    final i = _indexAt(x, itemW);
    setState(() {
      _stretch = 0;
      _fingerX = null;
      _pressed = false;
    });
    if (i != widget.index) {
      HapticFeedback.selectionClick();
      widget.onTap(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final n = GlassNavBar.items.length;
    return SizedBox(
      height: _h,
      child: LayoutBuilder(
        builder: (context, c) {
          final itemW = (c.maxWidth - _pad * 2) / n;
          final drop = _fingerX != null || _pressed; // modo gota
          final center = _fingerX != null
              ? _fingerX!.clamp(_pad + itemW / 2, c.maxWidth - _pad - itemW / 2)
              : _pad + (widget.index + 0.5) * itemW;
          final lit = _fingerX != null
              ? _indexAt(_fingerX!, itemW)
              : widget.index;
          // La gota es más grande que la barra y sobresale arriba y abajo.
          // La gota se estira hacia los lados al moverse rápido y se aplana un
          // poco, como una gota de agua; al frenar vuelve a ser redonda.
          final bw = drop ? itemW + 22 + _stretch : itemW;
          final bh = drop ? _h + 16 - _stretch * 0.25 : _h - 8;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (d) => _finish(d.localPosition.dx, itemW),
            onTapCancel: () => setState(() => _pressed = false),
            onHorizontalDragStart: (d) => setState(() {
              _pressed = true;
              _fingerX = d.localPosition.dx;
            }),
            onHorizontalDragUpdate: (d) => setState(() {
              _fingerX = d.localPosition.dx;
              _stretch = (_stretch * 0.6 + d.delta.dx.abs() * 1.6).clamp(
                0.0,
                34.0,
              );
            }),
            onHorizontalDragEnd: (_) => _finish(_fingerX ?? 0, itemW),
            onHorizontalDragCancel: () => setState(() {
              _fingerX = null;
              _pressed = false;
            }),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: Glass(blur: false, child: SizedBox.expand()),
                ),
                AnimatedPositioned(
                  duration: _fingerX != null
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: center - bw / 2,
                  top: (_h - bh) / 2,
                  width: bw,
                  height: bh,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(bh / 2),
                      color: drop
                          ? const Color(0x14FFFFFF)
                          : const Color(0x2EFFFFFF),
                      boxShadow: drop
                          ? const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ]
                          : const [],
                    ),
                    // La gota: borde de luz y reflejos (más fuertes al deslizar).
                    child: CustomPaint(
                      painter: drop
                          ? LiquidRimPainter(radius: bh / 2, strong: true)
                          : null,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _pad),
                    child: Row(
                      children: [
                        for (var i = 0; i < n; i++)
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: i == widget.index,
                              label: GlassNavBar.items[i].$2,
                              onTap: () => widget.onTap(i),
                              child: AnimatedScale(
                                scale: drop && i == lit ? 1.32 : 1,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      GlassNavBar.items[i].$1,
                                      size: 22,
                                      color: i == lit ? accent : Colors.white70,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      GlassNavBar.items[i].$2,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: i == lit
                                            ? accent
                                            : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void openPlayer(BuildContext context) => openPlayerScreen(context);

/// Mini-reproductor de vidrio, delgado.
/// Deslizar a la izquierda = siguiente, a la derecha = anterior,
/// hacia arriba (o tocar) = abrir el reproductor.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  double _dx = 0;
  bool _dragging = false;

  void _endDrag(double velocity) {
    final w = context.size?.width ?? 300;
    final next = _dx < -w * 0.22 || velocity < -600;
    final prev = _dx > w * 0.22 || velocity > 600;
    setState(() {
      _dragging = false;
      _dx = 0;
    });
    if (next || prev) {
      HapticFeedback.lightImpact();
      next ? audio.skipToNext() : audio.skipToPrevious();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: (d) => setState(() => _dx += d.delta.dx),
          onHorizontalDragEnd: (d) => _endDrag(d.velocity.pixelsPerSecond.dx),
          onHorizontalDragCancel: () => _endDrag(0),
          child: Glass(
            radius: 31,
            blur: false,
            child: SizedBox(
              height: 62,
              child: AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(_dx * 0.6, 0, 0),
                padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
                child: Row(
                  children: [
                    CoverArt(song: song, size: 44, radius: 8),
                    const SizedBox(width: 12),
                    // Título y artista en dos líneas.
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Marquee(
                            song.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ),
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
                          icon: Icon(
                            playing
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            size: 26,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      onPressed: audio.skipToNext,
                      icon: const Icon(
                        CupertinoIcons.forward_fill,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
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
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aún no hay música',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
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
        : 'Se agregaron $n canciones',
  );
}

Future<void> runImport(BuildContext context) async {
  final n = await importFiles();
  if (!context.mounted || n == null) return;
  toast(
    context,
    n == 0 ? 'No se importó ninguna canción' : 'Se importaron $n canciones',
  );
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
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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
            child: Text(
              text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
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
