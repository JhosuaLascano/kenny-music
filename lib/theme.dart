import 'package:flutter/material.dart';

/// Un color de acento que el usuario puede elegir en Ajustes.
class Accent {
  const Accent(this.name, this.color, this.group);
  final String name;
  final Color color;

  /// Grupo en el selector: Cálidos, Fríos o Intensos.
  final String group;
}

const accents = <Accent>[
  // Los 6 primeros conservan su posición (es el color guardado de cada usuario).
  Accent('Naranja Kenny', Color(0xFFFF8A2B), 'Cálidos'),
  Accent('Violeta', Color(0xFF9B72F2), 'Intensos'),
  Accent('Oro', Color(0xFFF2C64B), 'Cálidos'),
  Accent('Menta', Color(0xFF34D399), 'Fríos'),
  Accent('Azul', Color(0xFF60A5FA), 'Fríos'),
  Accent('Rosa', Color(0xFFF472B6), 'Intensos'),
  Accent('Mandarina', Color(0xFFFF6A1A), 'Cálidos'),
  Accent('Durazno', Color(0xFFFFB37A), 'Cálidos'),
  Accent('Limón', Color(0xFFE9E46A), 'Cálidos'),
  Accent('Coral', Color(0xFFFF7A70), 'Cálidos'),
  Accent('Esmeralda', Color(0xFF10B981), 'Fríos'),
  Accent('Turquesa', Color(0xFF2DD4BF), 'Fríos'),
  Accent('Cielo', Color(0xFF38BDF8), 'Fríos'),
  Accent('Índigo', Color(0xFF818CF8), 'Fríos'),
  Accent('Lila', Color(0xFFC084FC), 'Intensos'),
  Accent('Fucsia', Color(0xFFE879F9), 'Intensos'),
  Accent('Frambuesa', Color(0xFFFB7185), 'Intensos'),
  Accent('Rojo', Color(0xFFF87171), 'Intensos'),
];

const kBg = Color(0xFF0B0B0D);
const kSurface = Color(0xFF17171B);
const kSurface2 = Color(0xFF26262B);
const kText = Color(0xFFF5F5F5);
const kMuted = Color(0xFFA1A1AA);

/// Degradado de la marca (el del ícono).
const kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFAA4D), Color(0xFFFF7A1F)],
);

ThemeData buildTheme(Color accent) {
  final scheme = ColorScheme.dark(
    primary: accent,
    secondary: accent,
    surface: kSurface,
    onPrimary: Colors.black,
    onSurface: kText,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    canvasColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kSurface,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: kSurface),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: kSurface2,
      overlayShape: SliderComponentShape.noOverlay,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.black : kMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : kSurface2,
      ),
    ),
  );
}
