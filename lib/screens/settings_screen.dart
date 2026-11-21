import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../app_state.dart';
import '../lyrics.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'explore_tab.dart';
import 'home_shell.dart';
import 'song_list_screen.dart';

const _bgStyles = [
  ('blur', 'Portada difuminada'),
  ('grad', 'Degradado'),
  ('solid', 'Color sólido'),
];

// =====================================================================
// Pestaña "Más": menú con secciones
// =====================================================================

class MoreMenu extends StatelessWidget {
  const MoreMenu({super.key, required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    final groups =
        <(String, List<(IconData, Color, String, String, VoidCallback)>)>[
          (
            'AJUSTES',
            [
              (
                Icons.palette_rounded,
                const Color(0xFF7C3AED),
                'Apariencia',
                'Fondos, desenfoque, degradado y color',
                () => open(const AppearanceScreen()),
              ),
              (
                Icons.play_circle_fill_rounded,
                const Color(0xFFEA580C),
                'Reproducción',
                'Crossfade, estilo del reproductor y barra',
                () => open(const PlaybackScreen()),
              ),
              (
                Icons.download_rounded,
                const Color(0xFF0EA5E9),
                'Importar canciones',
                'Buscar en el celular o elegir archivos',
                () => open(const ImportScreen()),
              ),
            ],
          ),
          (
            'HERRAMIENTAS',
            [
              if (audio.hasEqualizer)
                (
                  Icons.equalizer_rounded,
                  const Color(0xFF16A34A),
                  'Ecualizador',
                  'Graves, voces y agudos',
                  () => open(const EqualizerScreen()),
                ),
              (
                Icons.bedtime_rounded,
                const Color(0xFF4F46E5),
                'Temporizador',
                'Apagar la música después de un rato',
                () => open(const SleepScreen()),
              ),
              (
                Icons.bar_chart_rounded,
                const Color(0xFFDB2777),
                'Tus estadísticas',
                'Lo que más escuchas',
                () => open(const StatsScreen()),
              ),
              (
                Icons.history_rounded,
                const Color(0xFF0D9488),
                'Historial',
                'Lo último que escuchaste',
                () => openList(
                  context,
                  'Historial',
                  () => store.recentSongs,
                  subtitle: 'Las últimas 30 canciones que escuchaste',
                ),
              ),
              (
                Icons.search_rounded,
                const Color(0xFF0891B2),
                'Buscar',
                'Canción, artista o álbum',
                onSearch,
              ),
              (
                Icons.people_alt_rounded,
                const Color(0xFF9333EA),
                'Artistas',
                'Tu música por artista',
                () => open(
                  const Scaffold(
                    body: ExploreTab(initialMode: 0, title: 'Artistas'),
                  ),
                ),
              ),
            ],
          ),
          (
            'DATOS',
            [
              (
                Icons.save_rounded,
                const Color(0xFF64748B),
                'Copia de seguridad',
                'Guardar o recuperar playlists y favoritas',
                () => open(const BackupScreen()),
              ),
              (
                Icons.lyrics_rounded,
                const Color(0xFFCA8A04),
                'Letras',
                'Buscar en internet y borrar descargadas',
                () => open(const LyricsSettingsScreen()),
              ),
              (
                Icons.info_rounded,
                const Color(0xFF3F3F46),
                'Acerca de',
                'Kenny Music 2.2.0',
                () => showAboutDialog(
                  context: context,
                  applicationName: 'Kenny Music',
                  applicationVersion: '2.2.0',
                  applicationLegalese: 'Hecho por LA DATA',
                ),
              ),
            ],
          ),
        ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, kTabBottomSpace),
        children: [
          const Text(
            'Más',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          for (final (title, items) in groups) ...[
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: kMuted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xCC17171B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 62, color: kSurface2),
                    ListTile(
                      onTap: items[i].$5,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0x1FFFFFFF), // neutro, sin colores
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(items[i].$1, color: Colors.white, size: 20),
                      ),
                      title: Text(
                        items[i].$3,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        items[i].$4,
                        style: const TextStyle(color: kMuted, fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: kMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Página de ajustes con título y contenido desplazable.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: children,
        ),
      ),
    );
  }
}

// =====================================================================
// Secciones
// =====================================================================

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const _Page(title: 'Apariencia', children: [ThemePicker()]);
}

class PlaybackScreen extends StatelessWidget {
  const PlaybackScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Page(
    title: 'Reproducción',
    children: [PlayerStylePicker(withCrossfade: true)],
  );
}

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Importar canciones',
      children: [
        ListenableBuilder(
          listenable: store,
          builder: (context, _) => Text(
            '${store.songs.length} canciones en la biblioteca',
            style: const TextStyle(color: kMuted),
          ),
        ),
        const SizedBox(height: 12),
        const ScanBanner(),
        const SizedBox(height: 8),
        const AddMusicButtons(),
        const SizedBox(height: 16),
        Text(
          Platform.isAndroid
              ? '"Buscar música en el celular" revisa todas las carpetas y agrega lo nuevo. "Importar archivos" copia las canciones que elijas dentro de la app.'
              : 'Elige canciones desde la app Archivos (mp3, m4a, flac, wav). Se copian dentro de Kenny Music.',
          style: const TextStyle(color: kMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class LyricsSettingsScreen extends StatelessWidget {
  const LyricsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Letras',
      children: [
        Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Buscar letras en internet'),
                subtitle: const Text(
                  'Si la canción no trae letra, se busca en LRCLIB',
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
                value: store.onlineLyrics,
                onChanged: store.setOnlineLyrics,
              ),
              const Divider(height: 1, color: kSurface2),
              ListTile(
                title: const Text('Borrar letras descargadas'),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: kMuted,
                ),
                onTap: () async {
                  await LyricsService.clearDownloaded();
                  nowLyrics.refresh(force: true);
                  if (context.mounted)
                    toast(context, 'Letras descargadas borradas');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ecualizador de 5 bandas (solo Android; iPhone no lo permite a las apps).
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  late final Future<AndroidEqualizerParameters?> _params = audio.eqParameters();

  static const _presets = <String, List<double>>{
    'Normal': [0, 0, 0, 0, 0],
    'Más graves': [6, 4, 0, 0, 0],
    'Voces': [-2, 0, 4, 3, 0],
    'Agudos': [0, 0, 0, 3, 6],
    'Fiesta': [5, 2, -1, 2, 5],
  };

  String _hz(double f) => f >= 1000
      ? '${(f / 1000).toStringAsFixed(f >= 10000 ? 0 : 1)} kHz'
      : '${f.round()} Hz';

  void _set(int band, double db) {
    store.setEqGain(band, db);
    audio.applyEqualizer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ecualizador')),
      body: FutureBuilder<AndroidEqualizerParameters?>(
        future: _params,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data;
          if (p == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Pon una canción y vuelve a abrir el ecualizador: el celular lo activa cuando hay música cargada.',
                style: TextStyle(color: kMuted),
              ),
            );
          }
          return ListenableBuilder(
            listenable: store,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in _presets.entries)
                      ActionChip(
                        label: Text(e.key),
                        onPressed: () {
                          for (var b = 0; b < e.value.length; b++) {
                            store.setEqGain(b, e.value[b]);
                          }
                          audio.applyEqualizer();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                for (var b = 0; b < p.bands.length; b++) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _hz(p.bands[b].centerFrequency),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${(b < store.eqGains.length ? store.eqGains[b] : 0).toStringAsFixed(1)} dB',
                        style: TextStyle(
                          color: accentOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: (b < store.eqGains.length ? store.eqGains[b] : 0.0)
                        .clamp(p.minDecibels, p.maxDecibels)
                        .toDouble(),
                    min: p.minDecibels,
                    max: p.maxDecibels,
                    onChanged: (v) => store.setEqGain(b, v),
                    onChangeEnd: (v) => _set(b, v),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const options = <(String, Duration?)>[
      ('15 minutos', Duration(minutes: 15)),
      ('30 minutos', Duration(minutes: 30)),
      ('45 minutos', Duration(minutes: 45)),
      ('1 hora', Duration(hours: 1)),
      ('Al terminar esta canción', Duration.zero),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Temporizador')),
      body: ValueListenableBuilder(
        valueListenable: audio.changes,
        builder: (context, _, _) {
          final active = audio.sleepAt != null || audio.sleepEndOfSong;
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  !active
                      ? 'La música se pausará sola después del tiempo que elijas.'
                      : audio.sleepEndOfSong
                      ? 'Se pausará al terminar esta canción.'
                      : 'Se pausará a las ${TimeOfDay.fromDateTime(audio.sleepAt!).format(context)}.',
                  style: const TextStyle(color: kMuted),
                ),
              ),
              for (final (label, d) in options)
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: Text(label),
                  onTap: () {
                    audio.setSleep(d);
                    toast(context, 'Temporizador: $label');
                  },
                ),
              if (active)
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('Apagar temporizador'),
                  onTap: () => audio.setSleep(null),
                ),
            ],
          );
        },
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final top = store.mostPlayed.take(10).toList();
    final byArtist = <String, int>{};
    for (final s in store.songs.values) {
      byArtist[s.artist] = (byArtist[s.artist] ?? 0) + (store.plays[s.id] ?? 0);
    }
    final artists = byArtist.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    Widget stat(String v, String l) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              v,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            Text(l, style: const TextStyle(color: kMuted, fontSize: 12)),
          ],
        ),
      ),
    );
    return _Page(
      title: 'Tus estadísticas',
      children: [
        Row(
          children: [
            stat('${store.listenMinutes}', 'minutos en total'),
            const SizedBox(width: 10),
            stat('${store.weekMinutes}', 'minutos esta semana'),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Canciones que más escuchas',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (top.isEmpty)
          const Text(
            'Todavía no hay datos. Escucha música y vuelve.',
            style: TextStyle(color: kMuted),
          ),
        for (var i = 0; i < top.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CoverArt(song: top[i], size: 44),
            title: Text(
              top[i].title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              top[i].artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              '${store.plays[top[i].id]} veces',
              style: const TextStyle(color: kMuted),
            ),
            onTap: () => audio.playSongs(top, start: i),
          ),
        const SizedBox(height: 22),
        const Text(
          'Artistas que más escuchas',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final e in artists.take(5))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
            title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(
              '${e.value} veces',
              style: const TextStyle(color: kMuted),
            ),
          ),
      ],
    );
  }
}

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Copia de seguridad',
      children: [
        const Text(
          'Guarda tus playlists, favoritas y estadísticas en un archivo. Si reinstalas la app, lo recuperas desde aquí. Las canciones en sí no se guardan: solo la lista de cuáles eran.',
          style: TextStyle(color: kMuted),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final name =
                'KennyMusic-copia-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
            try {
              final uri = await FilePicker.saveFile(
                dialogTitle: 'Guardar copia de seguridad',
                fileName: name,
                bytes: Uint8List.fromList(utf8.encode(store.exportBackup())),
                mimeType: 'application/json',
              );
              if (context.mounted && uri != null)
                toast(context, 'Copia guardada');
            } catch (_) {
              if (context.mounted)
                toast(context, 'No se pudo guardar la copia');
            }
          },
          icon: const Icon(Icons.save_alt_rounded, color: Colors.black),
          label: const Text(
            'Guardar copia',
            style: TextStyle(color: Colors.black),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              final files = await FilePicker.pickFiles(type: FileType.any);
              if (files.isEmpty) return;
              final text = utf8.decode(await files.first.readAsBytes());
              final n = store.importBackup(text);
              if (context.mounted)
                toast(context, 'Copia recuperada ($n playlists)');
            } catch (_) {
              if (context.mounted)
                toast(context, 'Ese archivo no es una copia de Kenny Music');
            }
          },
          icon: const Icon(Icons.restore_rounded),
          label: const Text('Recuperar copia'),
        ),
      ],
    );
  }
}

// =====================================================================
// Piezas reutilizables
// =====================================================================

/// Estilo del reproductor, barra de progreso y (opcional) crossfade.
class PlayerStylePicker extends StatelessWidget {
  const PlayerStylePicker({super.key, this.withCrossfade = false});
  final bool withCrossfade;

  static const layouts = [
    ('classic', 'Clásico'),
    ('full', 'Portada completa'),
    ('visual', 'Visualizador'),
    ('minimal', 'Mínimo'),
    ('lyrics', 'Letra integrada'),
    ('poster', 'Póster'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final accent = accentOf(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Estilo del reproductor'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (id, label) in layouts)
                  ChoiceChip(
                    label: Text(label),
                    selected: store.playerLayout == id,
                    showCheckmark: false,
                    onSelected: (_) => store.setPlayerLayout(id),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const _Label('Barra de progreso'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (id, label) in const [
                  ('thin', 'Fina con punto'),
                  ('capsule', 'Cápsula que crece'),
                  ('wave', 'Onda'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: store.progressStyle == id,
                    showCheckmark: false,
                    onSelected: (_) => store.setProgressStyle(id),
                  ),
              ],
            ),
            if (withCrossfade) ...[
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(child: _Label('Crossfade entre canciones')),
                  Text(
                    store.crossfade == 0 ? 'Apagado' : '${store.crossfade} s',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: store.crossfade.toDouble(),
                min: 0,
                max: 12,
                divisions: 12,
                onChanged: (v) => store.setCrossfade(v.round()),
              ),
              const SizedBox(height: 8),
              const Text(
                'La canción que termina baja de volumen mientras la siguiente empieza. 0 = sin crossfade.',
                style: TextStyle(color: kMuted, fontSize: 13),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Regulador de 0 a 100 % con su nombre y valor.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.left,
    required this.right,
    required this.color,
    required this.onChanged,
  });
  final String label;
  final int value;
  final String left;
  final String right;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$value %',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            onChanged: (v) => onChanged(v.round()),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(left, style: const TextStyle(color: kMuted, fontSize: 11)),
              Text(right, style: const TextStyle(color: kMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Apariencia: fondos, reguladores, estilo del menú principal y color.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final accent = accents[store.accentIndex.clamp(0, accents.length - 1)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('Fondo del reproductor'),
            Row(
              children: [
                for (final (id, label) in _bgStyles) ...[
                  Expanded(
                    child: _StyleCard(
                      id: id,
                      label: label,
                      selected: store.bgStyle == id,
                      ring: accent.color,
                      onTap: () => store.setBgStyle(id),
                    ),
                  ),
                  if (id != 'solid') const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 18),
            _SliderRow(
              label: 'Desenfoque del fondo',
              value: store.blurAmount,
              left: 'Nítido',
              right: 'Muy borroso',
              color: accent.color,
              onChanged: store.setBlurAmount,
            ),
            _SliderRow(
              label: 'Intensidad del degradado',
              value: store.gradIntensity,
              left: 'Suave',
              right: 'Color fuerte',
              color: accent.color,
              onChanged: store.setGradIntensity,
            ),
            const Text(
              'Se aplican al reproductor, a la letra y al fondo del menú principal.',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
            const SizedBox(height: 26),
            const _Label('Fondo del menú principal'),
            Row(
              children: [
                for (final (id, label) in _bgStyles) ...[
                  Expanded(
                    child: _StyleCard(
                      id: id,
                      label: label,
                      selected: store.homeBgStyle == id,
                      ring: accent.color,
                      onTap: () => store.setHomeBgStyle(id),
                    ),
                  ),
                  if (id != 'solid') const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 26),
            const _Label('Estilo del menú principal'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (id, label) in const [
                  ('list', 'Lista'),
                  ('grid', 'Cuadrícula'),
                  ('featured', 'Destacados'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: store.homeLayout == id,
                    showCheckmark: false,
                    onSelected: (_) => store.setHomeLayout(id),
                  ),
              ],
            ),
            const SizedBox(height: 26),
            const _AccentPicker(),
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: kMuted,
      ),
    ),
  );
}

/// Ejemplo de fondo (colores neutros: azul y gris, no naranja).
class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.id,
    required this.label,
    required this.selected,
    required this.ring,
    required this.onTap,
  });
  final String id;
  final String label;
  final bool selected;
  final Color ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Decoration preview = switch (id) {
      'blur' => const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.4),
          radius: 1.1,
          colors: [Color(0xFF6B8CB8), Color(0xFF34486A), Color(0xFF141A26)],
        ),
      ),
      'grad' => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3E5B85), Color(0xFF1C2638), kBg],
        ),
      ),
      _ => const BoxDecoration(color: Color(0xFF1C1C21)),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? ring : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: DecoratedBox(
                  decoration: preview,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF9DB4D6), Color(0xFF4A5F80)],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white54,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? kText : kMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Color de acento: una fila con el color actual; al tocarla se abre la
/// paleta de 18 colores y se cierra sola al elegir uno.
class _AccentPicker extends StatefulWidget {
  const _AccentPicker();

  @override
  State<_AccentPicker> createState() => _AccentPickerState();
}

class _AccentPickerState extends State<_AccentPicker> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final current = accents[store.accentIndex.clamp(0, accents.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: current.color,
                      border: Border.all(
                        color: const Color(0x33FFFFFF),
                        width: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Color de acento',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          current.name,
                          style: const TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final group in const [
                        'Neutros',
                        'Cálidos',
                        'Fríos',
                        'Intensos',
                      ]) ...[
                        Text(
                          group.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: kMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (var i = 0; i < accents.length; i++)
                              if (accents[i].group == group)
                                Semantics(
                                  button: true,
                                  selected: i == store.accentIndex,
                                  label: accents[i].name,
                                  child: GestureDetector(
                                    onTap: () {
                                      store.setAccent(i);
                                      setState(() => _open = false);
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: i == store.accentIndex
                                              ? kText
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: accents[i].color,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      const Text(
                        'Se usa en botones, estrella de favorita y pestaña activa.',
                        style: TextStyle(color: kMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
