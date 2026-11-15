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
    final uiScale = settings.uiScale.clamp(0.7, 1.3);

    // 사용자가 지정한 읽기 화면 바탕 색이 있으면 두 테마 모두에 적용한다.
    var theme = AppTheme.light(uiScale: uiScale);
    var darkTheme = AppTheme.dark(uiScale: uiScale);
    if (settings.customBgColor != null) {
      theme = theme.copyWith(scaffoldBackgroundColor: settings.customBgColor);
      darkTheme =
          darkTheme.copyWith(scaffoldBackgroundColor: settings.customBgColor);
    }

    return MaterialApp(
      title: AppStrings(settings.appLanguage).appTitle,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: settings.themeMode,
      home: const HomeScreen(),
    );
  }
}
