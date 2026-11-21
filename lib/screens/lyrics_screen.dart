import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../lyrics.dart';
import '../widgets/common.dart';
import 'player_screen.dart';

/// Letra en pantalla completa: avanza sola y resalta la línea que suena.
class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};
  StreamSubscription<Duration>? _ticks;
  int _current = -1;
  DateTime _userScrolledAt = DateTime(2000);

  // Traducción al español (se pide una vez por canción y se guarda).
  List<String>? _tr;
  String? _trFor;
  bool _trLoading = false;

  Future<void> _loadTranslation(String songId, Lyrics l) async {
    if (_trFor == songId || _trLoading) return;
    _trFor = songId;
    _tr = null;
    setState(() => _trLoading = true);
    final t = await LyricsTranslator.translate(songId, l);
    if (!mounted || _trFor != songId) return;
    setState(() {
      _tr = t;
      _trLoading = false;
    });
    if (t == null && mounted) {
      toast(
        context,
        'No se pudo traducir ahora (sin internet o límite diario)',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _ticks = audio.positionTicks.listen(_onTick);
  }

  @override
  void dispose() {
    _ticks?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onTick(Duration pos) {
    final l = nowLyrics.lyrics;
    if (l == null || !l.synced) return;
    final i = l.indexAt(pos);
    if (i == _current) return;
    setState(() => _current = i);
    // Si el usuario movió la letra con el dedo, se espera un poco antes de seguir.
    if (DateTime.now().difference(_userScrolledAt) < const Duration(seconds: 4))
      return;
    final ctx = _keys[i < 0 ? 0 : i]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audio.mediaItem,
      builder: (context, _) {
        final song = audio.current;
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              PlayerBackground(song: song, dim: 0.55),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                      child: Row(
                        children: [
                          CoverArt(song: song, size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song?.title ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  song?.artist ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Tamaño de la letra: más chica / más grande.
                          IconButton(
                            tooltip: 'Letra más chica',
                            onPressed: () =>
                                store.setLyricsSize(store.lyricsSize - 2),
                            icon: const Icon(Icons.text_decrease_rounded),
                          ),
                          IconButton(
                            tooltip: 'Letra más grande',
                            onPressed: () =>
                                store.setLyricsSize(store.lyricsSize + 2),
                            icon: const Icon(Icons.text_increase_rounded),
                          ),
                          // Traducir al español (solo si la letra está en inglés).
                          ListenableBuilder(
                            listenable: Listenable.merge([nowLyrics, store]),
                            builder: (context, _) {
                              final l = nowLyrics.lyrics;
                              if (l == null ||
                                  !LyricsTranslator.looksEnglish(l)) {
                                return const SizedBox.shrink();
                              }
                              final on = store.translateLyrics;
                              return IconButton(
                                tooltip: on
                                    ? 'Ocultar traducción'
                                    : 'Traducir al español',
                                style: IconButton.styleFrom(
                                  backgroundColor: on
                                      ? const Color(0x40FFFFFF)
                                      : Colors.transparent,
                                ),
                                onPressed: () => store.setTranslateLyrics(!on),
                                icon: const Icon(Icons.translate_rounded),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Cerrar letra',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([nowLyrics, store]),
                        builder: (context, _) {
                          final l = nowLyrics.lyrics;
                          final id = audio.current?.id;
                          if (store.translateLyrics &&
                              l != null &&
                              id != null &&
                              LyricsTranslator.looksEnglish(l) &&
                              _trFor != id) {
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _loadTranslation(id, l),
                            );
                          }
                          return _body(l);
                        },
                      ),
                    ),
                    _footer(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(Lyrics? l) {
    if (nowLyrics.loading) {
      return const Center(
        child: Text(
          'Cargando la letra…',
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
      );
    }
    if (l == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Letra no disponible',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              store.onlineLyrics ? 'No se encontró la letra de esta canción.' : 'La búsqueda de letras en internet está apagada en Ajustes.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => nowLyrics.refresh(force: true),
              child: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      );
    }
    return NotificationListener<UserScrollNotification>(
      onNotification: (_) {
        _userScrolledAt = DateTime.now();
        return false;
      },
      // Margen arriba y abajo: las líneas se desvanecen en los bordes para
      // que la letra no llene toda la pantalla.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, 0.14, 0.82, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: _list(l),
        ),
      ),
    );
  }

  Widget _list(Lyrics l) {
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        28,
        MediaQuery.sizeOf(context).height * 0.12,
        28,
        MediaQuery.sizeOf(context).height * 0.4,
      ),
      itemCount: l.lines.length,
      itemBuilder: (context, i) {
        final line = l.lines[i];
        final key = _keys.putIfAbsent(i, () => GlobalKey());
        final Color color;
        if (!l.synced) {
          color = Colors.white;
        } else if (i == _current) {
          color = Colors.white;
        } else if (i < _current) {
          color = Colors.white.withValues(alpha: 0.35);
        } else {
          color = Colors.white.withValues(alpha: 0.55);
        }
        return GestureDetector(
          key: key,
          onTap: line.time == null ? null : () => audio.seek(line.time!),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: l.synced
                    ? store.lyricsSize.toDouble()
                    : store.lyricsSize * 0.8,
                height: 1.22,
                fontWeight: l.synced ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.text),
                  // Traducción al español debajo de la línea original.
                  if (store.translateLyrics &&
                      _tr != null &&
                      i < _tr!.length &&
                      _tr![i].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _tr![i],
                        style: TextStyle(
                          fontSize: store.lyricsSize * 0.62,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: color.withValues(alpha: color.a * 0.75),
                        ),
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

  Widget _footer() {
    return ListenableBuilder(
      listenable: nowLyrics,
      builder: (context, _) {
        final l = nowLyrics.lyrics;
        if (l == null) return const SizedBox(height: 12);
        final text = switch (l.source) {
          'archivo' => 'Letra del archivo .lrc',
          'embebida' => 'Letra guardada en la canción',
          _ => 'Letra encontrada en internet (LRCLIB) · guardada para usar sin conexión',
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
          child: Row(
            children: [
              Icon(
                l.source == 'internet'
                    ? Icons.public_rounded
                    : Icons.description_outlined,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.synced ? text : '$text · sin tiempos',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
