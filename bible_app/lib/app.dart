import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/app_strings.dart';
import 'constants/app_theme.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

class BibleApp extends StatelessWidget {
  const BibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final uiScale = settings.uiScale.clamp(0.9, 1.1);

    return MaterialApp(
      title: AppStrings(settings.appLanguage).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(uiScale: uiScale),
      darkTheme: AppTheme.dark(uiScale: uiScale),
      themeMode: settings.themeMode,
      home: const HomeScreen(),
    );
  }
}
