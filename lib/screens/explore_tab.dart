import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'home_tab.dart';
import 'song_list_screen.dart';

/// Explorar por artistas y álbumes.
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  int _mode = 0; // 0 artistas, 1 álbumes

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final artists = store.artists;
          final albums = store.albums;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Explorar',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('Artistas')),
                          ButtonSegment(value: 1, label: Text('Álbumes')),
                        ],
                        selected: {_mode},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) =>
                            setState(() => _mode = s.first),
                      ),
                    ],
                  ),
                ),
              ),
              if (store.songs.isEmpty)
                const SliverToBoxAdapter(child: EmptyLibrary()),
              if (_mode == 0)
                SliverList.builder(
                  itemCount: artists.length,
                  itemBuilder: (context, i) {
                    final a = artists[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      leading: ClipOval(
                        child: CoverArt(song: a.first, size: 48, radius: 24),
                      ),
                      title: Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        a.subtitle,
                        style: const TextStyle(color: kMuted),
                      ),
                      onTap: () => openList(
                        context,
                        a.name,
                        () =>
                            store.songs.values
                                .where((s) => s.artist == a.name)
                                .toList()
                              ..sort((x, y) => x.title.compareTo(y.title)),
                      ),
                    );
                  },
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverLayoutBuilder(
                    builder: (context, c) {
                      final cols = c.crossAxisExtent > 600 ? 4 : 2;
                      final size = (c.crossAxisExtent - 16 * (cols - 1)) / cols;
                      return SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: size + 52,
                        ),
                        itemCount: albums.length,
                        itemBuilder: (context, i) =>
                            AlbumCard(group: albums[i], size: size),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: kTabBottomSpace),
              ),
            ],
          );
        },
      ),
    );
  }
}
