import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key, required this.active});
  final bool active;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _ctrl = TextEditingController();
  String _q = '';

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final q = _norm(_q.trim());
          final results = q.isEmpty
              ? <dynamic>[]
              : store.allSongs
                    .where(
                      (s) =>
                          _norm(s.title).contains(q) ||
                          _norm(s.artist).contains(q) ||
                          _norm(s.album).contains(q),
                    )
                    .toList();
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Buscar',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _ctrl,
                        onChanged: (v) => setState(() => _q = v),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Canción, artista o álbum',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _q.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Borrar',
                                  onPressed: () => setState(() {
                                    _ctrl.clear();
                                    _q = '';
                                  }),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: kSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (q.isNotEmpty && results.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Sin resultados',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kMuted),
                    ),
                  ),
                ),
              SliverList.builder(
                itemCount: results.length,
                itemBuilder: (context, i) => SongTile(
                  song: results[i],
                  onTap: () => audio.playSongs(results.cast(), start: i),
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
