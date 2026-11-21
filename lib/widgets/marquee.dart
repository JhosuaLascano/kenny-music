import 'dart:async';

import 'package:flutter/material.dart';

/// Texto que se desliza solo cuando no cabe (como el título en el reproductor).
///
/// Se desliza una vuelta y luego se queda QUIETO unos segundos sin pedir
/// cuadros nuevos (con un Timer, no con la animación). Antes la animación no
/// paraba nunca: obligaba a redibujar todo el tiempo el vidrio de la barra y
/// del mini-reproductor, y eso trababa la app en iPhone y Android.
class Marquee extends StatefulWidget {
  const Marquee(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _wait;
  double _textW = 0; // ancho del texto que se está deslizando (0 = quieto)
  static const _gap = 48.0;
  static const _pause = Duration(seconds: 3);

  @override
  void didUpdateWidget(Marquee old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _reset();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _reset() {
    _wait?.cancel();
    _c.stop();
    _c.value = 0;
    _textW = 0;
  }

  /// Una vuelta: espera, se desliza, vuelve al inicio y repite.
  void _loop() {
    _wait?.cancel();
    _wait = Timer(_pause, () async {
      if (!mounted || _textW == 0) return;
      _c.duration = Duration(
        milliseconds: ((_textW + _gap) / 35 * 1000).round(),
      );
      try {
        await _c.forward(from: 0).orCancel;
      } catch (_) {
        return; // se detuvo (cambió el texto o se cerró la pantalla)
      }
      if (!mounted) return;
      _c.value = 0;
      _loop();
    });
  }

  /// Arranca o detiene DESPUÉS de dibujar (nunca durante el dibujo).
  void _schedule(double? textW) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (textW == null) {
        if (_textW != 0) _reset();
        return;
      }
      if (textW == _textW) return;
      _reset();
      _textW = textW;
      _loop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        if (tp.width <= box.maxWidth) {
          if (_textW != 0) _schedule(null);
          return Text(widget.text, maxLines: 1, style: widget.style);
        }
        if (tp.width != _textW) _schedule(tp.width);
        return SizedBox(
          height: tp.height,
          child: ClipRect(
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, 0.04, 0.92, 1],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final dx =
                      -(tp.width + _gap) * Curves.easeInOut.transform(_c.value);
                  return OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: double.infinity,
                    child: Transform.translate(
                      offset: Offset(dx, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.text, maxLines: 1, style: widget.style),
                          const SizedBox(width: _gap),
                          Text(widget.text, maxLines: 1, style: widget.style),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
