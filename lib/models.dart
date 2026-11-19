/// Una canción de la biblioteca.
///
/// [path] y [cover] pueden empezar con `app:`; en ese caso son relativos a la
/// carpeta de la app (en iOS esa carpeta cambia al actualizar la app, por eso
/// no se guarda la ruta completa).
class Song {
  Song({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.addedAt,
    this.cover,
    this.genres = const [],
  });

  final String id;
  final String path;
  String title;
  String artist;
  String album;
  int durationMs;
  final int addedAt;
  String? cover;
  List<String> genres;

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        'addedAt': addedAt,
        'cover': cover,
        'genres': genres,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] as String,
        path: j['path'] as String,
        title: j['title'] as String? ?? 'Sin título',
        artist: j['artist'] as String? ?? 'Artista desconocido',
        album: j['album'] as String? ?? 'Sin álbum',
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        addedAt: (j['addedAt'] as num?)?.toInt() ?? 0,
        cover: j['cover'] as String?,
        genres: (j['genres'] as List?)?.cast<String>() ?? const [],
      );
}

class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
  });

  final String id;
  String name;
  List<String> songIds;
  final int createdAt;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'songIds': songIds, 'createdAt': createdAt};

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: j['name'] as String,
        songIds: (j['songIds'] as List).cast<String>(),
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      );
}

/// Álbum o artista agrupado a partir de las canciones.
class SongGroup {
  SongGroup(this.name, this.subtitle, this.songs);
  final String name;
  final String subtitle;
  final List<Song> songs;
  Song get first => songs.first;
}

/// Identificador estable a partir de la ruta guardada (dos hashes de 32 bits).
String songIdFor(String storedPath) {
  var fnv = 0x811c9dc5;
  var djb = 5381;
  for (final c in storedPath.codeUnits) {
    fnv = ((fnv ^ c) * 16777619) & 0xFFFFFFFF;
    djb = ((djb << 5) + djb + c) & 0xFFFFFFFF;
  }
  return '${fnv.toRadixString(16).padLeft(8, '0')}${djb.toRadixString(16).padLeft(8, '0')}';
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
