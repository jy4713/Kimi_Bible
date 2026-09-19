import 'package:flutter/material.dart';

class AppTheme {
  static const _primarySeed = Color(0xFF1A5276);

  /// [uiScale] scales the whole M3 text theme so menus, titles, buttons and
  /// other chrome follow the user-selected menu font size. Content text
  /// (Bible verses etc.) is sized separately and is not affected.
  static ThemeData light({double uiScale = 1.0}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primarySeed,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    final scaled = _scaledTextTheme(base.textTheme, uiScale);
    return base.copyWith(
        textTheme: scaled, primaryTextTheme: scaled);
  }

  static ThemeData dark({double uiScale = 1.0}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primarySeed,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    final scaled = _scaledTextTheme(base.textTheme, uiScale);
    return base.copyWith(
        textTheme: scaled, primaryTextTheme: scaled);
  }

  static TextTheme _scaledTextTheme(TextTheme base, double scale) {
    double fs(TextStyle? s, double def) => (s?.fontSize ?? def) * scale;
    return TextTheme(
      displayLarge:
          (base.displayLarge ?? const TextStyle()).copyWith(fontSize: fs(base.displayLarge, 57)),
      displayMedium:
          (base.displayMedium ?? const TextStyle()).copyWith(fontSize: fs(base.displayMedium, 45)),
      displaySmall:
          (base.displaySmall ?? const TextStyle()).copyWith(fontSize: fs(base.displaySmall, 36)),
      headlineLarge:
          (base.headlineLarge ?? const TextStyle()).copyWith(fontSize: fs(base.headlineLarge, 32)),
      headlineMedium:
          (base.headlineMedium ?? const TextStyle()).copyWith(fontSize: fs(base.headlineMedium, 28)),
      headlineSmall:
          (base.headlineSmall ?? const TextStyle()).copyWith(fontSize: fs(base.headlineSmall, 24)),
      titleLarge:
          (base.titleLarge ?? const TextStyle()).copyWith(fontSize: fs(base.titleLarge, 22)),
      titleMedium:
          (base.titleMedium ?? const TextStyle()).copyWith(fontSize: fs(base.titleMedium, 16)),
      titleSmall:
          (base.titleSmall ?? const TextStyle()).copyWith(fontSize: fs(base.titleSmall, 14)),
      bodyLarge:
          (base.bodyLarge ?? const TextStyle()).copyWith(fontSize: fs(base.bodyLarge, 16)),
      bodyMedium:
          (base.bodyMedium ?? const TextStyle()).copyWith(fontSize: fs(base.bodyMedium, 14)),
      bodySmall:
          (base.bodySmall ?? const TextStyle()).copyWith(fontSize: fs(base.bodySmall, 12)),
      labelLarge:
          (base.labelLarge ?? const TextStyle()).copyWith(fontSize: fs(base.labelLarge, 14)),
      labelMedium:
          (base.labelMedium ?? const TextStyle()).copyWith(fontSize: fs(base.labelMedium, 12)),
      labelSmall:
          (base.labelSmall ?? const TextStyle()).copyWith(fontSize: fs(base.labelSmall, 11)),
    );
  }
}
