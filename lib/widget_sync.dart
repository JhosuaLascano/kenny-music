import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'cover_color.dart';

/// Mantiene al día el widget de iPhone y recibe los toques de sus botones.
class WidgetSync {
  static const _channel = MethodChannel('kenny/widget');
  static String? _lastKey;

  static void start() {
    if (!Platform.isIOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'command') return;
      switch (call.arguments as String?) {
        case 'toggle':
          await audio.togglePlay();
        case 'next':
          await audio.skipToNext();
        case 'prev':
          await audio.skipToPrevious();
      }
    });
    audio.mediaItem.listen((_) => _push());
    audio.playbackState.listen((_) => _push());
  }

  static Future<void> _push() async {
    final song = audio.current;
    final playing = audio.playbackState.value.playing;
    // updatePosition cambia al cambiar de canción, pausar o adelantar.
    final upd = audio.playbackState.value.updatePosition.inSeconds;
    final key = '${song?.id}|${song?.cover}|$playing|$upd';
    if (key == _lastKey) return; // nada cambió
    _lastKey = key;
    final cover = song?.cover == null ? null : store.resolve(song!.cover!);
    final base = await coverColor(cover, const Color(0xFFB4441A));
    // Un poco más oscuro que la portada, como fondo del widget.
    final hsl = HSLColor.fromColor(base);
    final c = hsl
        .withLightness((hsl.lightness * 0.85).clamp(0.18, 0.4))
        .toColor();
    final hex =
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    try {
      await _channel.invokeMethod('update', {
        'title': song?.title ?? 'Kenny Music',
        'artist': song?.artist ?? 'Pon una canción',
        'playing': playing,
        'cover': cover,
        'color': hex,
        'position': audio.position.inMilliseconds.toDouble(),
        'duration': (audio.duration?.inMilliseconds ?? song?.durationMs ?? 0)
            .toDouble(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch.toDouble(),
      });
    } catch (_) {
      // Sin widget (por ejemplo, en el simulador): no pasa nada.
    }
  }
}
