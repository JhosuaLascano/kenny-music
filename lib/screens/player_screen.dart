import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
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

/// Fondo con el color de la canción: portada difuminada, degradado o sólido.
/// Se usa en el reproductor, en la letra y (más oscuro) en el menú principal.
class PlayerBackground extends StatelessWidget {
  const PlayerBackground({
    super.key,
    required this.song,
    this.dim = 0.35,
    this.style,
    this.home = false,
  });
  final Song? song;
  final double dim;

  /// 'blur', 'grad' o 'solid'. Si es null se usa el ajuste del reproductor.
  final String? style;

  /// Versión más oscura para el menú principal (para que se lea el texto).
  final bool home;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? store.bgStyle;
    final coverFile = song?.cover == null ? null : store.resolve(song!.cover!);
    if (style == 'solid' || song == null) {
      return ColoredBox(color: home ? kBg : const Color(0xFF1A1A1F));
    }
    if (style == 'blur' && coverFile != null) {
      // Portada achicada y estirada con suavizado: se ve difuminada sin usar
      // un filtro de desenfoque (que en iPhone se recalcula en cada cuadro y
      // podía trabar la app). El regulador decide qué tan chica: más chica =
      // más borrosa (0 % ≈ 160 px, 100 % ≈ 6 px).
      final t = (store.blurAmount / 100).clamp(0.0, 1.0);
      final px = (160 * math.pow(6 / 160, t)).round();
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: 1.3,
              child: Image.file(
                File(coverFile),
                fit: BoxFit.cover,
                cacheWidth: px,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
            ColoredBox(color: Colors.black.withValues(alpha: home ? 0.6 : dim)),
          ],
        ),
      );
    }
    // Degradado suave con el color de la portada (más claro arriba, oscuro abajo).
    return FutureBuilder<Color>(
      future: coverColor(coverFile, const Color(0xFF6B4A3A)),
      initialData: cachedCoverColor(coverFile),
      builder: (context, snap) {
        final base = HSLColor.fromColor(snap.data ?? const Color(0xFF4A3A33));
        // El regulador "Intensidad del degradado" decide cuánto color hay.
        final k = (store.gradIntensity / 100).clamp(0.0, 1.0);
        double lerp(double a, double b) => a + (b - a) * k;
        final top = base
            .withSaturation(
              (base.saturation * lerp(0.35, 1.25)).clamp(0.0, lerp(0.35, 0.9)),
            )
            .withLightness(home ? lerp(0.2, 0.32) : lerp(0.26, 0.46))
            .toColor();
        final bottom = home
            ? kBg
            : base
                  .withSaturation(
                    (base.saturation * lerp(0.3, 1.1)).clamp(
                      0.0,
                      lerp(0.3, 0.85),
                    ),
                  )
                  .withLightness(lerp(0.1, 0.22))
                  .toColor();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                top,
                Color.lerp(top, bottom, home ? 0.75 : 0.55)!,
                bottom,
              ],
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
                if (store.playerLayout == 'full') FullCoverLayer(song: song),
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
                icon: const Icon(CupertinoIcons.chevron_down, size: 24),
              ),
              const Spacer(),
              Builder(
                builder: (btnContext) => IconButton(
                  tooltip: 'Más opciones',
                  onPressed: () => _showMenu(btnContext, song),
                  icon: const Icon(CupertinoIcons.ellipsis, size: 24),
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
                  fontSize: 12,
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
          // Portada (cambia según el estilo del reproductor)
          _Artwork(song: song),
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
                        fontSize: 22,
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
                        fontSize: 15,
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
                          curve: Curves.easeOutBack,
                        ),
                        child: c,
                      ),
                      child: Icon(
                        fav ? CupertinoIcons.star_fill : CupertinoIcons.star,
                        key: ValueKey(fav),
                        size: 24,
                        color: fav ? accent : Colors.white,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Letra',
                onPressed: () => _openLyrics(context),
                icon: const Icon(CupertinoIcons.quote_bubble, size: 24),
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
                      trackHeight: 3,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: _dragValue == null ? 7 : 10,
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
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '-${two(dur - Duration(milliseconds: value.round()))}',
                        style: const TextStyle(
                          fontSize: 13,
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
                        CupertinoIcons.shuffle,
                        size: 26,
                        color: audio.shuffleOn ? accent : Colors.white70,
                      ),
                    ),
                    _Press(
                      tooltip: 'Anterior',
                      onTap: audio.skipToPrevious,
                      child: const Icon(CupertinoIcons.backward_fill, size: 38),
                    ),
                    _Press(
                      tooltip: playing ? 'Pausar' : 'Reproducir',
                      onTap: audio.togglePlay,
                      width: 96,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(scale: a, child: c),
                        ),
                        child: playing
                            ? const Icon(
                                CupertinoIcons.pause_fill,
                                key: ValueKey(true),
                                size: 54,
                              )
                            : const Padding(
                                key: ValueKey(false),
                                // el triángulo se ve corrido a la izquierda: se compensa un poco
                                padding: EdgeInsets.only(left: 5),
                                child: Icon(CupertinoIcons.play_fill, size: 54),
                              ),
                      ),
                    ),
                    _Press(
                      tooltip: 'Siguiente',
                      onTap: audio.skipToNext,
                      child: const Icon(CupertinoIcons.forward_fill, size: 38),
                    ),
                    _Press(
                      tooltip: 'Cola de reproducción',
                      onTap: () => _showQueue(context),
                      child: const Icon(
                        CupertinoIcons.music_note_list,
                        size: 26,
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
                  child: DecoratedBox(
                    // Casi transparente, solo un borde suave.
                    decoration: BoxDecoration(
                      color: const Color(0x12FFFFFF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            audio.repeatMode == AudioServiceRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            size: 14,
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
                                fontSize: 12,
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
    this.width = 52,
  });
  final Widget child;
  final double width;
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
            scale: _down ? 0.88 : 1,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: SizedBox(
              width: widget.width,
              height: 72,
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

/// Portada del reproductor según el estilo elegido en Ajustes.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => LayoutBuilder(
        builder: (context, c) {
          final size = c.maxWidth.clamp(
            0.0,
            MediaQuery.sizeOf(context).height * 0.42,
          );
          switch (store.playerLayout) {
            case 'full':
              // La portada grande se dibuja detrás (FullCoverLayer); aquí
              // solo se deja el espacio.
              return SizedBox(height: size);
            case 'visual':
              return SizedBox(
                height: size,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentOf(context).withValues(alpha: 0.45),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CoverArt(
                          key: ValueKey('${song.id}-${song.cover}'),
                          song: song,
                          size: size * 0.62,
                          radius: 0,
                        ),
                      ),
                    ),
                    SizedBox(height: size * 0.08),
                    SizedBox(
                      height: size * 0.22,
                      width: double.infinity,
                      child: const _Visualizer(),
                    ),
                  ],
                ),
              );
            default:
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
          }
        },
      ),
    );
  }
}

/// Estilo "Portada completa": la portada ocupa toda la parte de arriba y se
/// funde con el fondo hacia abajo.
class FullCoverLayer extends StatelessWidget {
  const FullCoverLayer({super.key, required this.song});
  final Song? song;

  @override
  Widget build(BuildContext context) {
    final c = song?.cover;
    if (c == null) return const SizedBox.shrink();
    final h = MediaQuery.sizeOf(context).height;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: h * 0.62,
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.55, 1],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Image.file(
            File(store.resolve(c)),
            key: ValueKey(c),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: 900,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

/// Barras que se mueven mientras suena la música (se calman al pausar).
/// No analiza el sonido real: es un efecto visual al ritmo de la reproducción.
class _Visualizer extends StatefulWidget {
  const _Visualizer();

  @override
  State<_Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<_Visualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  final _rnd = math.Random(7);
  late final List<double> _speed = List.generate(
    28,
    (_) => 2 + _rnd.nextDouble() * 5,
  );
  late final List<double> _phase = List.generate(
    28,
    (_) => _rnd.nextDouble() * math.pi * 2,
  );
  double _energy = 0; // 0 = en pausa, 1 = sonando
  StreamSubscription<PlaybackState>? _sub;

  @override
  void initState() {
    super.initState();
    _c.repeat();
    _energy = audio.playbackState.value.playing ? 1 : 0;
    _sub = audio.playbackState.listen((s) {
      final e = s.playing ? 1.0 : 0.0;
      if (e != _energy && mounted) setState(() => _energy = e);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _energy),
        duration: const Duration(milliseconds: 500),
        builder: (context, energy, _) => AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _BarsPainter(
              t: _c.value * 6,
              energy: energy,
              speed: _speed,
              phase: _phase,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.t,
    required this.energy,
    required this.speed,
    required this.phase,
    required this.color,
  });
  final double t;
  final double energy;
  final List<double> speed;
  final List<double> phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final n = speed.length;
    const gap = 4.0;
    final w = (size.width - gap * (n - 1)) / n;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, Colors.white, 0.35)!, color],
      ).createShader(Offset.zero & size);
    for (var i = 0; i < n; i++) {
      final wave =
          (math.sin(t * speed[i] + phase[i]) * 0.5 + 0.5) *
          (0.6 + 0.4 * math.sin(t * 1.3 + i * 0.4).abs());
      final h = size.height * (0.08 + 0.92 * wave * energy);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (w + gap), size.height - h, w, h),
        Radius.circular(w / 2),
      );
      canvas.drawRRect(r, paint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}
