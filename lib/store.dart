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
  int blurAmount = 60; // 0-100, desenfoque de la portada de fondo
  int gradIntensity = 70; // 0-100, cuánto color tiene el degradado
  String playerLayout =
      'classic'; // classic | full | visual | minimal | lyrics | poster
  String progressStyle = 'thin'; // thin | capsule | wave
  String homeLayout = 'list'; // list | grid | featured
  List<double> eqGains = [0, 0, 0, 0, 0]; // ecualizador (dB, solo Android)
  int accentIndex = kWhiteAccent;

  /// Solo cambia con el color de acento (la app entera escucha esto, no todo el store).
  final accentNotifier = ValueNotifier<int>(kWhiteAccent);
  int crossfade = 5; // segundos, 0 = apagado
  bool onlineLyrics = true;
  bool autoplay = false; // reproducción continua (∞)
  bool translateLyrics = false; // mostrar traducción al español
  int lyricsSize = 24; // tamaño de la letra (px)

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
        final ses = j['session'] as Map? ?? {};
        lastQueue = (ses['queue'] as List? ?? []).cast<String>();
        lastIndex = (ses['index'] as num?)?.toInt() ?? 0;
        lastPosMs = (ses['pos'] as num?)?.toInt() ?? 0;
        lastFrom = ses['from'] as String? ?? lastFrom;
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
        blurAmount = (s['blurAmount'] as num?)?.toInt() ?? blurAmount;
        gradIntensity = (s['gradIntensity'] as num?)?.toInt() ?? gradIntensity;
        playerLayout = s['playerLayout'] as String? ?? playerLayout;
        progressStyle = s['progressStyle'] as String? ?? progressStyle;
        homeLayout = s['homeLayout'] as String? ?? homeLayout;
        final eq = s['eqGains'] as List?;
        if (eq != null) eqGains = eq.map((e) => (e as num).toDouble()).toList();
        accentIndex = (s['accentIndex'] as num?)?.toInt() ?? accentIndex;
        // Cambio a un estilo sin color: el acento pasa a ser blanco una vez.
        if (s['neutral'] != true) accentIndex = kWhiteAccent;
        accentNotifier.value = accentIndex;
        crossfade = (s['crossfade'] as num?)?.toInt() ?? crossfade;
        onlineLyrics = s['onlineLyrics'] as bool? ?? onlineLyrics;
        autoplay = s['autoplay'] as bool? ?? autoplay;
        translateLyrics = s['translateLyrics'] as bool? ?? translateLyrics;
        lyricsSize = (s['lyricsSize'] as num?)?.toInt() ?? lyricsSize;
      }
    } catch (e) {
      debugPrint('No se pudo leer los datos: $e');
    }
  }

  // Listas ordenadas y agrupadas: se calculan una vez y se reutilizan hasta
  // que algo cambia (antes cada pestaña las recalculaba en cada redibujo,
  // y con muchas canciones eso trababa la app).
  int _ver = 0;
  final Map<String, (int, Object)> _memo = {};
  T _cached<T extends Object>(String key, T Function() build) {
    final m = _memo[key];
    if (m != null && m.$1 == _ver) return m.$2 as T;
    final v = build();
    _memo[key] = (_ver, v);
    return v;
  }

  // ---------- Última sesión (para retomar donde quedaste) ----------
  List<String> lastQueue = [];
  int lastIndex = 0;
  int lastPosMs = 0;
  String lastFrom = 'tu biblioteca';

  /// Guarda la cola y la posición SIN redibujar la app.
  void saveSession(List<String> queue, int index, int posMs, String from) {
    lastQueue = queue;
    lastIndex = index;
    lastPosMs = posMs;
    lastFrom = from;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _save);
  }

  void _changed() {
    _ver++;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _save);
  }

  Future<void> _save() async {
    final j = {
      'songs': songs.values.map((s) => s.toJson()).toList(),
      'favorites': favorites.toList(),
      'playlists': playlists.map((p) => p.toJson()).toList(),
      'recents': recents,
      'session': {
        'queue': lastQueue,
        'index': lastIndex,
        'pos': lastPosMs,
        'from': lastFrom,
      },
      'plays': plays,
      'listenMs': listenMs,
      'weekMs': weekMs,
      'settings': {
        'bgStyle': bgStyle,
        'homeBgStyle': homeBgStyle,
        'blurAmount': blurAmount,
        'gradIntensity': gradIntensity,
        'playerLayout': playerLayout,
        'progressStyle': progressStyle,
        'homeLayout': homeLayout,
        'eqGains': eqGains,
        'accentIndex': accentIndex,
        'neutral': true,
        'crossfade': crossfade,
        'onlineLyrics': onlineLyrics,
        'autoplay': autoplay,
        'translateLyrics': translateLyrics,
        'lyricsSize': lyricsSize,
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

  List<Song> get allSongs => _cached('all', _allSongs);
  List<Song> _allSongs() {
    final l = songs.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return l;
  }

  List<Song> get newest => _cached('newest', _newest);
  List<Song> _newest() {
    final l = songs.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return l;
  }

  List<Song> get mostPlayed => _cached('most', _mostPlayed);
  List<Song> _mostPlayed() {
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

  List<SongGroup> get albums => _cached('albums', _albums);
  List<SongGroup> _albums() {
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

  List<SongGroup> get artists => _cached('artists', _artists);
  List<SongGroup> _artists() {
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
  List<SongGroup> get folders => _cached('folders', _folders);
  List<SongGroup> _folders() {
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

  // ---------- Copia de seguridad ----------

  /// Playlists, favoritas y reproducciones en un archivo. Las canciones se
  /// guardan por su ruta, así se reconocen al reinstalar la app.
  String exportBackup() {
    String? pathOf(String id) => songs[id]?.path;
    return const JsonEncoder.withIndent(' ').convert({
      'app': 'kenny_music',
      'version': 1,
      'date': DateTime.now().toIso8601String(),
      'favorites': favorites.map(pathOf).whereType<String>().toList(),
      'playlists': [
        for (final p in playlists)
          {
            'name': p.name,
            'songs': p.songIds.map(pathOf).whereType<String>().toList(),
          },
      ],
      'plays': {
        for (final e in plays.entries)
          if (pathOf(e.key) != null) pathOf(e.key)!: e.value,
      },
      'listenMs': listenMs,
    });
  }

  /// Junta la copia con lo que ya hay. Devuelve cuántas playlists se tocaron.
  int importBackup(String text) {
    final j = jsonDecode(text);
    if (j is! Map || j['app'] != 'kenny_music') {
      throw const FormatException('No es una copia de Kenny Music');
    }
    String? idOf(Object? path) {
      if (path is! String) return null;
      final id = songIdFor(path);
      return songs.containsKey(id) ? id : null;
    }

    for (final f in (j['favorites'] as List? ?? [])) {
      final id = idOf(f);
      if (id != null) favorites.add(id);
    }
    var n = 0;
    for (final p in (j['playlists'] as List? ?? [])) {
      final name = (p as Map)['name'] as String? ?? 'Playlist';
      final ids = (p['songs'] as List? ?? []).map(idOf).whereType<String>();
      final existing = playlists.where((x) => x.name == name);
      final target = existing.isNotEmpty
          ? existing.first
          : createPlaylist(name);
      for (final id in ids) {
        if (!target.songIds.contains(id)) target.songIds.add(id);
      }
      n++;
    }
    (j['plays'] as Map? ?? {}).forEach((path, count) {
      final id = idOf(path);
      if (id != null) {
        final c = (count as num).toInt();
        if (c > (plays[id] ?? 0)) plays[id] = c;
      }
    });
    final ms = (j['listenMs'] as num?)?.toInt() ?? 0;
    if (ms > listenMs) listenMs = ms;
    _changed();
    return n;
  }

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

  /// Ordena la playlist de una vez: 'title', 'artist', 'recent' o 'duration'.
  void sortPlaylist(Playlist p, String by) {
    final list = songsOf(p);
    switch (by) {
      case 'title':
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case 'artist':
        list.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
      case 'recent':
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case 'duration':
        list.sort((a, b) => a.durationMs.compareTo(b.durationMs));
    }
    p.songIds
      ..clear()
      ..addAll(list.map((s) => s.id));
    _changed();
  }

  // ---------- Ajustes ----------

  void setBgStyle(String v) {
    bgStyle = v;
    _changed();
  }

  void setBlurAmount(int v) {
    blurAmount = v;
    _changed();
  }

  void setGradIntensity(int v) {
    gradIntensity = v;
    _changed();
  }

  void setProgressStyle(String v) {
    progressStyle = v;
    _changed();
  }

  void setHomeLayout(String v) {
    homeLayout = v;
    _changed();
  }

  void setEqGain(int band, double db) {
    while (eqGains.length <= band) {
      eqGains.add(0);
    }
    eqGains[band] = db;
    _changed();
  }

  void setPlayerLayout(String v) {
    playerLayout = v;
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

  void setTranslateLyrics(bool v) {
    translateLyrics = v;
    _changed();
  }

  void setLyricsSize(int v) {
    lyricsSize = v.clamp(16, 34);
    _changed();
  }

  void setAutoplay(bool v) {
    autoplay = v;
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

const kWhiteAccent = 18; // índice de 'Blanco' en theme.dart
