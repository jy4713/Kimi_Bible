import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_strings.dart';
import '../providers/settings_provider.dart';
import 'bible/bible_screen.dart';
import 'bible/compare_screen.dart';
import 'commentary/commentary_screen.dart';
import 'hymn/hymn_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  DateTime? _lastBackPress;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _commentaryKey = GlobalKey<CommentaryScreenState>();
  final _compareKey = GlobalKey<CompareScreenState>();

  static const _icons = [
    Icons.menu_book_outlined,
    Icons.compare_arrows,
    Icons.music_note_outlined,
    Icons.record_voice_over_outlined,
    Icons.comment_outlined,
  ];
  static const _selectedIcons = [
    Icons.menu_book,
    Icons.compare_arrows,
    Icons.music_note,
    Icons.record_voice_over,
    Icons.comment,
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const BibleScreen(),
      CompareScreen(key: _compareKey),
      // Hymnal picker (dropdown); both kinds are separate, like Bible vs hymnal.
      const HymnListScreen(),
      const HymnListScreen(readingMode: true),
      CommentaryScreen(key: _commentaryKey),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = AppStrings(settings.appLanguage);
    final labels = [
      strings.bible,
      strings.compareTab,
      strings.hymns,
      strings.responsiveReading,
      strings.commentary
    ];

    return PopScope(
      // 첫 번째 뒤로가기는 토스트로 안내하고, 2초 안에 두 번째 누르면 앱을 종료한다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Close any menu opened inside a tab (settings, search, ...) first.
        final nav = _navigatorKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
          return;
        }
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.pressBackAgainToExit),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        // Tabs live in a nested Navigator so pushed menus (settings, search)
        // slide over the tab content while the bottom navigation bar stays
        // visible; tapping a tab pops the menu and switches at the same time.
        body: Navigator(
          key: _navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => IndexedStack(
              index: _index,
              children: _screens,
            ),
            settings: const RouteSettings(name: '/'),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 62,
          labelTextStyle: WidgetStateProperty.all(
            TextStyle(fontSize: 12 * settings.uiScale),
          ),
          selectedIndex: _index,
          onDestinationSelected: (i) {
            // Close any open menu, then switch to the tapped tab.
            _navigatorKey.currentState?.popUntil((r) => r.isFirst);
            setState(() => _index = i);
            if (i == 1) {
              // Compare tab: follow the Bible reader's current location.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _compareKey.currentState?.syncFromBible();
              });
            } else if (i == 4) {
              // Commentary tab: jump to the exact verse being read.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _commentaryKey.currentState?.openCurrentBibleLocation();
              });
            }
          },
          destinations: [
            for (int i = 0; i < labels.length; i++)
              NavigationDestination(
                icon: Icon(_icons[i], size: 22),
                selectedIcon: Icon(_selectedIcons[i], size: 22),
                label: labels[i],
              ),
          ],
        ),
      ),
    );
  }
}
