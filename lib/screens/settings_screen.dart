import 'package:flutter/material.dart';

import '../app_state.dart';
import '../lyrics.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false, this.header});

  /// true = se muestra dentro de la pestaña "Más" (sin barra superior).
  final bool embedded;

  /// Contenido extra arriba de los ajustes (accesos de la pestaña "Más").
  final Widget? header;

  static const _styles = [
    ('blur', 'Portada difuminada'),
    ('grad', 'Degradado'),
    ('solid', 'Color sólido'),
  ];

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final accent = accents[store.accentIndex.clamp(0, accents.length - 1)];
        return ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, embedded ? 190 : 40),
          children: [
            ?header,
            const ThemePicker(),
            const SizedBox(height: 26),
            Row(
              children: [
                const Expanded(child: _Label('Crossfade entre canciones')),
                Text(
                  store.crossfade == 0 ? 'Apagado' : '${store.crossfade} s',
                  style: TextStyle(
                    color: accent.color,
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
            const SizedBox(height: 26),
            const _Label('Música'),
            Text(
              '${store.songs.length} canciones en la biblioteca',
              style: const TextStyle(color: kMuted),
            ),
            const SizedBox(height: 12),
            const ScanBanner(),
            const SizedBox(height: 8),
            const AddMusicButtons(),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Kenny Music 1.7.1',
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
    if (embedded) return SafeArea(bottom: false, child: body);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: body,
    );
  }
}

/// Fondo del reproductor y color de acento (en Ajustes y en el menú "…").
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
            const _Label('Estilo del reproductor'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (id, label) in const [
                  ('classic', 'Clásico'),
                  ('full', 'Portada completa'),
                  ('visual', 'Visualizador'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: store.playerLayout == id,
                    showCheckmark: false,
                    onSelected: (_) => store.setPlayerLayout(id),
                  ),
              ],
            ),
            const SizedBox(height: 26),
            const _Label('Fondo del reproductor'),
            Row(
              children: [
                for (final (id, label) in SettingsScreen._styles) ...[
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
                for (final (id, label) in SettingsScreen._styles) ...[
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
            const SizedBox(height: 8),
            Text(
              '${accent.name} · se usa en botones, estrella de favorito y barra activa.',
              style: const TextStyle(color: kMuted, fontSize: 13),
            ),
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
