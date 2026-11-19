import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

final _cache = <String, Color>{};

/// Color principal de una portada, ajustado para que sirva de fondo oscuro.
Future<Color> coverColor(String? file, Color fallback) async {
  if (file == null) return fallback;
  final hit = _cache[file];
  if (hit != null) return hit;
  try {
    final bytes = await File(file).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 24, targetHeight: 24);
    final img = (await codec.getNextFrame()).image;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (data == null) return fallback;
    double r = 0, g = 0, b = 0, w = 0;
    for (var i = 0; i < data.lengthInBytes; i += 4) {
      final c = Color.fromARGB(255, data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
      final hsv = HSVColor.fromColor(c);
      // Pesan más los píxeles con color (no grises ni negros).
      final weight = 0.05 + hsv.saturation * hsv.value;
      r += c.r * weight;
      g += c.g * weight;
      b += c.b * weight;
      w += weight;
    }
    final avg = Color.from(alpha: 1, red: r / w, green: g / w, blue: b / w);
    final hsl = HSLColor.fromColor(avg);
    final tuned = hsl
        .withLightness(hsl.lightness.clamp(0.22, 0.42))
        .withSaturation(hsl.saturation < 0.08 ? hsl.saturation : hsl.saturation.clamp(0.35, 0.85))
        .toColor();
    _cache[file] = tuned;
    return tuned;
  } catch (_) {
    return fallback;
  }
}
