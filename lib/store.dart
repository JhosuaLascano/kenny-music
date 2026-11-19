import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Toda la información guardada de la app: canciones, favoritas, playlists,
/// recientes y ajustes. Se guarda en un archivo JSON dentro de la app.
class LibraryStore extends ChangeNotifier {
  late String baseDir;
  final Map<String, Song> songs = {};
  final Set<String> favorites = {};
  final List<Playlist> playlists = [];
  final List<String> recents = [];
  final Map<String, int> plays = {};

  /// Tiempo escuchado (ms): total y por semana (clave = lunes de esa semana).
  int listenMs = 0;
  final Map<String, int> weekMs = {};

  // Ajustes
  String bgStyle = 'blur'; // blur | grad | solid
  String homeBgStyle = 'grad'; // fondo del menú principal
  int accentIndex = 0;

  /// Solo cambia con el color de acento (la app entera escucha esto, no todo el store).
  final accentNotifier = ValueNotifier<int>(0);
  int crossfade = 5; // segundos, 0 = apagado
  bool onlineLyrics = true;

  Timer? _saveTimer;
  bool scanning = false;
  String? scanMessage;

  File get _file => File('$baseDir/kenny_data.json');

  Future<void> load() async {
    baseDir = (await getApplicationDocumentsDirectory()).path;
    for (final d in ['music', 'covers', 'lyrics']) {
      await Directory('$baseDir/$d').create(recursive: true);
    }
    try {
      if (await _file.exists()) {
        final j =
            jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
        for (final s in (j['songs'] as List? ?? [])) {
          final song = Song.fromJson(s as Map<String, dynamic>);
          songs[song.id] = song;
        }
        favorites.addAll((j['favorites'] as List? ?? []).cast<String>());
        playlists.addAll(
          (j['playlists'] as List? ?? []).map(
            (p) => Playlist.fromJson(p as Map<String, dynamic>),
          ),
        );
        recents.addAll((j['recents'] as List? ?? []).cast<String>());
        listenMs = (j['listenMs'] as num?)?.toInt() ?? 0;
        (j['weekMs'] as Map? ?? {}).forEach(
          (k, v) => weekMs[k as String] = (v as num).toInt(),
        );
        (j['plays'] as Map? ?? {}).forEach(
          (k, v) => plays[k as String] = (v as num).toInt(),
        );
        final s = j['settings'] as Map? ?? {};
        bgStyle = s['bgStyle'] as String? ?? bgStyle;
        homeBgStyle = s['homeBgStyle'] as String? ?? homeBgStyle;
        accentIndex = (s['accentIndex'] as num?)?.toInt() ?? accentIndex;
        accentNotifier.value = accentIndex;
        crossfade = (s['crossfade'] as num?)?.toInt() ?? crossfade;
        onlineLyrics = s['onlineLyrics'] as bool? ?? onlineLyrics;
      }
    } catch (e) {
      debugPrint('No se pudo leer los datos: $e');
    }
  }

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    final j = {
      'songs': songs.values.map((s) => s.toJson()).toList(),
      'favorites': favorites.toList(),
      'playlists': playlists.map((p) => p.toJson()).toList(),
      'recents': recents,
      'plays': plays,
      'listenMs': listenMs,
      'weekMs': weekMs,
      'settings': {
        'bgStyle': bgStyle,
        'homeBgStyle': homeBgStyle,
        'accentIndex': accentIndex,
        'crossfade': crossfade,
        'onlineLyrics': onlineLyrics,
      },
    };
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(j));
    await tmp.rename(_file.path);
  }

  /// Convierte una ruta guardada (`app:...`) en ruta real.
  String resolve(String p) =>
      p.startsWith('app:') ? '$baseDir/${p.substring(4)}' : p;

  // ---------- Canciones ----------

  List<Song> get allSongs {
    final l = songs.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return l;
  }

  List<Song> get newest {
    final l = songs.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return l;
  }

  List<Song> get mostPlayed {
    final l = songs.values.where((s) => (plays[s.id] ?? 0) > 0).toList()
      ..sort((a, b) => (plays[b.id] ?? 0).compareTo(plays[a.id] ?? 0));
    return l;
  }

  List<Song> get recentSongs =>
      recents.map((id) => songs[id]).whereType<Song>().toList();

  List<Song> get favoriteSongs =>
      allSongs.where((s) => favorites.contains(s.id)).toList();

  List<Song> songsOf(Playlist p) =>
      p.songIds.map((id) => songs[id]).whereType<Song>().toList();

  List<SongGroup> get albums {
    final map = <String, List<Song>>{};
    for (final s in songs.values) {
      map.putIfAbsent('${s.album}\u0000${s.artist}', () => []).add(s);
    }
    final groups =
        map.values
            .map(
              (l) => SongGroup(
                l.first.album,
                l.first.artist,
                l..sort((a, b) => a.title.compareTo(b.title)),
              ),
            )
            .toList()
          ..sort(
            (a, b) => b.songs
                .map((s) => s.addedAt)
                .reduce((x, y) => x > y ? x : y)
                .compareTo(
                  a.songs.map((s) => s.addedAt).reduce((x, y) => x > y ? x : y),
                ),
          );
    return groups;
  }

  List<SongGroup> get artists {
    final map = <String, List<Song>>{};
    for (final s in songs.values) {
      map.putIfAbsent(s.artist, () => []).add(s);
    }
    return map.entries
        .map(
          (e) => SongGroup(
            e.key,
            '${e.value.length} ${e.value.length == 1 ? 'canción' : 'canciones'}',
            e.value..sort((a, b) => a.title.compareTo(b.title)),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void addSongs(Iterable<Song> list) {
    for (final s in list) {
      songs[s.id] = s;
    }
    _changed();
  }

  /// Quita de la biblioteca las canciones cuyo archivo ya no existe.
  int removeMissing() {
    final gone = songs.values
        .where((s) => !File(resolve(s.path)).existsSync())
        .map((s) => s.id)
        .toList();
    for (final id in gone) {
      _forget(id);
    }
    if (gone.isNotEmpty) _changed();
    return gone.length;
  }

  void _forget(String id) {
    final s = songs.remove(id);
    favorites.remove(id);
    recents.remove(id);
    plays.remove(id);
    for (final p in playlists) {
      p.songIds.remove(id);
    }
    if (s?.cover != null && s!.cover!.startsWith('app:')) {
      try {
        File(resolve(s.cover!)).deleteSync();
      } catch (_) {}
    }
  }

  /// Quita la canción de la biblioteca. Si fue importada a la app, también
  /// borra la copia; los archivos propios del celular no se tocan.
  void removeSong(String id) {
    final s = songs[id];
    if (s == null) return;
    if (s.path.startsWith('app:')) {
      try {
        File(resolve(s.path)).deleteSync();
      } catch (_) {}
    }
    _forget(id);
    _changed();
  }

  void updateDuration(String id, Duration d) {
    final s = songs[id];
    if (s == null || s.durationMs > 0) return;
    s.durationMs = d.inMilliseconds;
    _changed();
  }

  /// Canciones agrupadas por la carpeta donde están en el celular.
  List<SongGroup> get folders {
    final map = <String, List<Song>>{};
    for (final s in songs.values) {
      final String name;
      if (s.path.startsWith('app:')) {
        name = 'Importadas';
      } else {
        final parts = s.path.split('/');
        name = parts.length > 1 ? parts[parts.length - 2] : 'Otras';
      }
      map.putIfAbsent(name, () => []).add(s);
    }
    return map.entries
        .map(
          (e) => SongGroup(
            e.key,
            '${e.value.length} ${e.value.length == 1 ? 'canción' : 'canciones'}',
            e.value..sort((a, b) => a.title.compareTo(b.title)),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<Song> albumSongs(String album, String artist) =>
      songs.values.where((s) => s.album == album && s.artist == artist).toList()
        ..sort((a, b) => a.title.compareTo(b.title));

  /// Cambia la imagen de la canción por una elegida por el usuario.
  Future<void> setCustomCover(String id, String sourcePath) async {
    final s = songs[id];
    if (s == null) return;
    final ext = sourcePath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    // Nombre nuevo cada vez para que la imagen vieja no quede en caché.
    final name = '${id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(sourcePath).copy('$baseDir/covers/$name');
    final old = s.cover;
    s.cover = 'app:covers/$name';
    if (old != null && old.startsWith('app:covers/${id}_')) {
      try {
        File(resolve(old)).deleteSync();
      } catch (_) {}
    }
    _changed();
  }

  static String _weekKey(DateTime d) {
    final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  int get listenMinutes => listenMs ~/ 60000;
  int get weekMinutes => (weekMs[_weekKey(DateTime.now())] ?? 0) ~/ 60000;

  /// Suma tiempo escuchado. Solo avisa y guarda cuando cambia el minuto.
  void addListen(int ms) {
    final before = listenMinutes;
    listenMs += ms;
    final k = _weekKey(DateTime.now());
    weekMs[k] = (weekMs[k] ?? 0) + ms;
    if (weekMs.length > 8) {
      final keys = weekMs.keys.toList();
      for (final old in keys.take(keys.length - 8)) {
        weekMs.remove(old);
      }
    }
    if (listenMinutes != before) _changed();
  }

  void markPlayed(String id) {
    recents.remove(id);
    recents.insert(0, id);
    if (recents.length > 30) recents.removeRange(30, recents.length);
    plays[id] = (plays[id] ?? 0) + 1;
    _changed();
  }

  // ---------- Favoritas ----------

  bool isFavorite(String id) => favorites.contains(id);

  void toggleFavorite(String id) {
    if (!favorites.remove(id)) favorites.add(id);
    _changed();
  }

  // ---------- Playlists ----------

  Playlist createPlaylist(String name) {
    final p = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name,
      songIds: [],
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    playlists.add(p);
    _changed();
    return p;
  }

  void renamePlaylist(Playlist p, String name) {
    p.name = name;
    _changed();
  }

  void deletePlaylist(Playlist p) {
    playlists.remove(p);
    _changed();
  }

  /// Agrega canciones a la playlist; devuelve cuántas eran nuevas.
  int addToPlaylist(Playlist p, List<String> ids) {
    var n = 0;
    for (final id in ids) {
      if (!p.songIds.contains(id)) {
        p.songIds.add(id);
        n++;
      }
    }
    _changed();
    return n;
  }

  void removeFromPlaylist(Playlist p, String id) {
    p.songIds.remove(id);
    _changed();
  }

  void reorderPlaylist(Playlist p, int oldIndex, int newIndex) {
    final id = p.songIds.removeAt(oldIndex);
    p.songIds.insert(newIndex, id);
    _changed();
  }

  // ---------- Ajustes ----------

  void setBgStyle(String v) {
    bgStyle = v;
    _changed();
  }

  void setHomeBgStyle(String v) {
    homeBgStyle = v;
    _changed();
  }

  void setAccent(int i) {
    accentIndex = i;
    accentNotifier.value = i;
    _changed();
  }

  void setCrossfade(int s) {
    crossfade = s;
    _changed();
  }

  void setOnlineLyrics(bool v) {
    onlineLyrics = v;
    _changed();
  }

  void setScanning(bool v, [String? msg]) {
    scanning = v;
    scanMessage = msg;
    notifyListeners();
  }
}
