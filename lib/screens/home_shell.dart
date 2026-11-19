import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/common.dart';
import 'home_tab.dart';
import 'player_screen.dart';
import 'tabs.dart';

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
    // Lo justo para no tapar los botones de Android ni la rayita del iPhone.
    final pad = MediaQuery.viewPaddingOf(context).bottom;
    final bottom = Platform.isIOS ? (pad - 14).clamp(8.0, 40.0) : pad + 4;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Fondo con el color de la canción que suena (según Ajustes).
            Positioned.fill(
              child: StreamBuilder<MediaItem?>(
                stream: audio.mediaItem,
                builder: (context, _) => ListenableBuilder(
                  listenable: store,
                  builder: (context, _) {
                    final song = audio.current;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: PlayerBackground(
                        key: ValueKey(
                          '${song?.id}-${song?.cover}-${store.homeBgStyle}',
                        ),
                        song: song,
                        style: store.homeBgStyle,
                        home: true,
                      ),
                    );
                  },
                ),
              ),
            ),
            IndexedStack(
              index: _tab,
              children: [
                HomeTab(onGoTo: (i) => setState(() => _tab = i)),
                const ListsTab(),
                const FolderTab(),
                const AlbumsTab(),
                const MoreTab(),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottom + 62 + 8,
              child: const MiniPlayer(),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottom,
              child: GlassNavBar(
                index: _tab,
                onTap: (i) => setState(() => _tab = i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Espacio al final de cada pestaña para que nada quede debajo de la barra.
const kTabBottomSpace = 170.0;
