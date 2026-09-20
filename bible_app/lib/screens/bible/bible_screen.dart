import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../constants/book_names.dart';
import '../../models/note.dart';
import '../../models/source_info.dart';
import '../../providers/bible_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/bible_repository.dart';
import 'bible_search_screen.dart';
import '_book_selector_dialog.dart';
import '_translation_selector.dart';
import 'verse_list_view.dart';
import '../../widgets/settings_action_button.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  final _listKey = GlobalKey<VerseListViewState>();
  final _scrollController = ScrollController();
  String _sourceSignature = '';

  // Verse selection for notes.
  final Set<int> _selectedVerses = <int>{};
  bool _selectionMode = false;

  // Horizontal-swipe chapter navigation: accumulated drag distances so a
  // deliberate (fairly long, mostly horizontal) swipe flips the chapter,
  // while short/vertical drags are ignored.
  double _swipeDx = 0;
  double _swipeDy = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSources());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context, listen: true);
    final signature = settings.enabledBibles.map((s) => s.id).join('|');
    if (signature != _sourceSignature) {
      _sourceSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncSources());
    }
  }

  void _syncSources() {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    _sourceSignature = settings.enabledBibles.map((s) => s.id).join('|');
    context.read<BibleProvider>().syncWithSources(settings.enabledBibles);
  }

  // ── Navigation helpers ───────────────────────────────────────────────────

  void _prevChapter(BibleProvider bible, List<SourceInfo> sources) {
    _exitSelection();
    if (bible.chapter > 1) {
      bible.navigate(sources, bible.book, bible.chapter - 1);
    } else if (bible.book > 1) {
      final info = bookInfoOf(bible.book - 1);
      bible.navigate(sources, info.number, info.chapters);
    }
  }

  void _nextChapter(BibleProvider bible, List<SourceInfo> sources) {
    _exitSelection();
    final info = bookInfoOf(bible.book);
    if (bible.chapter < info.chapters) {
      bible.navigate(sources, bible.book, bible.chapter + 1);
    } else if (bible.book < 66) {
      bible.navigate(sources, bible.book + 1, 1);
    }
  }

  Future<void> _selectBook(
      BibleProvider bible, List<SourceInfo> sources) async {
    SourceInfo? src;
    if (bible.selectedId != null && sources.any((s) => s.id == bible.selectedId)) {
      src = sources.firstWhere((s) => s.id == bible.selectedId);
    } else if (sources.isNotEmpty) {
      src = sources.first;
    }
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => BookSelectorDialog(
        currentBook: bible.book,
        currentChapter: bible.chapter,
        currentVerse: bible.visibleVerse,
        verseCountProvider: src == null
            ? null
            : (b, c) => BibleRepository.instance.maxVerse(src!, b, c),
      ),
    );
    if (result != null && mounted) {
      _exitSelection();
      bible.navigate(sources, result['book']!, result['chapter']!,
          verseIndex: (result['verse'] ?? 1) - 1);
    }
  }

  Future<void> _selectVerse(
      BibleProvider bible, List<SourceInfo> sources) async {
    final verse = await showDialog<int>(
      context: context,
      builder: (_) => VerseSelectorDialog(
        verseCount: bible.verseCount,
        currentVerse: bible.visibleVerse,
      ),
    );
    if (verse != null && mounted) {
      _exitSelection();
      bible.navigate(sources, bible.book, bible.chapter,
          verseIndex: verse - 1);
    }
  }

  Future<void> _selectTranslation(
      BibleProvider bible, List<SourceInfo> sources) async {
    final current = bible.selectedId;
    if (current == null) return;
    final id = await showTranslationPicker(
      context,
      allSources: sources,
      selectedId: current,
      strings: AppStrings(context.read<SettingsProvider>().appLanguage),
    );
    if (id != null && mounted) {
      _exitSelection();
      await bible.setSelectedId(id, sources);
    }
  }

  // ── Verse selection & notes ──────────────────────────────────────────────

  void _exitSelection() {
    if (_selectionMode || _selectedVerses.isNotEmpty) {
      setState(() {
        _selectionMode = false;
        _selectedVerses.clear();
      });
    }
  }

  /// Tapping a verse (number or text). In selection mode: toggle. Otherwise:
  /// open the note when one exists, else start selection with this verse.
  void _onVerseTap(BibleProvider bible, int verseNumber) {
    if (_selectionMode) {
      setState(() {
        if (_selectedVerses.contains(verseNumber)) {
          _selectedVerses.remove(verseNumber);
        } else {
          _selectedVerses.add(verseNumber);
        }
        if (_selectedVerses.isEmpty) _selectionMode = false;
      });
      return;
    }
    final notes = context.read<NotesProvider>();
    final note = notes.noteCovering(
        bible.selectedId ?? '', bible.book, bible.chapter, verseNumber);
    if (note != null) {
      _showNoteView(note);
      return;
    }
    setState(() {
      _selectionMode = true;
      _selectedVerses.add(verseNumber);
    });
  }

  List<List<int>> _contiguousRanges() {
    final sorted = _selectedVerses.toList()..sort();
    final ranges = <List<int>>[];
    for (final v in sorted) {
      if (ranges.isNotEmpty && ranges.last.last == v - 1) {
        ranges.last.add(v);
      } else {
        ranges.add([v]);
      }
    }
    return ranges;
  }

  Future<void> _addNote(BibleProvider bible) async {
    final strings = AppStrings(context.read<SettingsProvider>().appLanguage);
    final notes = context.read<NotesProvider>();
    final sourceId = bible.selectedId ?? '';
    final ranges = _contiguousRanges();
    if (ranges.isEmpty) return;

    // A single already-existing note covering the whole selection → edit it.
    VerseNote? existing;
    if (ranges.length == 1) {
      existing = notes.noteCovering(
          sourceId, bible.book, bible.chapter, ranges.first.first);
      if (existing != null &&
          !(existing.verseFrom == ranges.first.first &&
              existing.verseTo == ranges.first.last)) {
        existing = null;
      }
    }

    final initial = existing?.text ?? '';
    final controller = TextEditingController(text: initial);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ranges.length == 1
              ? strings.noteForVerses(ranges.first.first, ranges.first.last)
              : strings.noteForMultipleVerses(_selectedVerses.length),
          style: const TextStyle(fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          maxLines: 8,
          minLines: 4,
          autofocus: existing == null,
          decoration: InputDecoration(
            hintText: strings.noteHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.save),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      for (final range in ranges) {
        final single = notes.noteCovering(
            sourceId, bible.book, bible.chapter, range.first);
        final id = (single != null &&
                single.verseFrom == range.first &&
                single.verseTo == range.last)
            ? single.id
            : null;
        await notes.save(
          id: id,
          sourceId: sourceId,
          book: bible.book,
          chapter: bible.chapter,
          verseFrom: range.first,
          verseTo: range.last,
          text: controller.text,
        );
      }
      _exitSelection();
    }
    controller.dispose();
  }

  Future<void> _showNoteView(VerseNote note) async {
    final strings = AppStrings(context.read<SettingsProvider>().appLanguage);
    final notes = context.read<NotesProvider>();
    final edited = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          strings.noteForVerses(note.verseFrom, note.verseTo),
          style: const TextStyle(fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: Text(note.text, style: const TextStyle(height: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(strings.edit),
                onPressed: () => Navigator.pop(ctx, 'edit'),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(strings.delete),
                onPressed: () => Navigator.pop(ctx, 'delete'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(strings.close),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (edited == 'delete' && note.id != null) {
      await notes.remove(note.id!);
    } else if (edited == 'edit') {
      final controller = TextEditingController(text: note.text);
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.noteEdit,
              style: const TextStyle(fontSize: 16)),
          content: TextField(
            controller: controller,
            maxLines: 8,
            minLines: 4,
            decoration:
                const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.save),
            ),
          ],
        ),
      );
      if (saved == true && mounted) {
        await notes.save(
          id: note.id,
          sourceId: note.sourceId,
          book: note.book,
          chapter: note.chapter,
          verseFrom: note.verseFrom,
          verseTo: note.verseTo,
          text: controller.text,
        );
      }
      controller.dispose();
    }
  }

  // ── Scroll tracking ──────────────────────────────────────────────────────

  void _onScroll() {
    if (!mounted) return;
    final bible = context.read<BibleProvider>();
    final first = _listKey.currentState?.firstVisible();
    if (first != null && first.index < bible.verses.length) {
      bible.setVisibleVerse(bible.verses[first.index].verse);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final bible = context.watch<BibleProvider>();
    final notes = context.watch<NotesProvider>();
    final sources = settings.enabledBibles;
    final strings = AppStrings(settings.appLanguage);

    final bookInfo = bookInfoOf(bible.book);
    final fontSize = settings.fontSize;
    final selectedSource = sources.isEmpty
        ? null
        : sources.firstWhere((s) => s.id == bible.selectedId,
            orElse: () => sources.first);

    // Title pieces. The book name is ALWAYS shown Korean / English, and the
    // currently selected translation is shown as well.
    final trName = selectedSource?.name ?? strings.translation;
    final bookKE = '${bookInfo.korean} / ${bookInfo.english}';
    final chLabel = strings.chapterLabel(bible.chapter);
    final vLabel = strings.verseLabel(bible.visibleVerse);

    // Decide single-line vs two-line title by measuring the text.
    final titleStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);
    double measure(String s) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: titleStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width;
    }

    const buttonPad = 12.0; // horizontal padding per _HeaderButton
    const extraW = buttonPad * 4 + 8 * 3 + 96; // paddings + ' · ' + chevrons
    final contentsW = measure(trName) +
        measure(bookKE) +
        measure(chLabel) +
        measure(vLabel);
    final availW = MediaQuery.of(context).size.width - 108; // search action
    final oneLine = contentsW + extraW <= availW;
    final scaler = MediaQuery.textScalerOf(context);
    final lineH = scaler.scale(titleStyle?.fontSize ?? 16) * 1.35;
    final toolbarHeight =
        oneLine ? null : (lineH * 2 + 34).clamp(64.0, 170.0);

    final translationBtn = _HeaderButton(
      label: trName,
      onPressed:
          sources.isEmpty ? null : () => _selectTranslation(bible, sources),
    );
    final bookBtnOneLine = _HeaderButton(
      label: '$bookKE $chLabel',
      onPressed:
          sources.isEmpty ? null : () => _selectBook(bible, sources),
    );
    final bookBtnTwoLine = _HeaderButton(
      label: bookKE,
      onPressed:
          sources.isEmpty ? null : () => _selectBook(bible, sources),
    );
    final chapterBtn = _HeaderButton(
      label: chLabel,
      onPressed:
          sources.isEmpty ? null : () => _selectBook(bible, sources),
    );
    final verseBtn = _HeaderButton(
      label: vLabel,
      onPressed: sources.isEmpty || bible.verseCount == 0
          ? null
          : () => _selectVerse(bible, sources),
    );
    final prevBtn = IconButton(
      icon: const Icon(Icons.chevron_left),
      tooltip: strings.previousChapter,
      onPressed: () => _prevChapter(bible, sources),
    );
    final nextBtn = IconButton(
      icon: const Icon(Icons.chevron_right),
      tooltip: strings.nextChapter,
      onPressed: () => _nextChapter(bible, sources),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: toolbarHeight,
        title: oneLine
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  translationBtn,
                  _HeaderDivider(),
                  bookBtnOneLine,
                  _HeaderDivider(),
                  verseBtn,
                  const SizedBox(width: 2),
                  prevBtn,
                  nextBtn,
                ],
              )
            : Padding(
                // Nudge the two-line title down so the first line is not
                // clipped by the status bar / app bar edge.
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      translationBtn,
                      _HeaderDivider(),
                      bookBtnTwoLine,
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      chapterBtn,
                      _HeaderDivider(),
                      verseBtn,
                      const SizedBox(width: 2),
                      prevBtn,
                      nextBtn,
                    ],
                  ),
                ],
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: strings.bibleSearch,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BibleSearchScreen(
                  sources: sources,
                  currentBook: bible.book,
                  fontSize: fontSize,
                  onNavigate: (book, chapter, verse) {
                    Navigator.pop(context);
                    _exitSelection();
                    bible.navigate(sources, book, chapter,
                        verseIndex: verse - 1);
                  },
                ),
              ),
            ),
          ),
          const SettingsActionButton(),
        ],
      ),
      body: sources.isEmpty
          ? Center(child: Text(strings.noData))
          : bible.loading
              ? const Center(child: CircularProgressIndicator())
              : bible.error != null
                  ? _Error(
                      message: bible.error!, strings: strings)
                  : Column(
                      children: [
                        Expanded(
                          // Deliberate horizontal swipe changes chapter:
                          // left swipe -> next chapter, right swipe -> prev
                          // (with book wrap at both ends). Disabled while the
                          // verse-selection mode is active.
                          child: GestureDetector(
                            onHorizontalDragStart: _selectionMode
                                ? null
                                : (_) {
                                    _swipeDx = 0;
                                    _swipeDy = 0;
                                  },
                            onHorizontalDragUpdate: _selectionMode
                                ? null
                                : (d) {
                                    _swipeDx += d.delta.dx;
                                    _swipeDy += d.delta.dy;
                                  },
                            onHorizontalDragEnd: _selectionMode
                                ? null
                                : (_) {
                                    const minDistance = 90.0;
                                    if (_swipeDx.abs() < minDistance) return;
                                    // Must be clearly horizontal, not a
                                    // slightly-diagonal vertical scroll.
                                    if (_swipeDx.abs() <
                                        _swipeDy.abs() * 1.5) {
                                      return;
                                    }
                                    if (_swipeDx < 0) {
                                      _nextChapter(bible, sources);
                                    } else {
                                      _prevChapter(bible, sources);
                                    }
                                  },
                            child: VerseListView(
                            key: _listKey,
                            verses: bible.verses,
                            fontSize: fontSize,
                            controller: _scrollController,
                            notes: selectedSource == null
                                ? const []
                                : notes.forChapter(selectedSource.id,
                                    bible.book, bible.chapter),
                            onVerseTap: (v) => _onVerseTap(bible, v),
                            selectedVerses: _selectedVerses,
                            scrollToIndex: bible.verseIndex,
                            scrollEpoch: bible.epoch,
                            ),
                          ),
                        ),
                        if (_selectionMode)
                          SafeArea(
                            child: Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      strings
                                          .selectedVersesCount(
                                              _selectedVerses.length),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.note_add_outlined,
                                        size: 18),
                                    label: Text(strings.addNote),
                                    onPressed: () => _addNote(bible),
                                  ),
                                  TextButton(
                                    onPressed: _exitSelection,
                                    child: Text(strings.cancel),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _HeaderButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text('·',
            style: TextStyle(
                color: Theme.of(context).colorScheme.outline, fontSize: 18)),
      );
}

// ── Error widget ───────────────────────────────────────────────────────────

class _Error extends StatelessWidget {
  final String message;
  final AppStrings strings;
  const _Error({required this.message, required this.strings});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            strings.errorLabel(message),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
}
