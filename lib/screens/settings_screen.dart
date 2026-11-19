import 'package:flutter/material.dart';

import '../app_state.dart';
import '../lyrics.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _styles = [
    ('blur', 'Portada difuminada'),
    ('grad', 'Degradado'),
    ('solid', 'Color sólido'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final accent = accents[store.accentIndex.clamp(0, accents.length - 1)];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              const _Label('Fondo del reproductor'),
              Row(
                children: [
                  for (final (id, label) in _styles) ...[
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
              const SizedBox(height: 26),
              const _Label('Color de acento'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < accents.length; i++)
                    Semantics(
                      button: true,
                      selected: i == store.accentIndex,
                      label: accents[i].name,
                      child: GestureDetector(
                        onTap: () => store.setAccent(i),
                        child: Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: i == store.accentIndex ? kText : Colors.transparent,
                                width: 3),
                          ),
                          child: DecoratedBox(
                            decoration:
                                BoxDecoration(shape: BoxShape.circle, color: accents[i].color),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${accent.name} · se usa en botones, estrella de favorito y barra activa.',
                  style: const TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(child: _Label('Crossfade entre canciones')),
                  Text(store.crossfade == 0 ? 'Apagado' : '${store.crossfade} s',
                      style: TextStyle(color: accent.color, fontWeight: FontWeight.w700)),
                ],
              ),
              Slider(
                value: store.crossfade.toDouble(),
                min: 0,
                max: 12,
                divisions: 12,
                label: store.crossfade == 0 ? 'Apagado' : '${store.crossfade} s',
                onChanged: (v) => store.setCrossfade(v.round()),
              ),
              const SizedBox(height: 8),
              const Text(
                'La canción que termina baja de volumen mientras la siguiente empieza. 0 = sin crossfade.',
                style: TextStyle(color: kMuted, fontSize: 13),
              ),
              const SizedBox(height: 26),
              Container(
                decoration:
                    BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Buscar letras en internet'),
                      subtitle: const Text('Si la canción no trae letra, se busca en LRCLIB',
                          style: TextStyle(color: kMuted, fontSize: 12)),
                      value: store.onlineLyrics,
                      onChanged: store.setOnlineLyrics,
                    ),
                    const Divider(height: 1, color: kSurface2),
                    ListTile(
                      title: const Text('Borrar letras descargadas'),
                      trailing: const Icon(Icons.chevron_right_rounded, color: kMuted),
                      onTap: () async {
                        await LyricsService.clearDownloaded();
                        nowLyrics.refresh(force: true);
                        if (context.mounted) toast(context, 'Letras descargadas borradas');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const _Label('Música'),
              Text('${store.songs.length} canciones en la biblioteca',
                  style: const TextStyle(color: kMuted)),
              const SizedBox(height: 12),
              const ScanBanner(),
              const SizedBox(height: 8),
              const AddMusicButtons(),
              const SizedBox(height: 40),
              const Center(
                child: Text('Kenny Music 1.0.0', style: TextStyle(color: kMuted, fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kMuted)),
      );
}

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
            colors: [Color(0xFFFF9A3C), Color(0xFFB4441A), Color(0xFF2A1208)],
          ),
        ),
      'grad' => const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB4441A), Color(0xFF3A1A0C), kBg],
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
                border: Border.all(color: selected ? ring : Colors.transparent, width: 2),
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
                          gradient: kBrandGradient,
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
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? kText : kMuted)),
          ],
        ),
      ),
    );
  }
}
