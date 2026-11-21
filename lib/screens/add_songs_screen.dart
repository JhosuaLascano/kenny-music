import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Elegir varias canciones de una vez para agregarlas a una playlist.
class AddSongsScreen extends StatefulWidget {
  const AddSongsScreen({super.key, required this.playlist});
  final Playlist playlist;

  @override
  State<AddSongsScreen> createState() => _AddSongsScreenState();
}

class _AddSongsScreenState extends State<AddSongsScreen> {
  final _selected = <String>{};
  String _q = '';

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final already = widget.playlist.songIds.toSet();
    final q = _norm(_q.trim());
    final songs = store.allSongs
        .where(
          (s) =>
              q.isEmpty ||
              _norm(s.title).contains(q) ||
              _norm(s.artist).contains(q) ||
              _norm(s.album).contains(q),
        )
        .toList();
    final selectable = songs.where((s) => !already.contains(s.id)).toList();
    final allOn =
        selectable.isNotEmpty &&
        selectable.every((s) => _selected.contains(s.id));

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: kMuted)),
        ),
        leadingWidth: 96,
        title: Text(
          'Agregar a "${widget.playlist.name}"',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: selectable.isEmpty
                ? null
                : () => setState(() {
                    if (allOn) {
                      _selected.removeAll(selectable.map((s) => s.id));
                    } else {
                      _selected.addAll(selectable.map((s) => s.id));
                    }
                  }),
            child: Text(
              allOn ? 'Ninguna' : 'Todas',
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Buscar canción o artista',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: kSurface,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, i) {
                final s = songs[i];
                final inList = already.contains(s.id);
                final on = inList || _selected.contains(s.id);
                return InkWell(
                  onTap: inList
                      ? null
                      : () => setState(() {
                          if (!_selected.remove(s.id)) _selected.add(s.id);
                        }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: on
                                ? (inList ? kSurface2 : accent)
                                : Colors.transparent,
                            border: Border.all(
                              color: on
                                  ? (inList ? kSurface2 : accent)
                                  : const Color(0xFF52525B),
                              width: 2,
                            ),
                          ),
                          child: on
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 17,
                                  color: inList ? kMuted : Colors.black,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        CoverArt(song: s, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: inList ? kMuted : kText,
                                ),
                              ),
                              Text(
                                inList ? 'Ya está en la playlist' : s.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () {
                          // Se agregan en el orden de la lista (alfabético).
                          final ids = store.allSongs
                              .where((s) => _selected.contains(s.id))
                              .map((s) => s.id)
                              .toList();
                          final n = store.addToPlaylist(widget.playlist, ids);
                          Navigator.pop(context);
                          toast(
                            context,
                            n == 1
                                ? 'Se agregó 1 canción'
                                : 'Se agregaron $n canciones',
                          );
                        },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Elige canciones'
                        : 'Agregar ${_selected.length} '
                              '${_selected.length == 1 ? 'canción' : 'canciones'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
