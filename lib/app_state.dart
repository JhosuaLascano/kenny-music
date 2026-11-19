import 'package:flutter/widgets.dart';

import 'audio_handler.dart';
import 'lyrics.dart';
import 'store.dart';

/// Objetos compartidos por toda la app.
final store = LibraryStore();
late final KennyAudioHandler audio;
final nowLyrics = NowLyrics();

/// Para abrir pantallas desde el reproductor (por ejemplo "Mostrar álbum").
final navKey = GlobalKey<NavigatorState>();
