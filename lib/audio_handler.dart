import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'models.dart';
import 'store.dart';

/// Reproductor con dos "bandejas" para poder hacer crossfade: mientras una
/// canción baja de volumen, la siguiente sube en la otra bandeja.
/// También publica el estado para la notificación y la pantalla de bloqueo.
class KennyAudioHandler extends BaseAudioHandler with SeekHandler {
  KennyAudioHandler(this.store) {
    for (var i = 0; i < 2; i++) {
      _listen(i);
    }
    _initSession();
    // Cuenta los minutos escuchados (para el panel "Tu música").
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (_p.playing) store.addListen(5000);
    });
  }

  final LibraryStore store;
  final List<AudioPlayer> _players = [AudioPlayer(), AudioPlayer()];
  int _cur = 0;
  AudioPlayer get _p => _players[_cur];

  List<Song> _queue = [];
  List<Song> _original = [];
  int _index = -1;
  double _volume = 1.0;
  bool _shuffle = false;
  AudioServiceRepeatMode _repeat = AudioServiceRepeatMode.none;

  Timer? _fadeTimer;
  AudioPlayer? _fadingOut;
  bool _crossfading = false;
  bool _fadeStarting = false;
  int _failStreak = 0;

  /// Cambia cada vez que cambia la cola, el aleatorio, la repetición o el volumen.
  final changes = ValueNotifier<int>(0);

  // ---------- Temporizador de apagado ----------
  Timer? _sleepTimer;
  DateTime? sleepAt;
  bool sleepEndOfSong = false;

  /// [d] null cancela; `Duration.zero` = al terminar la canción.
  void setSleep(Duration? d) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepAt = null;
    sleepEndOfSong = false;
    if (d == Duration.zero) {
      sleepEndOfSong = true;
    } else if (d != null) {
      sleepAt = DateTime.now().add(d);
      _sleepTimer = Timer(d, _sleepNow);
    }
    changes.value++;
  }

  Future<void> _sleepNow() async {
    // Baja el volumen poco a poco antes de pausar.
    for (var i = 10; i >= 0; i--) {
      _p.setVolume(_volume * i / 10);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    await pause();
    _p.setVolume(_volume);
    setSleep(null);
  }

  List<Song> get queueSongs => List.unmodifiable(_queue);
  int get index => _index;
  Song? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;
  bool get shuffleOn => _shuffle;
  AudioServiceRepeatMode get repeatMode => _repeat;
  double get volume => _volume;
  bool get isPlaying => _p.playing;
  Duration get position => _p.position;
  Duration? get duration => _p.duration;

  /// Posición actual cada 200 ms (una sola fuente compartida por toda la app).
  late final Stream<Duration> positionTicks = Stream.periodic(
    const Duration(milliseconds: 200),
    (_) => _p.position,
  ).asBroadcastStream();

  Future<void> _initSession() async {
    final s = await AudioSession.instance;
    await s.configure(const AudioSessionConfiguration.music());
  }

  void _listen(int i) {
    final p = _players[i];
    p.playbackEventStream.listen(
      (_) {
        if (i == _cur) _broadcast();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Error de reproducción: $e');
      },
    );
    p.playingStream.listen((_) {
      if (i == _cur) _broadcast();
    });
    p.durationStream.listen((d) {
      if (i == _cur && d != null) _onDuration(d);
    });
    p.positionStream.listen((pos) {
      if (i == _cur) _checkCrossfade(pos);
    });
    p.processingStateStream.listen((st) {
      if (i == _cur && st == ProcessingState.completed) _onCompleted();
    });
  }

  MediaItem _item(Song s) => MediaItem(
    id: s.id,
    title: s.title,
    artist: s.artist,
    album: s.album,
    duration: s.durationMs > 0 ? Duration(milliseconds: s.durationMs) : null,
    artUri: s.cover != null ? Uri.file(store.resolve(s.cover!)) : null,
  );

  void _publishQueue() {
    queue.add(_queue.map(_item).toList());
    changes.value++;
  }

  void _onDuration(Duration d) {
    final s = current;
    if (s == null) return;
    if (s.durationMs <= 0) {
      store.updateDuration(s.id, d);
      mediaItem.add(_item(s).copyWith(duration: d));
    }
  }

  // ---------- Reproducir ----------

  /// Reproduce una lista de canciones empezando por [start].
  Future<void> playSongs(
    List<Song> songs, {
    int start = 0,
    bool shuffle = false,
  }) async {
    if (songs.isEmpty) return;
    _original = List.of(songs);
    _shuffle = shuffle;
    if (shuffle) {
      final rest = List.of(songs)..removeAt(start);
      rest.shuffle(Random());
      _queue = [songs[start], ...rest];
      start = 0;
    } else {
      _queue = List.of(songs);
    }
    _publishQueue();
    _failStreak = 0;
    await _playIndex(start);
  }

  // Cambios de canción en fila: uno a la vez, y si llegan varios seguidos
  // (tocar "siguiente" muy rápido) solo se hace el último. Antes se abrían
  // varias canciones a la vez y el reproductor podía quedar trabado.
  Future<void> _lock = Future.value();
  int _req = 0;

  Future<void> _playIndex(int i, {bool fade = false}) {
    final my = ++_req;
    final prev = _lock;
    final done = Completer<void>();
    _lock = done.future;
    return prev.then((_) async {
      try {
        if (my != _req) return; // ya llegó un pedido más nuevo
        await _playIndexNow(i, fade: fade).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Cambio de canción falló: $e');
      } finally {
        done.complete();
      }
    });
  }

  Future<void> _playIndexNow(int i, {bool fade = false}) async {
    if (i < 0 || i >= _queue.length) return;
    final song = _queue[i];
    final path = store.resolve(song.path);
    if (!fade) {
      _cancelFade();
      await _players[1 - _cur].stop();
    }
    final target = fade ? _players[1 - _cur] : _p;
    try {
      await target.setFilePath(path);
      _failStreak = 0;
    } catch (e) {
      debugPrint('No se pudo abrir $path: $e');
      _failStreak++;
      _index = i;
      final n = _nextIndex(i);
      if (n != null && _failStreak < _queue.length) {
        return _playIndexNow(n);
      }
      await _p.stop();
      _broadcast();
      return;
    }
    _index = i;
    mediaItem.add(_item(song));
    store.markPlayed(song.id);

    if (fade) {
      final old = _p;
      _cur = 1 - _cur;
      _crossfading = true;
      _fadingOut = old;
      await target.setVolume(0);
      target.play();
      final total = max(1, store.crossfade) * 1000;
      var elapsed = 0;
      const step = 100;
      _fadeTimer = Timer.periodic(const Duration(milliseconds: step), (t) {
        elapsed += step;
        final x = (elapsed / total).clamp(0.0, 1.0);
        target.setVolume(_volume * x);
        old.setVolume(_volume * (1 - x));
        if (x >= 1) _cancelFade();
      });
    } else {
      await target.setVolume(_volume);
      target.play();
    }
    _broadcast();
    changes.value++;
  }

  /// Termina un crossfade en curso: detiene la canción que salía y deja la
  /// actual a volumen normal.
  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    final old = _fadingOut;
    _fadingOut = null;
    if (old != null) {
      old.stop();
      old.setVolume(_volume);
    }
    if (_crossfading) _p.setVolume(_volume);
    _crossfading = false;
  }

  void _checkCrossfade(Duration pos) {
    final secs = store.crossfade;
    if (secs <= 0 ||
        _fadeStarting ||
        _crossfading ||
        !_p.playing ||
        sleepEndOfSong)
      return;
    if (_repeat == AudioServiceRepeatMode.one) return;
    final d = _p.duration;
    if (d == null || d.inSeconds < secs * 2 + 2) return;
    if (d - pos > Duration(seconds: secs)) return;
    final n = _nextIndex(_index);
    if (n == null) return;
    _fadeStarting = true;
    _playIndex(n, fade: true).whenComplete(() => _fadeStarting = false);
  }

  int? _nextIndex(int i) {
    if (_queue.isEmpty) return null;
    if (i + 1 < _queue.length) return i + 1;
    if (_repeat == AudioServiceRepeatMode.all) return 0;
    return null;
  }

  void _onCompleted() {
    if (_crossfading || _fadeStarting) return;
    if (sleepEndOfSong) {
      setSleep(null);
      _p.pause();
      _p.seek(Duration.zero);
      return;
    }
    if (_repeat == AudioServiceRepeatMode.one) {
      _p.seek(Duration.zero);
      _p.play();
      return;
    }
    final n = _nextIndex(_index);
    if (n != null) {
      _playIndex(n);
    } else {
      _p.pause();
      _p.seek(Duration.zero);
    }
  }

  void _broadcast() {
    final p = _p;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (p.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[p.processingState]!,
        playing: p.playing,
        updatePosition: p.position,
        bufferedPosition: p.bufferedPosition,
        speed: p.speed,
        queueIndex: _index < 0 ? null : _index,
        repeatMode: _repeat,
        shuffleMode: _shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  // ---------- Controles (app, notificación y pantalla de bloqueo) ----------

  @override
  Future<void> play() async {
    if (current == null) return;
    if (_p.processingState == ProcessingState.idle) {
      await _playIndex(_index);
      return;
    }
    _p.play();
  }

  @override
  Future<void> pause() async {
    _cancelFade();
    await _p.pause();
  }

  Future<void> togglePlay() => _p.playing ? pause() : play();

  @override
  Future<void> stop() async {
    _cancelFade();
    await _players[0].stop();
    await _players[1].stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    _cancelFade();
    await _p.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    await _playIndex(_nextIndex(_index) ?? 0);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_p.position > const Duration(seconds: 3) ||
        (_index == 0 && _repeat != AudioServiceRepeatMode.all)) {
      await seek(Duration.zero);
      return;
    }
    await _playIndex(_index > 0 ? _index - 1 : _queue.length - 1);
  }

  @override
  Future<void> skipToQueueItem(int index) => _playIndex(index);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeat = repeatMode;
    _broadcast();
    changes.value++;
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final on = shuffleMode != AudioServiceShuffleMode.none;
    if (on == _shuffle) return;
    toggleShuffle();
  }

  void cycleRepeat() {
    setRepeatMode(switch (_repeat) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.none,
    });
  }

  void toggleShuffle() {
    final cur = current;
    _shuffle = !_shuffle;
    if (cur != null) {
      if (_shuffle) {
        _original = List.of(_queue);
        final rest = List.of(_queue)..removeAt(_index);
        rest.shuffle(Random());
        _queue = [cur, ...rest];
        _index = 0;
      } else {
        _queue = List.of(_original);
        _index = max(0, _queue.indexWhere((s) => s.id == cur.id));
      }
      _publishQueue();
    }
    _broadcast();
    changes.value++;
  }

  void playNext(Song s) {
    if (current == null) {
      playSongs([s]);
      return;
    }
    _queue.insert(_index + 1, s);
    _original.add(s);
    _publishQueue();
  }

  void addToQueue(Song s) {
    if (current == null) {
      playSongs([s]);
      return;
    }
    _queue.add(s);
    _original.add(s);
    _publishQueue();
  }

  void removeFromQueue(int i) {
    if (i == _index || i < 0 || i >= _queue.length) return;
    final s = _queue.removeAt(i);
    _original.removeWhere((o) => identical(o, s));
    if (i < _index) _index--;
    _publishQueue();
    _broadcast();
  }

  /// Quita una canción borrada de la biblioteca de la cola.
  void forgetSong(String id) {
    if (current?.id == id) {
      stop();
      _queue = [];
      _original = [];
      _index = -1;
      mediaItem.add(null);
      _publishQueue();
      return;
    }
    for (var i = _queue.length - 1; i >= 0; i--) {
      if (_queue[i].id == id) removeFromQueue(i);
    }
  }

  /// Vuelve a publicar la canción actual (por ejemplo, después de cambiar su imagen).
  void refreshCurrent() {
    final s = current;
    if (s != null) mediaItem.add(_item(s));
    _publishQueue();
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    if (!_crossfading) _p.setVolume(_volume);
    changes.value++;
  }

  @override
  Future<void> onTaskRemoved() async {
    if (!_p.playing) await stop();
  }
}
