import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'audio_handler.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  audio = await AudioService.init(
    builder: () => KennyAudioHandler(store),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ladata.kenny_music.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationIcon: 'drawable/ic_stat_kenny',
      notificationColor: Color(0xFFFF8A2B),
    ),
  );
  nowLyrics.follow(audio.mediaItem);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const KennyMusicApp());
}

class KennyMusicApp extends StatelessWidget {
  const KennyMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final accent = accents[store.accentIndex.clamp(0, accents.length - 1)].color;
        return MaterialApp(
          title: 'Kenny Music',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(accent),
          home: const HomeShell(),
        );
      },
    );
  }
}
