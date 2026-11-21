import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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
    if (style == 'tint') {
      // Cola: degradado con el color de la canción que suena (sin la imagen
      // de la portada, para que la lista se lea bien). Siempre con color,
      // aunque la portada sea oscura.
      return FutureBuilder<Color>(
        future: coverColor(coverFile, const Color(0xFF4A5A6A)),
        initialData: cachedCoverColor(coverFile),
        builder: (context, snap) {
          final b = HSLColor.fromColor(snap.data ?? const Color(0xFF4A5A6A));
          final sat = b.saturation < 0.1
              ? b.saturation
              : b.saturation.clamp(0.4, 0.75);
          final top = b.withSaturation(sat).withLightness(0.38).toColor();
          final mid = b.withSaturation(sat * 0.9).withLightness(0.26).toColor();
          final bottom = b
              .withSaturation(sat * 0.8)
              .withLightness(0.15)
              .toColor();
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [top, mid, bottom],
              ),
            ),
          );
        },
      );
    }
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
                    duration: const Duration(milliseconds: 450),
                    // Con la cola abierta: un solo color liso (sin portada)
                    // para que la lista se lea bien.
                    child: PlayerBackground(
                      key: ValueKey(
                        '${song?.id}-${song?.cover}-${store.bgStyle}-$_queueMode',
                      ),
                      song: song,
                      style: _queueMode ? 'tint' : null,
                    ),
                  ),
                ),
                if (!_queueMode &&
                    (store.playerLayout == 'full' ||
                        store.playerLayout == 'poster'))
                  FullCoverLayer(
                    song: song,
                    poster: store.playerLayout == 'poster',
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

  /// true = la cola está abierta dentro del reproductor (la portada sube).
  bool _queueMode = false;

  Widget _content(BuildContext context, Song song) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
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
          // Parte de arriba: portada grande o cola (con transición).
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  alignment: Alignment.topLeft,
                  scale: Tween(begin: 0.94, end: 1.0).animate(a),
                  child: child,
                ),
              ),
              child: _queueMode
                  ? _QueuePanel(key: const ValueKey('cola'), song: song)
                  : _nowPanel(context, song),
            ),
          ),
          const SizedBox(height: 10),
          _SeekBar(song: song),
          const SizedBox(height: 6),
          _controls(),
          if (_queueMode) _volume(),
          const SizedBox(height: 12),
          _bottomRow(context),
        ],
      ),
    );
  }

  /// Portada grande, título, estrella y línea de la letra.
  Widget _nowPanel(BuildContext context, Song song) {
    final accent = accentOf(context);
    final hq =
        (song.bitrate ?? 0) >= 256 ||
        ['flac', 'wav'].contains(song.path.split('.').last.toLowerCase());
    return Column(
      key: const ValueKey('ahora'),
      children: [
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
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Marquee(
                    song.title,
                    // Estilo "Mínimo": título enorme.
                    style: TextStyle(
                      fontSize: store.playerLayout == 'minimal' ? 34 : 22,
                      fontWeight: store.playerLayout == 'minimal'
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Marquee(
                    song.album == 'Sin álbum'
                        ? song.artist
                        : '${song.artist} - ${song.album}',
                    style: const TextStyle(fontSize: 15, color: Colors.white60),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _FavButton(song: song),
            IconButton(
              tooltip: 'Letra',
              onPressed: () => _openLyrics(context),
              icon: const Icon(CupertinoIcons.quote_bubble, size: 24),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _LyricPreview(onTap: () => _openLyrics(context)),
        const Spacer(flex: 1),
      ],
    );
  }

  /// Anterior, reproducir/pausa y siguiente.
  Widget _controls() {
    return StreamBuilder<PlaybackState>(
      stream: audio.playbackState,
      builder: (context, s) {
        final playing = s.data?.playing ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Press(
              tooltip: 'Anterior',
              onTap: audio.skipToPrevious,
              width: 72,
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
                        // el triángulo se ve corrido a la izquierda: se compensa
                        padding: EdgeInsets.only(left: 5),
                        child: Icon(CupertinoIcons.play_fill, size: 54),
                      ),
              ),
            ),
            _Press(
              tooltip: 'Siguiente',
              onTap: audio.skipToNext,
              width: 72,
              child: const Icon(CupertinoIcons.forward_fill, size: 38),
            ),
          ],
        );
      },
    );
  }

  /// Volumen (se muestra con la cola abierta).
  Widget _volume() {
    return ValueListenableBuilder(
      valueListenable: audio.changes,
      builder: (context, _, _) => Row(
        children: [
          const Icon(
            CupertinoIcons.speaker_fill,
            size: 16,
            color: Colors.white70,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
              ),
              child: Slider(value: audio.volume, onChanged: audio.setVolume),
            ),
          ),
          const Icon(
            CupertinoIcons.speaker_3_fill,
            size: 18,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  /// Letra · [aleatorio | repetir | continuo] · cola.
  Widget _bottomRow(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([audio.changes, store]),
      builder: (context, _) {
        final rep = audio.repeatMode;
        Widget seg(IconData icon, bool on, String tip, VoidCallback onTap) =>
            Semantics(
              button: true,
              selected: on,
              label: tip,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 58,
                  height: 42,
                  color: on ? const Color(0x38FFFFFF) : Colors.transparent,
                  child: Icon(icon, size: 21, color: Colors.white),
                ),
              ),
            );
        return Row(
          children: [
            IconButton(
              tooltip: 'Letra',
              onPressed: () => _openLyrics(context),
              icon: const Icon(CupertinoIcons.quote_bubble, size: 24),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: ColoredBox(
                color: const Color(0x24FFFFFF),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    seg(
                      CupertinoIcons.shuffle,
                      audio.shuffleOn,
                      'Aleatorio',
                      audio.toggleShuffle,
                    ),
                    seg(
                      rep == AudioServiceRepeatMode.one
                          ? CupertinoIcons.repeat_1
                          : CupertinoIcons.repeat,
                      rep != AudioServiceRepeatMode.none,
                      switch (rep) {
                        AudioServiceRepeatMode.all => 'Repetir todo',
                        AudioServiceRepeatMode.one => 'Repetir una',
                        _ => 'Sin repetir',
                      },
                      audio.cycleRepeat,
                    ),
                    seg(
                      Icons.all_inclusive_rounded,
                      store.autoplay,
                      'Reproducción continua',
                      () => store.setAutoplay(!store.autoplay),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Semantics(
              button: true,
              selected: _queueMode,
              label: 'Cola de reproducción',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _queueMode = !_queueMode);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _queueMode
                        ? const Color(0xD9FFFFFF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    CupertinoIcons.list_bullet,
                    size: 22,
                    color: _queueMode ? const Color(0xFF1A1A1A) : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
      (Icons.speed_rounded, 'Velocidad', () => _speedSheet(context)),
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
      transitionDuration: const Duration(milliseconds: 180),
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
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeIn,
          ),
          child: child,
        ),
      ),
    );
  }

  /// Velocidad de reproducción (0,75× a 2×).
  void _speedSheet(BuildContext context) {
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Velocidad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder(
                valueListenable: audio.changes,
                builder: (context, _, _) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in speeds)
                      ChoiceChip(
                        label: Text(
                          '${s.toString().replaceAll('.0', '').replaceAll('.', ',')}×',
                        ),
                        selected: (audio.speed - s).abs() < 0.01,
                        showCheckmark: false,
                        onSelected: (_) => audio.setSpeed(s),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Útil para podcasts o para practicar una canción más lento.',
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
            ],
          ),
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
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: const [
              Text(
                'Tema del reproductor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 16),
              PlayerStylePicker(),
              SizedBox(height: 26),
              ThemePicker(),
            ],
          ),
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
            case 'poster':
              // La portada grande se dibuja detrás (FullCoverLayer); aquí
              // solo se deja el espacio.
              return SizedBox(height: size);
            case 'minimal':
              // Portada chica a la izquierda; el título va enorme más abajo.
              return SizedBox(
                height: size * 0.7,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: cinematicSwitch(
                    currentKey: ValueKey('${song.id}-${song.cover}'),
                    child: CoverArt(
                      key: ValueKey('${song.id}-${song.cover}'),
                      song: song,
                      size: size * 0.42,
                      radius: 12,
                    ),
                  ),
                ),
              );
            case 'lyrics':
              return _InlineLyrics(song: song, height: size);
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
                // Vuela desde/hacia el mini-reproductor al abrir y cerrar, y
                // hace la transición de cine al cambiar de canción.
                // Doble toque en la portada = favorita (con estrella animada).
                child: _DoubleTapFav(
                  song: song,
                  child: Hero(
                    tag: kNowCoverTag,
                    transitionOnUserGestures: true,
                    child: cinematicSwitch(
                      currentKey: ValueKey('${song.id}-${song.cover}'),
                      child: CoverArt(
                        key: ValueKey('${song.id}-${song.cover}'),
                        song: song,
                        size: size,
                        radius: 14,
                      ),
                    ),
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
  const FullCoverLayer({super.key, required this.song, this.poster = false});
  final Song? song;

  /// true = estilo "Póster": la portada llena toda la pantalla.
  final bool poster;

  @override
  Widget build(BuildContext context) {
    final c = song?.cover;
    if (c == null) return const SizedBox.shrink();
    final h = MediaQuery.sizeOf(context).height;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: poster ? h : h * 0.62,
      child: ShaderMask(
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: poster
              ? const [Colors.white, Color(0xB3FFFFFF), Color(0x40FFFFFF)]
              : const [Colors.white, Colors.white, Colors.transparent],
          stops: poster ? const [0, 0.5, 1] : const [0, 0.55, 1],
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

/// Barra de progreso para adelantar o regresar, en 3 estilos (Ajustes →
/// Reproducción): fina con punto, cápsula que crece y onda.
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.song});
  final Song song;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag; // milisegundos mientras se arrastra

  String _two(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _seekTo(double ms) {
    audio.seek(Duration(milliseconds: ms.round()));
    setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => StreamBuilder<Duration>(
        stream: audio.positionTicks,
        builder: (context, _) {
          final dur =
              audio.duration ?? Duration(milliseconds: widget.song.durationMs);
          final max = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
          final value = (_drag ?? audio.position.inMilliseconds.toDouble())
              .clamp(0.0, max);
          final frac = value / max;
          final dragging = _drag != null;
          final times = Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _two(Duration(milliseconds: value.round())),
                style: TextStyle(
                  fontSize: 13,
                  color: dragging ? Colors.white : Colors.white70,
                  fontWeight: dragging ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              Text(
                '-${_two(dur - Duration(milliseconds: value.round()))}',
                style: TextStyle(
                  fontSize: 13,
                  color: dragging ? Colors.white : Colors.white70,
                  fontWeight: dragging ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          );

          // Gestos comunes para cápsula y onda: tocar o arrastrar para saltar.
          Widget touchable(Widget child) => LayoutBuilder(
            builder: (context, c) {
              double at(double x) => (x / c.maxWidth).clamp(0.0, 1.0) * max;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) =>
                    setState(() => _drag = at(d.localPosition.dx)),
                onHorizontalDragUpdate: (d) =>
                    setState(() => _drag = at(d.localPosition.dx)),
                onHorizontalDragEnd: (_) => _seekTo(_drag ?? value),
                onTapDown: (d) =>
                    setState(() => _drag = at(d.localPosition.dx)),
                onTapUp: (_) => _seekTo(_drag ?? value),
                onTapCancel: () => setState(() => _drag = null),
                child: child,
              );
            },
          );

          switch (store.progressStyle) {
            case 'capsule':
              return Column(
                children: [
                  touchable(
                    SizedBox(
                      height: 30,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          height: dragging ? 14 : 6,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: frac,
                            heightFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: dragging
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  times,
                ],
              );
            case 'wave':
              return Column(
                children: [
                  touchable(
                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _WavePainter(
                          seed: widget.song.id.hashCode,
                          progress: frac,
                          played: accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  times,
                ],
              );
            default:
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      trackHeight: 3,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: dragging ? 10 : 7,
                      ),
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: SizedBox(
                      height: 26,
                      child: Slider(
                        value: value,
                        max: max,
                        padding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _drag = v),
                        onChangeEnd: _seekTo,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  times,
                ],
              );
          }
        },
      ),
    );
  }
}

/// Barritas tipo nota de voz (siempre iguales para la misma canción).
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.seed,
    required this.progress,
    required this.played,
  });
  final int seed;
  final double progress;
  final Color played;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 48;
    const gap = 3.0;
    final w = (size.width - gap * (n - 1)) / n;
    final rnd = math.Random(seed);
    final on = Paint()..color = played;
    final off = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < n; i++) {
      final shape = 0.35 + 0.65 * (math.sin(i * 0.45 + seed % 7) * 0.5 + 0.5);
      final h =
          size.height *
          (0.15 + 0.85 * shape * (0.55 + 0.45 * rnd.nextDouble()));
      final x = i * (w + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, w, h),
          Radius.circular(w / 2),
        ),
        (i + 0.5) / n <= progress ? on : off,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress || old.seed != seed || old.played != played;
}

/// Transición "de cine" al cambiar de canción: la portada anterior se encoge,
/// se difumina y se desvanece; la nueva llega un poco más grande y se enfoca.
Widget cinematicSwitch({required Key currentKey, required Widget child}) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 650),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (c, a) {
      final incoming = c.key == currentKey;
      return AnimatedBuilder(
        animation: a,
        child: c,
        builder: (context, child) {
          final t = a.value; // 0 → 1 al entrar; 1 → 0 al salir
          final scale = incoming ? 1.12 - 0.12 * t : 0.86 + 0.14 * t;
          final blur = (1 - t) * 10;
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: blur < 0.3
                  ? child
                  : ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: child,
                    ),
            ),
          );
        },
      );
    },
    child: child,
  );
}

/// Estilo "Letra integrada": la letra avanza dentro del reproductor.
class _InlineLyrics extends StatelessWidget {
  const _InlineLyrics({required this.song, required this.height});
  final Song song;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoverArt(song: song, size: 56, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  song.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListenableBuilder(
              listenable: nowLyrics,
              builder: (context, _) {
                final l = nowLyrics.lyrics;
                if (nowLyrics.loading) {
                  return const Text(
                    'Cargando la letra…',
                    style: TextStyle(color: Colors.white60),
                  );
                }
                if (l == null) {
                  return const Text(
                    'Letra no disponible',
                    style: TextStyle(color: Colors.white60),
                  );
                }
                return StreamBuilder<Duration>(
                  stream: audio.positionTicks,
                  builder: (context, _) {
                    final cur = l.synced ? l.indexAt(audio.position) : -1;
                    final start = math.min(
                      math.max(0, cur - 1),
                      math.max(0, l.lines.length - 1),
                    );
                    final shown = l.lines.skip(start).take(5).toList();
                    return ClipRect(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < shown.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: TextStyle(
                                  fontSize: start + i == cur ? 20 : 16,
                                  fontWeight: start + i == cur
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: start + i == cur
                                      ? Colors.white
                                      : (start + i < cur
                                            ? Colors.white38
                                            : Colors.white60),
                                  height: 1.25,
                                ),
                                child: Text(
                                  shown[i].text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Estrella de favorita con un pequeño rebote al tocarla.
class _FavButton extends StatelessWidget {
  const _FavButton({required this.song, this.circle = false});
  final Song song;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final fav = store.isFavorite(song.id);
        return IconButton(
          tooltip: fav ? 'Quitar de favoritas' : 'Agregar a favoritas',
          style: circle
              ? IconButton.styleFrom(backgroundColor: const Color(0x2EFFFFFF))
              : null,
          onPressed: () {
            HapticFeedback.lightImpact();
            store.toggleFavorite(song.id);
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (c, a) => ScaleTransition(
              scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
              child: c,
            ),
            child: Icon(
              fav ? CupertinoIcons.star_fill : CupertinoIcons.star,
              key: ValueKey(fav),
              size: circle ? 20 : 24,
              color: fav ? accent : Colors.white,
            ),
          ),
        );
      },
    );
  }
}

/// La cola dentro del reproductor: la portada sube pequeña con el título,
/// debajo "Reproduciendo" y "A continuación de: ..." (se puede reordenar).
class _QueuePanel extends StatelessWidget {
  const _QueuePanel({super.key, required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: audio.changes,
      builder: (context, _, _) {
        final q = audio.queueSongs;
        final cur = audio.index;
        final upcoming = cur + 1 < q.length
            ? q.sublist(cur + 1)
            : const <Song>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CoverArt(song: song, size: 64, radius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Marquee(
                        song.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                _FavButton(song: song, circle: true),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Cola',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Reproduciendo',
              style: TextStyle(fontSize: 15, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CoverArt(song: song, size: 46, radius: 6),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.graphic_eq_rounded, color: Colors.white),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'A continuación de: ${audio.queueFrom}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: upcoming.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'No hay más canciones en la cola.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    )
                  : ShaderMask(
                      // La lista se desvanece al final, sin cortes bruscos.
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0, 0.88, 1],
                      ).createShader(r),
                      blendMode: BlendMode.dstIn,
                      child: ReorderableListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: upcoming.length,
                        buildDefaultDragHandles: false,
                        onReorderItem: (a, b) =>
                            audio.moveQueueItem(cur + 1 + a, cur + 1 + b),
                        itemBuilder: (context, i) {
                          final s = upcoming[i];
                          return Material(
                            key: ValueKey('up-${cur + 1 + i}-${s.id}'),
                            type: MaterialType.transparency,
                            child: InkWell(
                              onTap: () => audio.skipToQueueItem(cur + 1 + i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: const Padding(
                                        padding: EdgeInsets.only(
                                          right: 10,
                                          top: 10,
                                          bottom: 10,
                                        ),
                                        child: Icon(
                                          Icons.drag_handle_rounded,
                                          color: Colors.white60,
                                        ),
                                      ),
                                    ),
                                    CoverArt(song: s, size: 46, radius: 6),
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
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            s.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white60,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Quitar de la cola',
                                      onPressed: () =>
                                          audio.removeFromQueue(cur + 1 + i),
                                      icon: const Icon(
                                        CupertinoIcons.xmark,
                                        size: 18,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Doble toque sobre la portada: marca o quita la favorita y muestra una
/// estrella que crece y se desvanece en el centro.
class _DoubleTapFav extends StatefulWidget {
  const _DoubleTapFav({required this.song, required this.child});
  final Song song;
  final Widget child;

  @override
  State<_DoubleTapFav> createState() => _DoubleTapFavState();
}

class _DoubleTapFavState extends State<_DoubleTapFav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _nowFav = true;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    store.toggleFavorite(widget.song.id);
    setState(() => _nowFav = store.isFavorite(widget.song.id));
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return GestureDetector(
      onDoubleTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                if (_c.value == 0 || _c.value == 1)
                  return const SizedBox.shrink();
                final t = _c.value;
                final scale = Curves.easeOutBack.transform(
                  (t * 1.6).clamp(0.0, 1.0),
                );
                final opacity = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.4 + scale * 0.8,
                    child: Icon(
                      _nowFav
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star_slash,
                      size: 110,
                      color: _nowFav ? accent : Colors.white,
                      shadows: const [
                        Shadow(color: Color(0x80000000), blurRadius: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
