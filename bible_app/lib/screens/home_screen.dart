import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_strings.dart';
import '../providers/settings_provider.dart';
import 'bible/bible_screen.dart';
import 'bible/compare_screen.dart';
import 'commentary/commentary_screen.dart';
import 'hymn/hymn_list_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _commentaryKey = GlobalKey<CommentaryScreenState>();
  final _compareKey = GlobalKey<CompareScreenState>();

  static const _icons = [
    Icons.menu_book_outlined,
    Icons.compare_arrows,
    Icons.music_note_outlined,
    Icons.comment_outlined,
    Icons.settings_outlined,
  ];
  static const _selectedIcons = [
    Icons.menu_book,
    Icons.compare_arrows,
    Icons.music_note,
    Icons.comment,
    Icons.settings,
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const BibleScreen(),
      CompareScreen(key: _compareKey),
      const HymnListScreen(),
      CommentaryScreen(key: _commentaryKey),
      const SettingsScreen(),
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
      strings.commentary,
      strings.settings
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 1) {
            // Compare tab: follow the Bible reader's current location.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _compareKey.currentState?.syncFromBible();
            });
          } else if (i == 3) {
            // Commentary tab: jump to the exact verse being read.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _commentaryKey.currentState?.openCurrentBibleLocation();
            });
          }
        },
        destinations: [
          for (int i = 0; i < labels.length; i++)
            NavigationDestination(
              icon: Icon(_icons[i]),
              selectedIcon: Icon(_selectedIcons[i]),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}
