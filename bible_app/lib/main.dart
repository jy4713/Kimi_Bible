import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/bible_provider.dart';
import 'providers/compare_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/settings_provider.dart';
import 'main_web.dart' if (dart.library.io) 'main_native.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initDatabaseFactory();

  final settings = SettingsProvider();
  await settings.init();

  final bible = BibleProvider();
  await bible.init();

  final compare = CompareProvider();
  await compare.init();

  final notes = NotesProvider();
  await notes.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: bible),
        ChangeNotifierProvider.value(value: compare),
        ChangeNotifierProvider.value(value: notes),
      ],
      child: const BibleApp(),
    ),
  );
}
