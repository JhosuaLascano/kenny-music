import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Qué tan abierto está el reproductor (0 = cerrado, 1 = abierto).
/// La pantalla de atrás lo usa para encogerse un poco, como en iPhone.
final playerOpenProgress = ValueNotifier<double>(0);

const _spring = SpringDescription(mass: 1, stiffness: 170, damping: 19);

/// Curva de resorte: llega, se pasa un poquito y regresa (rebote suave).
class SpringCurve extends Curve {
  const SpringCurve([this.seconds = 0.55]);
  final double seconds;

  @override
  double transformInternal(double t) =>
      SpringSimulation(_spring, 0, 1, 0).x(t * seconds);
}

/// Ruta del reproductor: sube con rebote y se puede bajar arrastrando con el dedo.
class PlayerRoute extends PageRoute<void> {
  PlayerRoute({required this.builder});

  final WidgetBuilder builder;
  bool _gesture = false;

  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  bool get opaque => false;
  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 550);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 380);

  @override
  AnimationController createAnimationController() {
    final c = super.createAnimationController();
    c.addListener(() => playerOpenProgress.value = c.value.clamp(0.0, 1.0));
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed || s == AnimationStatus.dismissed)
        _gesture = false;
    });
    return c;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final v = animation.value;
        final double t;
        if (_gesture) {
          t = v; // sigue al dedo exactamente
        } else if (animation.status == AnimationStatus.reverse) {
          t = 1 - Curves.easeOutCubic.transform(1 - v);
        } else {
          t = const SpringCurve().transform(v);
        }
        final h = MediaQuery.sizeOf(context).height;
        final radius = (1 - t).clamp(0.0, 1.0) * 60 + (t < 0.999 ? 20 : 0);
        return Transform.translate(
          offset: Offset(0, (1 - t) * h),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
            child: child,
          ),
        );
      },
    );
  }

  // ---- Arrastrar para cerrar ----

  void dragStart() {
    if (controller == null || controller!.isAnimating) return;
    _gesture = true;
    navigator?.didStartUserGesture();
  }

  void dragUpdate(double dy, double height) {
    if (!_gesture) return;
    controller!.value = (controller!.value - dy / height).clamp(0.0, 1.0);
  }

  void dragEnd(double velocity, double height) {
    if (!_gesture) return;
    final c = controller!;
    final v = velocity / height; // pantallas por segundo
    if (v > 1.1 || (c.value < 0.7 && v > -0.5)) {
      navigator?.pop();
      if (c.isAnimating) {
        c.animateBack(
          0,
          duration: Duration(
            milliseconds: (380 * c.value).round().clamp(120, 380),
          ),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      c.animateWith(SpringSimulation(_spring, c.value, 1, -v));
    }
    navigator?.didStopUserGesture();
  }
}
