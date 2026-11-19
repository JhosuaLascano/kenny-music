import 'dart:io';

import 'package:flutter/services.dart';

import 'app_state.dart';

/// Mantiene al día el widget de iPhone y recibe los toques de sus botones.
///
/// Importante: aquí no se procesan imágenes. En iPhone, con la app en segundo
/// plano, el procesamiento de imágenes de Flutter queda en pausa; antes eso
/// hacía que el widget no se actualizara hasta abrir la app. Ahora iOS
/// achica la portada y calcula su color por su cuenta.
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

  static void _push() {
    final song = audio.current;
    final playing = audio.playbackState.value.playing;
    // updatePosition cambia al cambiar de canción, pausar o adelantar.
    final upd = audio.playbackState.value.updatePosition.inSeconds;
    final key = '${song?.id}|${song?.cover}|$playing|$upd';
    if (key == _lastKey) return; // nada cambió
    _lastKey = key;
    final cover = song?.cover == null ? null : store.resolve(song!.cover!);
    _channel
        .invokeMethod('update', {
          'title': song?.title ?? 'Kenny Music',
          'artist': song?.artist ?? 'Pon una canción',
          'playing': playing,
          'cover': cover,
          'position': audio.position.inMilliseconds.toDouble(),
          'duration': (audio.duration?.inMilliseconds ?? song?.durationMs ?? 0)
              .toDouble(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch.toDouble(),
        })
        .catchError((_) => null); // sin widget (simulador): no pasa nada
  }
}
