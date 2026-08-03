import 'package:flutter/material.dart';

/// Central theme for stiko, built around a warm sticky-note palette.
class StikoTheme {
  const StikoTheme._();

  /// Warm amber seed color that anchors the whole app.
  static const Color seed = Color(0xFFF6BE00);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
      ),
    );
  }
}

/// Pastel colors used by individual sticky-note todo cards.
class StickyColors {
  const StickyColors._();

  static const List<Color> palette = <Color>[
    Color(0xFFFFF3B0), // yellow
    Color(0xFFFFD6A5), // peach
    Color(0xFFCAFFBF), // mint
    Color(0xFF9BF6FF), // sky
    Color(0xFFBDB2FF), // lavender
    Color(0xFFFFC6FF), // pink
  ];

  /// Returns a stable palette color for the given [index].
  static Color at(int index) => palette[index % palette.length];
}
