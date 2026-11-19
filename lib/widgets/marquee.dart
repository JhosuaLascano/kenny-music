import 'package:flutter/material.dart';

/// Texto que se desliza solo cuando no cabe (como el título en el reproductor).
class Marquee extends StatefulWidget {
  const Marquee(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  double _textW = 0;
  static const _gap = 48.0;
  static const _pause = 2.0; // segundos quieto antes de moverse

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _setup(double textW) {
    if (textW == _textW && _c.isAnimating) return;
    _textW = textW;
    final moveSecs = (textW + _gap) / 35;
    _c.duration = Duration(milliseconds: ((moveSecs + _pause) * 1000).round());
    _c.repeat();
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
        final h = tp.height;
        if (tp.width <= box.maxWidth) {
          if (_c.isAnimating) _c.stop();
          _c.value = 0;
          return Text(widget.text, maxLines: 1, style: widget.style);
        }
        _setup(tp.width);
        final total = _c.duration!.inMilliseconds / 1000;
        return SizedBox(
          height: h,
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
                  final secs = _c.value * total;
                  final p = secs < _pause
                      ? 0.0
                      : (secs - _pause) / (total - _pause);
                  final dx =
                      -(tp.width + _gap) *
                      Curves.easeInOut.transform(p.clamp(0.0, 1.0));
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
