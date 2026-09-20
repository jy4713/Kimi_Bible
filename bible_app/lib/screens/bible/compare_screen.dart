import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../constants/book_names.dart';
import '../../models/source_info.dart';
import '../../providers/bible_provider.dart';
import '../../providers/compare_provider.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/bible_repository.dart';
import '_book_selector_dialog.dart';
import '_translation_selector.dart';
import '../../widgets/settings_action_button.dart';

/// Verse-by-verse translation comparison tab.
///
/// ONE scrollable list is used: each verse is a single row containing every
/// selected translation, so matching verses are aligned by construction and
/// scrolling is perfectly smooth — no cross-panel scroll synchronization.
///
/// - Axis.horizontal (좌우): verse number gutter + one text column per
///   translation, side by side. Row height follows the tallest translation,
///   so verse tops always line up.
/// - Axis.vertical (상하): verse number gutter + the translations stacked
///   inside the row, each prefixed with a colored [역본명] label.
///
/// No separator lines between verses, as requested.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => CompareScreenState();
}

class CompareScreenState extends State<CompareScreen> {
  String _sourceSignature = '';
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _verseKeys = <int, GlobalKey>{};
  int? _pendingVerse;

  /// Called by HomeScreen whenever the Compare tab is selected, so the
  /// comparison opens at the book/chapter/verse the Bible reader is showing.
  void syncFromBible() async {
    if (!mounted) return;
    final bible = context.read<BibleProvider>();
    final sources = context.read<SettingsProvider>().enabledBibles;
    final cmp = context.read<CompareProvider>();
    final v = bible.visibleVerse;
    await cmp.syncTo(sources, bible.book, bible.chapter);
    if (!mounted) return;
    _scrollToVerse(cmp, v);
  }

  /// Jump the list so verse [v] sits at the top. Runs post-frame (with
  /// estimates + ensureVisible) so it works right after a rebuild/navigate.
  void _scrollToVerse(CompareProvider cmp, int v) {
    _pendingVerse = v;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || _pendingVerse != v) return;
      final estH = (cmp.axis == Axis.horizontal ? 110.0 : 150.0);
      if (_scroll.hasClients) {
        final target = ((v - 1) * estH)
            .clamp(0.0, _scroll.position.maxScrollExtent);
        _scroll.jumpTo(target);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || _pendingVerse != v) return;
      final ctx = _verseKeys[v]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx,
            alignment: 0.0, duration: const Duration(milliseconds: 200));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncSources(initial: true));
  }

  void _syncSources({bool initial = false}) {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    final signature = settings.enabledBibles.map((s) => s.id).join('|');
    if (initial || signature != _sourceSignature) {
      _sourceSignature = signature;
      context.read<CompareProvider>().syncWithSources(settings.enabledBibles);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context, listen: true);
    final signature = settings.enabledBibles.map((s) => s.id).join('|');
    if (signature != _sourceSignature) {
      _sourceSignature = signature;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _syncSources());
    }
  }

  void _prevChapter(CompareProvider cmp, List<SourceInfo> sources) {
    _pendingVerse = null;
    _verseKeys.clear();
    if (cmp.chapter > 1) {
      cmp.navigate(sources, cmp.book, cmp.chapter - 1);
    } else if (cmp.book > 1) {
      final info = bookInfoOf(cmp.book - 1);
      cmp.navigate(sources, info.number, info.chapters);
    }
  }

  void _nextChapter(CompareProvider cmp, List<SourceInfo> sources) {
    _pendingVerse = null;
    _verseKeys.clear();
    final info = bookInfoOf(cmp.book);
    if (cmp.chapter < info.chapters) {
      cmp.navigate(sources, cmp.book, cmp.chapter + 1);
    } else if (cmp.book < 66) {
      cmp.navigate(sources, cmp.book + 1, 1);
    }
  }

  Future<void> _selectBook(
      CompareProvider cmp, List<SourceInfo> sources) async {
    // Verse counts come from the first currently-selected translation.
    SourceInfo? src;
    for (final id in cmp.selectedIds) {
      if (sources.any((s) => s.id == id)) {
        src = sources.firstWhere((s) => s.id == id);
        break;
      }
    }
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => BookSelectorDialog(
        currentBook: cmp.book,
        currentChapter: cmp.chapter,
        currentVerse: _pendingVerse ?? 1,
        verseCountProvider: src == null
            ? null
            : (b, c) => BibleRepository.instance.maxVerse(src!, b, c),
      ),
    );
    if (result != null && mounted) {
      final book = result['book']!;
      final chapter = result['chapter']!;
      final verse = result['verse'];
      if (book == cmp.book && chapter == cmp.chapter) {
        // Same chapter: just scroll to the chosen verse.
        if (verse != null) _scrollToVerse(cmp, verse);
        return;
      }
      _verseKeys.clear();
      if (verse != null) {
        // Keep the pending-verse scroll target across the rebuild.
        _scrollToVerse(cmp, verse);
      } else {
        _pendingVerse = null;
      }
      cmp.navigate(sources, book, chapter);
    }
  }

  Future<void> _selectTranslations(
      CompareProvider cmp, List<SourceInfo> sources) async {
    final strings = AppStrings(context.read<SettingsProvider>().appLanguage);
    final ids = await showCompareTranslationPicker(
      context,
      allSources: sources,
      selectedIds: cmp.selectedIds,
      strings: strings,
      // Live-apply (debounced in the sheet) — no Apply button.
      onSelectionChanged: (newIds) => cmp.setSelectedIds(newIds, sources),
    );
    if (ids != null && mounted) {
      await cmp.setSelectedIds(ids, sources);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cmp = context.watch<CompareProvider>();
    final sources = settings.enabledBibles;
    final strings = AppStrings(settings.appLanguage);
    final bookInfo = bookInfoOf(cmp.book);

    final selectedSources = <SourceInfo>[
      for (final id in cmp.selectedIds)
        if (sources.any((s) => s.id == id)) sources.firstWhere((s) => s.id == id),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: TextButton(
                onPressed:
                    sources.isEmpty ? null : () => _selectBook(cmp, sources),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(
                  '${strings.bookLabel(korean: bookInfo.korean, english: bookInfo.english)}  ${strings.chapterLabel(cmp.chapter)}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: strings.previousChapter,
              onPressed: () => _prevChapter(cmp, sources),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: strings.nextChapter,
              onPressed: () => _nextChapter(cmp, sources),
            ),
          ],
        ),
        actions: [
          // Layout toggle: side-by-side <-> stacked-per-verse
          IconButton(
            icon: Icon(cmp.axis == Axis.horizontal
                ? Icons.view_column_outlined
                : Icons.view_agenda_outlined),
            tooltip: strings.layoutTooltip,
            onPressed: () => cmp.setAxis(cmp.axis == Axis.horizontal
                ? Axis.vertical
                : Axis.horizontal),
          ),
          // Translation multi-select
          IconButton(
            icon: const Icon(Icons.library_add_check_outlined),
            tooltip: strings.compareTranslationSelection,
            onPressed: () => _selectTranslations(cmp, sources),
          ),
          const SettingsActionButton(),
        ],
      ),
      body: sources.isEmpty
          ? Center(child: Text(strings.noData))
          : cmp.loading
              ? const Center(child: CircularProgressIndicator())
              : cmp.error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          strings.errorLabel(cmp.error!),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    )
                  : _CompareVerseList(
                      // Keyed by chapter so a chapter change always
                      // starts at the top of the list.
                      key: ValueKey('${cmp.book}:${cmp.chapter}'),
                      cmp: cmp,
                      sources: selectedSources,
                      fontSize: settings.fontSize,
                      scrollController: _scroll,
                      verseKeys: _verseKeys,
                    ),
    );
  }
}

/// The single scrollable verse list. Each verse is one row containing all
/// translations, so alignment is guaranteed by the layout itself.
class _CompareVerseList extends StatelessWidget {
  final CompareProvider cmp;
  final List<SourceInfo> sources;
  final double fontSize;
  final ScrollController scrollController;
  final Map<int, GlobalKey> verseKeys;

  const _CompareVerseList({
    super.key,
    required this.cmp,
    required this.sources,
    required this.fontSize,
    required this.scrollController,
    required this.verseKeys,
  });

  // Colored label tints, one per selected translation (cycled).
  static const List<Color> _tints = [
    Color(0xFFE91E63), // pink
    Color(0xFFFF9800), // orange
    Color(0xFF009688), // teal
    Color(0xFF3F51B5), // indigo
  ];

  @override
  Widget build(BuildContext context) {
    // verse number -> text, per translation.
    final maps = <Map<int, String>>[
      for (final s in sources)
        {for (final v in cmp.versesFor(s.id)) v.verse: v.text},
    ];
    final maxVerse = maps.fold<int>(
        0, (m, map) => map.keys.fold(m, (a, k) => k > a ? k : a));

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: maxVerse,
      itemBuilder: (_, i) {
        final verseNumber = i + 1;
        return Padding(
          key: verseKeys[verseNumber] ??= GlobalKey(),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      '$verseNumber',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: fontSize * 0.8,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: cmp.axis == Axis.horizontal
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int t = 0; t < sources.length; t++)
                            Expanded(
                              child: _translationText(
                                context,
                                t,
                                maps[t][verseNumber],
                                left: t > 0,
                              ),
                            ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int t = 0; t < sources.length; t++)
                            _translationText(
                              context,
                              t,
                              maps[t][verseNumber],
                              top: t > 0,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _translationText(
      BuildContext context, int index, String? text,
      {bool left = false, bool top = false}) {
    final color = _tints[index % _tints.length];
    final label = sources[index].name;
    final bodyStyle = TextStyle(fontSize: fontSize, height: 1.6);

    Widget content = text == null
        ? const SizedBox.shrink()
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '[$label] ',
                  style: TextStyle(
                    fontSize: fontSize * 0.85,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                TextSpan(text: text, style: bodyStyle),
              ],
            ),
          );

    if (left) {
      content = Padding(
        padding: const EdgeInsets.only(left: 8),
        child: content,
      );
    } else if (top) {
      content = Padding(
        padding: const EdgeInsets.only(top: 6),
        child: content,
      );
    }
    return content;
  }
}
