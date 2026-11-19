import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/player_route.dart';
import 'explore_tab.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'search_tab.dart';

/// Pantalla principal con las 4 pestañas, el mini-reproductor y la barra de vidrio.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: ValueListenableBuilder<double>(
        valueListenable: playerOpenProgress,
        builder: (context, p, child) {
          if (p <= 0.001) return child!;
          // Mientras el reproductor sube, el menú se encoge y oscurece un poco (como en iPhone).
          return Transform.scale(
            scale: 1 - 0.06 * p,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28 * p),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child!,
                  IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.35 * p),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: _scaffold(bottom),
      ),
    );
  }

  Widget _scaffold(double bottom) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: [
              HomeTab(onGoTo: (i) => setState(() => _tab = i)),
              const ExploreTab(),
              const LibraryTab(),
              SearchTab(active: _tab == 3),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + bottom + 66 + 10,
            child: const MiniPlayer(),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + bottom,
            child: GlassNavBar(
              index: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),
        ],
      ),
    );
  }
}

/// Espacio al final de cada pestaña para que nada quede debajo de la barra.
const kTabBottomSpace = 190.0;
