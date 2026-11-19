import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_state.dart';
import 'models.dart';

class LyricLine {
  const LyricLine(this.time, this.text);
  final Duration? time; // null = letra sin tiempos
  final String text;
}

class Lyrics {
  const Lyrics(this.lines, this.source);
  final List<LyricLine> lines;

  /// 'archivo' (.lrc junto a la canción), 'embebida' o 'internet'.
  final String source;
  bool get synced => lines.isNotEmpty && lines.first.time != null;

  /// Índice de la línea que suena en [pos] (-1 antes de la primera).
  int indexAt(Duration pos) {
    if (!synced) return -1;
    var lo = 0, hi = lines.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].time! <= pos) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}

final _stamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

/// Lee texto LRC. Si no tiene tiempos, devuelve la letra simple.
Lyrics? parseLyrics(String raw, String source) {
  final timed = <LyricLine>[];
  final plain = <LyricLine>[];
  for (var line in const LineSplitter().convert(raw)) {
    line = line.trim();
    if (line.isEmpty) continue;
    final stamps = <Duration>[];
    var rest = line;
    while (true) {
      final m = _stamp.matchAsPrefix(rest);
      if (m == null) break;
      final frac = m.group(3) ?? '0';
      final ms = switch (frac.length) {
        1 => int.parse(frac) * 100,
        2 => int.parse(frac) * 10,
        _ => int.parse(frac),
      };
      stamps.add(Duration(
          minutes: int.parse(m.group(1)!), seconds: int.parse(m.group(2)!), milliseconds: ms));
      rest = rest.substring(m.end).trimLeft();
    }
    if (stamps.isNotEmpty) {
      for (final t in stamps) {
        timed.add(LyricLine(t, rest));
      }
    } else if (!RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(line)) {
      plain.add(LyricLine(null, line));
    }
  }
  if (timed.isNotEmpty) {
    timed.sort((a, b) => a.time!.compareTo(b.time!));
    // Las líneas vacías con tiempo marcan pausas instrumentales.
    return Lyrics(timed.map((l) => LyricLine(l.time, l.text.isEmpty ? '♪' : l.text)).toList(), source);
  }
  if (plain.isNotEmpty) return Lyrics(plain, source);
  return null;
}

class LyricsService {
  static String _dir() => '${store.baseDir}/lyrics';

  /// Busca la letra en este orden: archivo .lrc junto a la canción, caché,
  /// letra embebida con tiempos, internet (LRCLIB) y, al final, cualquier
  /// letra sin tiempos que se haya encontrado.
  static Future<Lyrics?> find(Song s) async {
    // 1. Archivo .lrc al lado de la canción.
    try {
      final real = store.resolve(s.path);
      final lrc = File(real.replaceAll(RegExp(r'\.[^./\\]+$'), '.lrc'));
      if (await lrc.exists()) {
        final l = parseLyrics(await lrc.readAsString(), 'archivo');
        if (l != null) return l;
      }
    } catch (_) {}

    // 2. Caché de internet con tiempos.
    final cached = File('${_dir()}/${s.id}.lrc');
    if (await cached.exists()) {
      final l = parseLyrics(await cached.readAsString(), 'internet');
      if (l != null) return l;
    }

    // 3. Letra embebida en el archivo de música.
    Lyrics? fallback;
    final emb = File('${_dir()}/${s.id}.emb');
    if (await emb.exists()) {
      final l = parseLyrics(await emb.readAsString(), 'embebida');
      if (l != null && l.synced) return l;
      fallback = l;
    }

    // 4. Letra simple de internet ya guardada.
    final plainCache = File('${_dir()}/${s.id}.txt');
    if (await plainCache.exists()) {
      final l = parseLyrics(await plainCache.readAsString(), 'internet');
      return fallback ?? l;
    }

    // 5. Internet. Si ya se buscó hace poco y no había nada, no se repite.
    if (store.onlineLyrics) {
      final none = File('${_dir()}/${s.id}.none');
      final recentMiss = await none.exists() &&
          DateTime.now().difference(await none.lastModified()) < const Duration(days: 3);
      if (!recentMiss) {
        try {
          final r = await _fetchLrclib(s);
          if (r != null) {
            if (r.$1 != null) {
              await cached.writeAsString(r.$1!);
              final l = parseLyrics(r.$1!, 'internet');
              if (l != null) return l;
            }
            if (r.$2 != null) {
              await plainCache.writeAsString(r.$2!);
              return fallback ?? parseLyrics(r.$2!, 'internet');
            }
          } else {
            await none.writeAsString('');
          }
        } catch (e) {
          debugPrint('Letra en internet falló: $e'); // sin conexión: se intentará luego
        }
      }
    }
    return fallback;
  }

  static String _cleanTitle(String t) => t
      .replaceAll(RegExp(r'[\(\[][^\)\]]*(official|oficial|video|audio|lyric|letra|visualizer|hd|4k)[^\)\]]*[\)\]]',
          caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Devuelve (letra con tiempos, letra simple) o null si no hay nada.
  static Future<(String?, String?)?> _fetchLrclib(Song s) async {
    final title = _cleanTitle(s.title);
    final hasArtist = s.artist != 'Artista desconocido';
    final queries = <Map<String, String>>[
      if (hasArtist) {'track_name': title, 'artist_name': s.artist},
      {'q': hasArtist ? '${s.artist} $title' : title},
    ];
    for (final q in queries) {
      final res = await http
          .get(Uri.https('lrclib.net', '/api/search', q), headers: {'User-Agent': 'KennyMusic/1.0'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) continue;
      final list = (jsonDecode(utf8.decode(res.bodyBytes)) as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) continue;
      final dur = s.durationMs / 1000.0;
      double diff(Map<String, dynamic> m) =>
          dur <= 0 ? 0 : (((m['duration'] as num?)?.toDouble() ?? 0) - dur).abs();
      final ok = list.where((m) => dur <= 0 || diff(m) <= 8).toList()
        ..sort((a, b) {
          final sa = a['syncedLyrics'] != null ? 0 : 1;
          final sb = b['syncedLyrics'] != null ? 0 : 1;
          if (sa != sb) return sa - sb;
          return diff(a).compareTo(diff(b));
        });
      if (ok.isEmpty) continue;
      final best = ok.first;
      final synced = best['syncedLyrics'] as String?;
      final plain = best['plainLyrics'] as String?;
      if ((synced ?? '').trim().isNotEmpty || (plain ?? '').trim().isNotEmpty) {
        return ((synced ?? '').trim().isEmpty ? null : synced, (plain ?? '').trim().isEmpty ? null : plain);
      }
    }
    return null;
  }

  /// Borra todas las letras descargadas (no las embebidas).
  static Future<void> clearDownloaded() async {
    final d = Directory(_dir());
    if (!await d.exists()) return;
    await for (final f in d.list()) {
      if (f is File && !f.path.endsWith('.emb')) await f.delete();
    }
  }
}

/// La letra de la canción que está sonando.
class NowLyrics extends ChangeNotifier {
  String? songId;
  Lyrics? lyrics;
  bool loading = false;
  StreamSubscription? _sub;

  void follow(Stream<dynamic> mediaItems) {
    _sub?.cancel();
    _sub = mediaItems.listen((_) => refresh());
  }

  Future<void> refresh({bool force = false}) async {
    final s = audio.current;
    if (s == null) {
      songId = null;
      lyrics = null;
      loading = false;
      notifyListeners();
      return;
    }
    if (!force && s.id == songId) return;
    songId = s.id;
    lyrics = null;
    loading = true;
    notifyListeners();
    final l = await LyricsService.find(s);
    if (songId != s.id) return; // cambió de canción mientras buscaba
    lyrics = l;
    loading = false;
    notifyListeners();
  }
}
