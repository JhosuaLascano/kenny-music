import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_state.dart';
import 'models.dart';

const audioExtensions = {'mp3', 'm4a', 'flac', 'wav', 'aac'};

/// Carpetas del celular que nunca tienen música (tonos, notas de voz...).
const _skipFolders = {
  'android',
  'notifications',
  'ringtones',
  'alarms',
  'recordings',
  'call',
  'whatsapp voice notes',
  'whatsapp audio',
  'voice recorder',
};

String _ext(String path) {
  final i = path.lastIndexOf('.');
  return i < 0 ? '' : path.substring(i + 1).toLowerCase();
}

String fileNameOf(String path) => path.split(RegExp(r'[\\/]')).last;

/// Pide permiso para leer la música del celular (solo Android).
Future<bool> askAudioPermission() async {
  if (!Platform.isAndroid) return true;
  if ((await Permission.audio.request()).isGranted) return true;
  return (await Permission.storage.request()).isGranted;
}

/// Busca canciones en todo el almacenamiento del celular (Android).
/// Devuelve cuántas canciones nuevas se agregaron, o -1 si no hay permiso.
Future<int> scanDevice() async {
  if (!await askAudioPermission()) return -1;
  store.setScanning(true, 'Buscando música en el celular…');
  try {
    final found = <String>[];
    final roots = <Directory>[Directory('/storage/emulated/0')];
    try {
      for (final e in Directory('/storage').listSync(followLinks: false)) {
        final n = fileNameOf(e.path);
        if (e is Directory && n != 'emulated' && n != 'self') roots.add(e);
      }
    } catch (_) {}
    for (final r in roots) {
      await _walk(r, found, 0);
    }
    store.removeMissing();
    final fresh = found.where((p) => !store.songs.containsKey(songIdFor(p))).toList();
    final added = await _process(fresh, fresh);
    return added;
  } finally {
    store.setScanning(false);
  }
}

Future<void> _walk(Directory d, List<String> out, int depth) async {
  if (depth > 10) return;
  List<FileSystemEntity> items;
  try {
    items = await d.list(followLinks: false).toList();
  } catch (_) {
    return;
  }
  for (final e in items) {
    final name = fileNameOf(e.path);
    if (name.startsWith('.')) continue;
    if (e is Directory) {
      if (_skipFolders.contains(name.toLowerCase())) continue;
      await _walk(e, out, depth + 1);
    } else if (e is File && audioExtensions.contains(_ext(name))) {
      try {
        if (e.lengthSync() < 150 * 1024) continue; // tonos y notas cortas
      } catch (_) {
        continue;
      }
      out.add(e.path);
    }
  }
}

/// Abre el selector de archivos, copia las canciones dentro de la app y las
/// agrega. Devuelve cuántas se agregaron (null si el usuario canceló).
Future<int?> importFiles() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: audioExtensions.toList(),
  );
  if (files.isEmpty) return null;
  store.setScanning(true, 'Importando ${files.length} canciones…');
  try {
    final real = <String>[];
    final stored = <String>[];
    for (final f in files) {
      final src = f.path;
      if (src == null) continue;
      var name = fileNameOf(src);
      var dest = File('${store.baseDir}/music/$name');
      var n = 1;
      while (await dest.exists()) {
        final dot = name.lastIndexOf('.');
        final alt = '${name.substring(0, dot)} ($n)${name.substring(dot)}';
        dest = File('${store.baseDir}/music/$alt');
        n++;
      }
      await File(src).copy(dest.path);
      try {
        if (!Platform.isAndroid) await File(src).delete(); // copia temporal del selector
      } catch (_) {}
      real.add(dest.path);
      stored.add('app:music/${fileNameOf(dest.path)}');
    }
    return await _process(real, stored);
  } finally {
    store.setScanning(false);
  }
}

/// Lee etiquetas, portada y letra embebida en segundo plano y agrega las
/// canciones a la biblioteca.
Future<int> _process(List<String> realPaths, List<String> storedPaths) async {
  if (realPaths.isEmpty) return 0;
  final base = store.baseDir;
  var added = 0;
  const batch = 25;
  for (var i = 0; i < realPaths.length; i += batch) {
    final end = (i + batch).clamp(0, realPaths.length);
    store.setScanning(true, 'Leyendo canciones… $end/${realPaths.length}');
    final real = realPaths.sublist(i, end);
    final stored = storedPaths.sublist(i, end);
    final maps = await Isolate.run(() => _readBatch(real, stored, base));
    final now = DateTime.now().millisecondsSinceEpoch;
    store.addSongs(maps.map((m) => Song(
          id: m['id'] as String,
          path: m['path'] as String,
          title: m['title'] as String,
          artist: m['artist'] as String,
          album: m['album'] as String,
          durationMs: m['durationMs'] as int,
          addedAt: now,
          cover: m['cover'] as String?,
          genres: (m['genres'] as List).cast<String>(),
        )));
    added += maps.length;
  }
  return added;
}

List<Map<String, Object?>> _readBatch(List<String> real, List<String> stored, String base) {
  final out = <Map<String, Object?>>[];
  for (var i = 0; i < real.length; i++) {
    final path = real[i];
    final id = songIdFor(stored[i]);
    final fileTitle = fileNameOf(path).replaceAll(RegExp(r'\.[^.]+$'), '');
    String? title, artist, album, cover;
    var durationMs = 0;
    var genres = <String>[];
    try {
      final m = readMetadata(File(path), getImage: true);
      title = m.title;
      artist = m.artist ?? m.albumArtist;
      album = m.album;
      durationMs = m.duration?.inMilliseconds ?? 0;
      genres = m.genres;
      if (m.pictures.isNotEmpty) {
        final pic = m.pictures.firstWhere(
            (p) => p.pictureType == PictureType.coverFront,
            orElse: () => m.pictures.first);
        final ext = pic.mimetype.contains('png') ? 'png' : 'jpg';
        File('$base/covers/$id.$ext').writeAsBytesSync(pic.bytes);
        cover = 'app:covers/$id.$ext';
      }
      final lyr = m.lyrics?.trim();
      if (lyr != null && lyr.isNotEmpty) {
        File('$base/lyrics/$id.emb').writeAsStringSync(lyr);
      }
    } catch (_) {
      // Archivo sin etiquetas o formato raro: se usa el nombre del archivo.
    }
    if ((title == null || title.trim().isEmpty) || (artist == null || artist.trim().isEmpty)) {
      // "Artista - Título.mp3"
      final parts = fileTitle.split(' - ');
      if (parts.length >= 2) {
        artist = (artist == null || artist.trim().isEmpty) ? parts.first.trim() : artist;
        title = (title == null || title.trim().isEmpty) ? parts.sublist(1).join(' - ').trim() : title;
      }
    }
    out.add({
      'id': id,
      'path': stored[i],
      'title': (title == null || title.trim().isEmpty) ? fileTitle : title.trim(),
      'artist': (artist == null || artist.trim().isEmpty) ? 'Artista desconocido' : artist.trim(),
      'album': (album == null || album.trim().isEmpty) ? 'Sin álbum' : album.trim(),
      'durationMs': durationMs,
      'cover': cover,
      'genres': genres,
    });
  }
  return out;
}
