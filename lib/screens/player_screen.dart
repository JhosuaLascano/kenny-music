import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../cover_color.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'lyrics_screen.dart';

/// Fondo del reproductor según el ajuste: portada difuminada, degradado o sólido.
class PlayerBackground extends StatelessWidget {
  const PlayerBackground({super.key, required this.song, this.dim = 0.45});
  final Song? song;
  final double dim;

  @override
  Widget build(BuildContext context) {
    final style = store.bgStyle;
    final coverFile = song?.cover == null ? null : store.resolve(song!.cover!);
    if (style == 'solid') return const ColoredBox(color: Color(0xFF141418));
    if (style == 'blur' && coverFile != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
            child: Transform.scale(
              scale: 1.4,
              child: Image.file(File(coverFile), fit: BoxFit.cover, cacheWidth: 200, gaplessPlayback: true),
            ),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: dim)),
        ],
      );
    }
    // Degradado (o portada difuminada sin portada): color de la portada → negro.
    return FutureBuilder<Color>(
      future: coverColor(coverFile, const Color(0xFF7A3A12)),
      builder: (context, snap) {
        final c = snap.data ?? const Color(0xFF3A2416);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c, Color.lerp(c, kBg, 0.7)!, kBg],
              stops: const [0, 0.55, 1],
            ),
          ),
        );
      },
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return StreamBuilder<MediaItem?>(
      stream: audio.mediaItem,
      builder: (context, _) {
        final song = audio.current;
        return Scaffold(
          backgroundColor: kBg,
          body: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 400) Navigator.pop(context);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListenableBuilder(
                  listenable: store,
                  builder: (_, _) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: PlayerBackground(key: ValueKey('${song?.id}-${store.bgStyle}'), song: song),
                  ),
                ),
                SafeArea(
                  child: song == null
                      ? Center(
                          child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('No hay nada sonando')))
                      : _content(context, song, accent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, Song song, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Cerrar reproductor',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
              ),
              const Expanded(
                child: Text('REPRODUCIENDO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70)),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: LayoutBuilder(builder: (context, c) {
              final size = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
              return Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0x80000000), blurRadius: 50, offset: Offset(0, 20))
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: CoverArt(key: ValueKey(song.id), song: song, size: size, radius: 16),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    Text(song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: store,
                builder: (context, _) {
                  final fav = store.isFavorite(song.id);
                  return _RoundButton(
                    tooltip: fav ? 'Quitar de favoritas' : 'Agregar a favoritas',
                    icon: fav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: fav ? accent : Colors.white,
                    onTap: () => store.toggleFavorite(song.id),
                  );
                },
              ),
              const SizedBox(width: 8),
              _RoundButton(
                tooltip: 'Más opciones',
                icon: Icons.more_horiz_rounded,
                onTap: () => showSongMenu(context, song),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LyricPreview(onTap: () => _openLyrics(context)),
          const SizedBox(height: 8),
          StreamBuilder<Duration>(
            stream: audio.positionTicks,
            builder: (context, _) {
              final dur = audio.duration ?? Duration(milliseconds: song.durationMs);
              final pos = audio.position;
              final max = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
              final value = (_dragValue ?? pos.inMilliseconds.toDouble()).clamp(0.0, max);
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: value,
                      max: max,
                      onChanged: (v) => setState(() => _dragValue = v),
                      onChangeEnd: (v) {
                        audio.seek(Duration(milliseconds: v.round()));
                        setState(() => _dragValue = null);
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(Duration(milliseconds: value.round())),
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      Text('-${formatDuration(dur - Duration(milliseconds: value.round()))}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          StreamBuilder<PlaybackState>(
            stream: audio.playbackState,
            builder: (context, s) {
              final playing = s.data?.playing ?? false;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Anterior',
                    iconSize: 44,
                    onPressed: audio.skipToPrevious,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 28),
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: IconButton.filled(
                      tooltip: playing ? 'Pausar' : 'Reproducir',
                      style: IconButton.styleFrom(backgroundColor: Colors.white),
                      onPressed: audio.togglePlay,
                      icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 40, color: kBg),
                    ),
                  ),
                  const SizedBox(width: 28),
                  IconButton(
                    tooltip: 'Siguiente',
                    iconSize: 44,
                    onPressed: audio.skipToNext,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: audio.changes,
            builder: (context, _, _) => Row(
              children: [
                const Icon(Icons.volume_down_rounded, size: 20, color: Colors.white70),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(value: audio.volume, onChanged: audio.setVolume),
                  ),
                ),
                const Icon(Icons.volume_up_rounded, size: 20, color: Colors.white70),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder(
            valueListenable: audio.changes,
            builder: (context, _, _) {
              final rep = audio.repeatMode;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    tooltip: 'Letra',
                    onPressed: () => _openLyrics(context),
                    icon: const Icon(Icons.lyrics_outlined),
                  ),
                  IconButton(
                    tooltip: audio.shuffleOn ? 'Aleatorio: activado' : 'Aleatorio: desactivado',
                    onPressed: audio.toggleShuffle,
                    icon: Icon(Icons.shuffle_rounded,
                        color: audio.shuffleOn ? accent : Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Transmitir',
                    onPressed: () => _showCast(context),
                    icon: const Icon(Icons.cast_rounded),
                  ),
                  IconButton(
                    tooltip: switch (rep) {
                      AudioServiceRepeatMode.all => 'Repetir todo',
                      AudioServiceRepeatMode.one => 'Repetir una',
                      _ => 'Sin repetir',
                    },
                    onPressed: audio.cycleRepeat,
                    icon: Icon(
                      rep == AudioServiceRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: rep == AudioServiceRepeatMode.none ? Colors.white : accent,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cola de reproducción',
                    onPressed: () => _showQueue(context),
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _openLyrics(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, _, _) => const LyricsScreen(),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  void _showCast(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Transmitir',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                Platform.isIOS
                    ? 'Para escuchar en un parlante o en la TV, abre el Centro de control, toca el ícono de AirPlay en la tarjeta de música y elige el dispositivo. Kenny Music seguirá sonando ahí.'
                    : 'Para escuchar en un parlante o audífonos Bluetooth, conéctalos desde los ajustes rápidos del celular. Kenny Music sonará por ese dispositivo automáticamente.',
                style: const TextStyle(color: kMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: ValueListenableBuilder(
          valueListenable: audio.changes,
          builder: (context, _, _) {
            final q = audio.queueSongs;
            final cur = audio.index;
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cola de reproducción',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: q.length,
                    itemBuilder: (context, i) {
                      final s = q[i];
                      final isCur = i == cur;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        leading: CoverArt(song: s, size: 44),
                        title: Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: isCur ? accentOf(context) : kText,
                                fontWeight: isCur ? FontWeight.w700 : FontWeight.w500)),
                        subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: isCur
                            ? Icon(Icons.graphic_eq_rounded, color: accentOf(context))
                            : IconButton(
                                tooltip: 'Quitar de la cola',
                                onPressed: () => audio.removeFromQueue(i),
                                icon: const Icon(Icons.close_rounded, color: kMuted),
                              ),
                        onTap: () => audio.skipToQueueItem(i),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {required this.icon, required this.onTap, required this.tooltip, this.color = Colors.white});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.14)),
      icon: Icon(icon, color: color),
    );
  }
}

/// Línea actual de la letra debajo del título (como "Cargando la letra").
class _LyricPreview extends StatelessWidget {
  const _LyricPreview({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 22,
        width: double.infinity,
        child: ListenableBuilder(
          listenable: nowLyrics,
          builder: (context, _) {
            final l = nowLyrics.lyrics;
            if (nowLyrics.loading) return const _PreviewText('Cargando la letra');
            if (l == null) return const _PreviewText('Letra no disponible');
            if (!l.synced) return const _PreviewText('Toca para ver la letra');
            return StreamBuilder<Duration>(
              stream: audio.positionTicks,
              builder: (context, _) {
                final i = l.indexAt(audio.position);
                final text = i < 0 ? '♪' : l.lines[i].text;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _PreviewText(text, key: ValueKey(i), strong: true),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PreviewText extends StatelessWidget {
  const _PreviewText(this.text, {super.key, this.strong = false});
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 14,
              color: strong ? Colors.white : Colors.white70,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w400)),
    );
  }
}
