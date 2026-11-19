import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../cover_color.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/marquee.dart';
import '../widgets/player_route.dart';
import 'lyrics_screen.dart';
import 'settings_screen.dart';
import 'song_list_screen.dart';

/// Fondo del reproductor según el ajuste: portada difuminada, degradado o sólido.
class PlayerBackground extends StatelessWidget {
  const PlayerBackground({super.key, required this.song, this.dim = 0.35});
  final Song? song;
  final double dim;

  @override
  Widget build(BuildContext context) {
    final style = store.bgStyle;
    final coverFile = song?.cover == null ? null : store.resolve(song!.cover!);
    if (style == 'solid') return const ColoredBox(color: Color(0xFF1A1A1F));
    if (style == 'blur' && coverFile != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 70,
              sigmaY: 70,
              tileMode: TileMode.decal,
            ),
            child: Transform.scale(
              scale: 1.5,
              child: Image.file(
                File(coverFile),
                fit: BoxFit.cover,
                cacheWidth: 200,
                gaplessPlayback: true,
              ),
            ),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: dim)),
        ],
      );
    }
    // Degradado suave con el color de la portada (más claro arriba, oscuro abajo).
    return FutureBuilder<Color>(
      future: coverColor(coverFile, const Color(0xFF6B4A3A)),
      builder: (context, snap) {
        final base = HSLColor.fromColor(snap.data ?? const Color(0xFF4A3A33));
        final top = base
            .withSaturation((base.saturation * 0.55).clamp(0.0, 0.45))
            .withLightness(0.36)
            .toColor();
        final bottom = base
            .withSaturation((base.saturation * 0.5).clamp(0.0, 0.4))
            .withLightness(0.14)
            .toColor();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, Color.lerp(top, bottom, 0.55)!, bottom],
            ),
          ),
        );
      },
    );
  }
}

/// Abre el reproductor deslizándose hacia arriba con rebote.
void openPlayerScreen(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(PlayerRoute(builder: (_) => const PlayerScreen()));
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double? _dragValue;

  PlayerRoute? get _route {
    final r = ModalRoute.of(context);
    return r is PlayerRoute ? r : null;
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return StreamBuilder<MediaItem?>(
      stream: audio.mediaItem,
      builder: (context, _) {
        final song = audio.current;
        return Scaffold(
          backgroundColor: kBg,
          body: GestureDetector(
            onVerticalDragStart: (_) => _route?.dragStart(),
            onVerticalDragUpdate: (d) => _route?.dragUpdate(d.delta.dy, h),
            onVerticalDragEnd: (d) =>
                _route?.dragEnd(d.velocity.pixelsPerSecond.dy, h),
            onVerticalDragCancel: () => _route?.dragEnd(0, h),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListenableBuilder(
                  listenable: store,
                  builder: (_, _) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    child: PlayerBackground(
                      key: ValueKey(
                        '${song?.id}-${song?.cover}-${store.bgStyle}',
                      ),
                      song: song,
                    ),
                  ),
                ),
                SafeArea(
                  child: song == null
                      ? Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('No hay nada sonando'),
                          ),
                        )
                      : _content(context, song),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _format(Song s) {
    final ext = s.path.split('.').last.toUpperCase();
    final parts = <String>[];
    if (s.bitrate != null) parts.add('${s.bitrate}kbps');
    if (s.sampleRate != null && s.sampleRate! > 0) {
      final k = s.sampleRate! / 1000;
      parts.add(
        '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}kHz',
      );
    }
    return parts.isEmpty ? ext : '$ext · ${parts.join('/')}';
  }

  Widget _content(BuildContext context, Song song) {
    final accent = accentOf(context);
    final hq =
        (song.bitrate ?? 0) >= 256 ||
        ['flac', 'wav'].contains(song.path.split('.').last.toLowerCase());
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
      child: Column(
        children: [
          // Barra de arriba: cerrar y menú
          Row(
            children: [
              IconButton(
                tooltip: 'Cerrar reproductor',
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 34),
              ),
              const Spacer(),
              Builder(
                builder: (btnContext) => IconButton(
                  tooltip: 'Más opciones',
                  onPressed: () => _showMenu(btnContext, song),
                  icon: const Icon(Icons.more_horiz_rounded, size: 30),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _format(song),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  letterSpacing: 0.2,
                ),
              ),
              if (hq) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'HQ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(flex: 3),
          // Portada
          LayoutBuilder(
            builder: (context, c) {
              final size = c.maxWidth.clamp(
                0.0,
                MediaQuery.sizeOf(context).height * 0.42,
              );
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 40,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.92, end: 1.0).animate(a),
                      child: child,
                    ),
                  ),
                  child: CoverArt(
                    key: ValueKey('${song.id}-${song.cover}'),
                    song: song,
                    size: size,
                    radius: 14,
                  ),
                ),
              );
            },
          ),
          const Spacer(flex: 4),
          // Título, estrella y letra
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Marquee(
                      song.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Marquee(
                      song.album == 'Sin álbum'
                          ? song.artist
                          : '${song.artist} - ${song.album}',
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: store,
                builder: (context, _) {
                  final fav = store.isFavorite(song.id);
                  return IconButton(
                    tooltip: fav
                        ? 'Quitar de favoritas'
                        : 'Agregar a favoritas',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      store.toggleFavorite(song.id);
                    },
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (c, a) => ScaleTransition(
                        scale: CurvedAnimation(
                          parent: a,
                          curve: Curves.elasticOut,
                        ),
                        child: c,
                      ),
                      child: Icon(
                        fav ? Icons.star_rounded : Icons.star_outline_rounded,
                        key: ValueKey(fav),
                        size: 32,
                        color: fav ? accent : Colors.white,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Letra',
                onPressed: () => _openLyrics(context),
                icon: const Icon(Icons.format_quote_rounded, size: 30),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.white70, width: 2),
                  ),
                  minimumSize: const Size(40, 36),
                  fixedSize: const Size(44, 38),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LyricPreview(onTap: () => _openLyrics(context)),
          const Spacer(flex: 2),
          // Barra de progreso
          StreamBuilder<Duration>(
            stream: audio.positionTicks,
            builder: (context, _) {
              final dur =
                  audio.duration ?? Duration(milliseconds: song.durationMs);
              final max = dur.inMilliseconds.toDouble().clamp(
                1.0,
                double.infinity,
              );
              final value =
                  (_dragValue ?? audio.position.inMilliseconds.toDouble())
                      .clamp(0.0, max);
              String two(Duration d) =>
                  '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      trackHeight: 4,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: _dragValue == null ? 8 : 11,
                      ),
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: SizedBox(
                      height: 26,
                      child: Slider(
                        value: value,
                        max: max,
                        padding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _dragValue = v),
                        onChangeEnd: (v) {
                          audio.seek(Duration(milliseconds: v.round()));
                          setState(() => _dragValue = null);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        two(Duration(milliseconds: value.round())),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '-${two(dur - Duration(milliseconds: value.round()))}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const Spacer(flex: 2),
          // Controles
          ValueListenableBuilder(
            valueListenable: audio.changes,
            builder: (context, _, _) => StreamBuilder<PlaybackState>(
              stream: audio.playbackState,
              builder: (context, s) {
                final playing = s.data?.playing ?? false;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Press(
                      tooltip: audio.shuffleOn
                          ? 'Aleatorio: activado'
                          : 'Aleatorio: desactivado',
                      onTap: audio.toggleShuffle,
                      child: Icon(
                        Icons.shuffle_rounded,
                        size: 30,
                        color: audio.shuffleOn ? accent : Colors.white70,
                      ),
                    ),
                    _Press(
                      tooltip: 'Anterior',
                      onTap: audio.skipToPrevious,
                      child: const Icon(Icons.fast_rewind_rounded, size: 48),
                    ),
                    _Press(
                      tooltip: playing ? 'Pausar' : 'Reproducir',
                      onTap: audio.togglePlay,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (c, a) =>
                            ScaleTransition(scale: a, child: c),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey(playing),
                          size: 76,
                        ),
                      ),
                    ),
                    _Press(
                      tooltip: 'Siguiente',
                      onTap: audio.skipToNext,
                      child: const Icon(Icons.fast_forward_rounded, size: 48),
                    ),
                    _Press(
                      tooltip: 'Cola de reproducción',
                      onTap: () => _showQueue(context),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        size: 32,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Spacer(flex: 2),
          // Pastilla de estado: repetir · crossfade · temporizador
          ValueListenableBuilder(
            valueListenable: audio.changes,
            builder: (context, _, _) {
              final rep = switch (audio.repeatMode) {
                AudioServiceRepeatMode.all => 'Repetir todo',
                AudioServiceRepeatMode.one => 'Repetir una',
                _ => 'Sin repetir',
              };
              final parts = [
                rep,
                store.crossfade == 0
                    ? 'Sin crossfade'
                    : 'Crossfade ${store.crossfade} s',
                if (audio.sleepEndOfSong) 'Apagar al terminar',
                if (audio.sleepAt != null)
                  'Apagar ${TimeOfDay.fromDateTime(audio.sleepAt!).format(context)}',
              ];
              return Semantics(
                button: true,
                label: 'Cambiar repetición. $rep',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    audio.cycleRepeat();
                  },
                  child: Glass(
                    radius: 22,
                    dark: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            audio.repeatMode == AudioServiceRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            size: 18,
                            color:
                                audio.repeatMode == AudioServiceRepeatMode.none
                                ? Colors.white70
                                : accent,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              parts.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openLyrics(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const LyricsScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(
              begin: 0.96,
              end: 1.0,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  // ---------- Menú "…" ----------

  void _showMenu(BuildContext btnContext, Song song) {
    HapticFeedback.selectionClick();
    final items = <(IconData, String, VoidCallback)>[
      (
        Icons.timer_outlined,
        'Temporizador de apagado',
        () => _sleepSheet(context),
      ),
      (
        Icons.playlist_add_rounded,
        'Agregar a la lista',
        () => showAddToPlaylist(context, [song.id]),
      ),
      (Icons.album_outlined, 'Mostrar álbum', () => _showAlbum(song)),
      (
        Icons.image_outlined,
        'Editar imagen de la canción',
        () => _editImage(song),
      ),
      (
        Icons.palette_outlined,
        'Seleccionar tema del reproductor',
        () => _themeSheet(context),
      ),
    ];
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar menú',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (c, _, _) => SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(60, 50, 16, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Glass(
                radius: 26,
                dark: true,
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (icon, label, action) in items)
                          InkWell(
                            onTap: () {
                              Navigator.pop(c);
                              action();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  Icon(icon, size: 26),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (c, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: CurvedAnimation(
            parent: a,
            curve: const SpringCurve(0.42),
            reverseCurve: Curves.easeIn,
          ),
          child: child,
        ),
      ),
    );
  }

  void _sleepSheet(BuildContext context) {
    final options = <(String, Duration?)>[
      ('15 minutos', const Duration(minutes: 15)),
      ('30 minutos', const Duration(minutes: 30)),
      ('45 minutos', const Duration(minutes: 45)),
      ('1 hora', const Duration(hours: 1)),
      ('Al terminar esta canción', Duration.zero),
    ];
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Temporizador de apagado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (audio.sleepAt != null || audio.sleepEndOfSong)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    audio.sleepEndOfSong
                        ? 'Se pausará al terminar esta canción.'
                        : 'Se pausará a las ${TimeOfDay.fromDateTime(audio.sleepAt!).format(context)}.',
                    style: const TextStyle(color: kMuted),
                  ),
                ),
              ),
            for (final (label, d) in options)
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text(label),
                onTap: () {
                  Navigator.pop(c);
                  audio.setSleep(d);
                  toast(context, 'Temporizador: $label');
                },
              ),
            if (audio.sleepAt != null || audio.sleepEndOfSong)
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Apagar temporizador'),
                onTap: () {
                  Navigator.pop(c);
                  audio.setSleep(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAlbum(Song song) {
    Navigator.pop(context); // cerrar el reproductor
    final nav = navKey.currentState;
    if (nav == null) return;
    Future.delayed(const Duration(milliseconds: 200), () {
      nav.push(
        MaterialPageRoute(
          builder: (_) => SongListScreen(
            title: song.album,
            subtitle: song.artist,
            songs: () => store.albumSongs(song.album, song.artist),
          ),
        ),
      );
    });
  }

  Future<void> _editImage(Song song) async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty || files.first.path == null) return;
    await store.setCustomCover(song.id, files.first.path!);
    audio.refreshCurrent();
    if (mounted) toast(context, 'Imagen actualizada');
  }

  void _themeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tema del reproductor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 16),
              ThemePicker(),
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
                    child: Text(
                      'Cola de reproducción',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: q.length,
                    itemBuilder: (context, i) {
                      final s = q[i];
                      final isCur = i == cur;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        leading: CoverArt(song: s, size: 44),
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCur ? accentOf(context) : kText,
                            fontWeight: isCur
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          s.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isCur
                            ? Icon(
                                Icons.graphic_eq_rounded,
                                color: accentOf(context),
                              )
                            : IconButton(
                                tooltip: 'Quitar de la cola',
                                onPressed: () => audio.removeFromQueue(i),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: kMuted,
                                ),
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

/// Botón que se encoge al presionarlo y rebota al soltarlo.
class _Press extends StatefulWidget {
  const _Press({
    required this.child,
    required this.onTap,
    required this.tooltip,
  });
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) {
            setState(() => _down = false);
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _down ? 0.82 : 1,
            duration: Duration(milliseconds: _down ? 90 : 420),
            curve: _down ? Curves.easeOut : Curves.elasticOut,
            child: SizedBox(
              width: 56,
              height: 80,
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Línea actual de la letra debajo del título ("Cargando la letra").
class _LyricPreview extends StatelessWidget {
  const _LyricPreview({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 20,
        width: double.infinity,
        child: ListenableBuilder(
          listenable: nowLyrics,
          builder: (context, _) {
            final l = nowLyrics.lyrics;
            if (nowLyrics.loading)
              return const _PreviewText('Cargando la letra');
            if (l == null) return const _PreviewText('Letra no disponible');
            if (!l.synced) return const _PreviewText('Toca para ver la letra');
            return StreamBuilder<Duration>(
              stream: audio.positionTicks,
              builder: (context, _) {
                final i = l.indexAt(audio.position);
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _PreviewText(
                    i < 0 ? '♪' : l.lines[i].text,
                    key: ValueKey(i),
                    strong: true,
                  ),
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
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          color: strong ? Colors.white : Colors.white54,
          fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
