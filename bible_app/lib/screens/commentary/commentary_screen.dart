import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../constants/book_names.dart';
import '../../models/source_info.dart';
import '../../providers/bible_provider.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/commentary_repository.dart';
import '../../widgets/html_content.dart';
import '../bible/_book_selector_dialog.dart';

class CommentaryScreen extends StatefulWidget {
  const CommentaryScreen({super.key});

  @override
  State<CommentaryScreen> createState() => CommentaryScreenState();
}

class CommentaryScreenState extends State<CommentaryScreen> {
  List<CommentaryEntry> _entries = [];
  final List<GlobalKey> _entryKeys = <GlobalKey>[];
  SourceInfo? _source;
  bool _loading = false;
  bool _initialized = false;
  int? _scrollTargetVerse;

  // After the tab is opened these are independent from the Bible reader so a
  // user can browse another commentary location without moving the Bible.
  int _book = 1;
  int _chapter = 1;

  /// Opens the commentary at the book/chapter/verse currently shown in the
  /// Bible reader. Called by HomeScreen whenever the Commentary tab is
  /// selected, so the commentary follows the exact verse being read.
  void openCurrentBibleLocation() {
    if (!mounted) return;
    final bible = context.read<BibleProvider>();
    final book = bible.book;
    final chapter = bible.chapter;
    final verse = bible.visibleVerse;

    if (!_initialized || _book != book || _chapter != chapter) {
      setState(() {
        _initialized = true;
        _book = book;
        _chapter = chapter;
      });
      _loadCurrent(scrollToVerse: verse);
    } else if (verse != _scrollTargetVerse) {
      _scrollToVerse(verse);
    }
  }

  Future<void> _loadCurrent({int? scrollToVerse}) async {
    final settings = context.read<SettingsProvider>();
    final sources = settings.enabledCommentaries;
    if (sources.isEmpty) return;

    if (_source == null || !sources.any((s) => s.id == _source!.id)) {
      _source = sources.first;
    }

    setState(() => _loading = true);
    try {
      final entries = await CommentaryRepository.instance
          .getChapter(_source!, _book, _chapter);
      if (mounted) {
        setState(() {
          _entries = entries;
          _entryKeys
            ..clear()
            ..addAll(List.generate(entries.length, (_) => GlobalKey()));
        });
      }
      if (scrollToVerse != null && mounted) {
        // Wait one frame so the list has laid out before scrolling.
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToVerse(scrollToVerse));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Scrolls the commentary list to the entry for [verse] (or the first
  /// entry at/after it).
  void _scrollToVerse(int verse) {
    if (!mounted) return;
    _scrollTargetVerse = verse;
    for (int i = 0; i < _entryKeys.length && i < _entries.length; i++) {
      if (_entries[i].verse < verse) continue;
      final ctx = _entryKeys[i].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.0, duration: const Duration(milliseconds: 250));
      }
      return;
    }
  }

  Future<void> _selectBook() async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => BookSelectorDialog(
        currentBook: _book,
        currentChapter: _chapter,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _book = result['book']!;
      _chapter = result['chapter']!;
    });
    _loadCurrent();
  }

  void _switchSource(SourceInfo source) {
    if (_source?.id == source.id) return;
    _source = source;
    _loadCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = AppStrings(settings.appLanguage);
    final sources = settings.enabledCommentaries;
    final fontSize = settings.fontSize;

    if (sources.isEmpty) {
      return Scaffold(
        body: Center(
          child:
              Text(strings.noActiveCommentaries, textAlign: TextAlign.center),
        ),
      );
    }

    if (_source == null || !sources.any((s) => s.id == _source!.id)) {
      _source = sources.first;
    }
    final bookInfo = bookInfoOf(_book);

    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.commentary)),
        body: Center(child: Text(strings.noCommentary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: TextButton(
          onPressed: _selectBook,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(
            '${strings.bookLabel(korean: bookInfo.korean, english: bookInfo.english)}  ${strings.chapterLabel(_chapter)}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          if (sources.length > 1)
            PopupMenuButton<SourceInfo>(
              initialValue: _source,
              onSelected: _switchSource,
              itemBuilder: (_) => sources
                  .map((s) => PopupMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _source?.name ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Text(
                    strings.noCommentary,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                )
              // All entries are built (not lazily) so every entry's key is
              // live when we scroll to the verse being read in the Bible.
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _entries.length; i++)
                        Container(
                          key: i < _entryKeys.length ? _entryKeys[i] : null,
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.verseLabel(_entries[i].verse),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  fontSize: fontSize * 0.9,
                                ),
                              ),
                              const SizedBox(height: 4),
                              HtmlContent(
                                  html: _entries[i].html,
                                  fontSize: fontSize * 0.9),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
