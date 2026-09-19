import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../models/note.dart';
import '../../models/verse.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/dictionary_repository.dart';

/// Converts the lexicon's lightweight HTML fragment to readable plain text.
String dictionaryHtmlToPlain(String html) {
  var s = html;
  s = s.replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

/// Shows a bottom-sheet popup with the Strong's definition of [code]
/// (e.g. 'H7225') for [word].
Future<void> showStrongDefinition(
  BuildContext context,
  String word,
  String code,
) async {
  final korean = context.read<SettingsProvider>().appLanguage ==
      AppLanguage.korean;
  final definition =
      await DictionaryRepository.instance.lookup(code, korean: korean);
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final textTheme = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      word,
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    code,
                    style: textTheme.titleSmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: definition == null
                      ? Text(korean ? '사전에서 찾을 수 없습니다' : 'Not found in lexicon')
                      : SelectableText(
                          dictionaryHtmlToPlain(definition),
                          style: const TextStyle(height: 1.5),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A scrollable list of verses for a single translation.
///
/// Shared by the single-reading screen and the comparison panels. Features:
/// - ALL verses are built (not lazily) so every verse carries a live
///   [GlobalKey]; parents can measure any verse position at any time, which
///   is what keeps matching verse tops pixel-aligned across comparison panels
///   even during fast flings (no missing-item corrections, no flicker);
/// - scroll-to-verse / align-verse helpers ([jumpToVerse], [alignVerse]);
/// - first-visible-verse reporting ([firstVisible]);
/// - optional note markers (dashed underline) and verse selection.
class VerseListView extends StatefulWidget {
  final List<Verse> verses;
  final double fontSize;
  final ScrollController? controller;

  /// Verses (sorted) that carry a note; their text is shown with a dashed
  /// underline.
  final List<VerseNote> notes;

  /// Tapping a verse (its number OR its text) reports the verse number.
  /// Selection / note-open logic lives in the parent screen.
  final void Function(int verseNumber)? onVerseTap;

  /// Currently selected verse numbers (selection mode).
  final Set<int> selectedVerses;

  /// Index to scroll to after the widget built (e.g. after a navigation).
  final int scrollToIndex;

  /// Bumps whenever the parent wants the list (re)positioned — e.g. on every
  /// chapter navigation. Unlike [scrollToIndex] alone this also forces a
  /// return to the top when the target index is 0.
  final int scrollEpoch;

  const VerseListView({
    super.key,
    required this.verses,
    required this.fontSize,
    this.controller,
    this.notes = const [],
    this.onVerseTap,
    this.selectedVerses = const {},
    this.scrollToIndex = 0,
    this.scrollEpoch = 0,
  });

  @override
  State<VerseListView> createState() => VerseListViewState();
}

class VerseListViewState extends State<VerseListView> {
  static const _topPadding = 8.0;

  final List<GlobalKey> _itemKeys = [];
  ScrollController? _ownController;
  int _appliedScrollTo = 0;
  int _appliedEpoch = 0;

  ScrollController get controller => widget.controller ?? _ownController!;

  @override
  void initState() {
    super.initState();
    _ownController = widget.controller == null ? ScrollController() : null;
    _syncKeys();
    _appliedScrollTo = widget.scrollToIndex;
    _appliedEpoch = widget.scrollEpoch;
    if (widget.scrollToIndex > 0 || widget.scrollEpoch > 0) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => jumpToVerse(widget.scrollToIndex));
    }
  }

  @override
  void didUpdateWidget(covariant VerseListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verses.length != widget.verses.length) _syncKeys();
    final epochChanged = widget.scrollEpoch != _appliedEpoch;
    if (epochChanged) _appliedEpoch = widget.scrollEpoch;
    if (epochChanged || widget.scrollToIndex != _appliedScrollTo) {
      _appliedScrollTo = widget.scrollToIndex;
      if (widget.scrollToIndex > 0 || epochChanged) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => jumpToVerse(widget.scrollToIndex));
      }
    }
  }

  void _syncKeys() {
    _itemKeys
      ..clear()
      ..addAll(List.generate(widget.verses.length, (_) => GlobalKey()));
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  /// Y position of verse [index] relative to the top of this scroll view's
  /// viewport (includes the list padding). Null only before first layout.
  double? relY(int index) {
    if (index < 0 || index >= _itemKeys.length) return null;
    final ctx = _itemKeys[index].currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null) return null;
    final viewport = scrollable.context.findRenderObject();
    if (viewport == null || !viewport.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: viewport).dy;
  }

  /// The first verse whose top edge is at (or below) the viewport top.
  /// Returns the index plus its current viewport-relative Y so callers can
  /// replicate the exact alignment in other panels.
  ({int index, double relY})? firstVisible() {
    for (int i = 0; i < _itemKeys.length; i++) {
      final y = relY(i);
      if (y != null && y >= -0.5) return (index: i, relY: y);
    }
    return null;
  }

  /// Scrolls so that verse [index] sits at the top of the viewport.
  void jumpToVerse(int index) {
    final y = relY(index);
    final c = controller;
    if (y == null || !c.hasClients) return;
    final target = (c.offset + y - _topPadding)
        .clamp(0.0, c.position.maxScrollExtent);
    c.jumpTo(target);
  }

  /// Scrolls so that verse [index]'s top edge lands at viewport-relative
  /// [targetRelY]. This is what keeps matching verses top-aligned across
  /// comparison panels while scrolling.
  void alignVerse(int index, double targetRelY) {
    final y = relY(index);
    final c = controller;
    if (y == null || !c.hasClients) return;
    final delta = y - targetRelY;
    if (delta.abs() < 0.5) return;
    final target =
        (c.offset + delta).clamp(0.0, c.position.maxScrollExtent);
    c.jumpTo(target);
  }

  VerseNote? _noteFor(int verseNumber) {
    for (final n in widget.notes) {
      if (verseNumber >= n.verseFrom && verseNumber <= n.verseTo) return n;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Every verse is built so each key is always measurable — required for
    // reliable cross-panel scroll alignment.
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(8, _topPadding, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < widget.verses.length; i++)
            _VerseRow(
              key: _itemKeys[i],
              verse: widget.verses[i],
              fontSize: widget.fontSize,
              note: _noteFor(widget.verses[i].verse),
              onVerseTap: widget.onVerseTap,
              selected: widget.selectedVerses.contains(widget.verses[i].verse),
            ),
        ],
      ),
    );
  }
}

class _VerseRow extends StatefulWidget {
  final Verse verse;
  final double fontSize;
  final VerseNote? note;
  final void Function(int verseNumber)? onVerseTap;
  final bool selected;

  const _VerseRow({
    super.key,
    required this.verse,
    required this.fontSize,
    required this.note,
    required this.onVerseTap,
    required this.selected,
  });

  @override
  State<_VerseRow> createState() => _VerseRowState();
}

class _VerseRowState extends State<_VerseRow> {
  /// Gesture recognizers for Strong's-tagged words; must be disposed.
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      height: 1.6,
      decoration: widget.note != null ? TextDecoration.underline : null,
      decorationStyle:
          widget.note != null ? TextDecorationStyle.dashed : null,
      decorationColor: widget.note != null ? colorScheme.primary : null,
      decorationThickness: widget.note != null ? 1.4 : null,
    );

    final verse = widget.verse;
    final hasStrong = verse.hasStrong;

    // For Strong's sources the verse text is rendered as individually
    // tappable words (tap = dictionary popup), so the whole-verse text tap
    // (note selection) is disabled to avoid conflicts; the verse NUMBER
    // still toggles selection.
    final textGesture = (widget.onVerseTap == null || hasStrong)
        ? null
        : () => widget.onVerseTap!(verse.verse);

    Widget textWidget;
    if (hasStrong) {
      _recognizers
        ..forEach((r) => r.dispose())
        ..clear();
      final spans = <InlineSpan>[
        for (final seg in verse.strongSegments()) ...[
          if (seg.strongCode != null)
            TextSpan(
              text: seg.word,
              style: textStyle.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              recognizer: _makeRecognizer(seg.word, seg.strongCode!),
            )
          else
            TextSpan(text: seg.word, style: textStyle),
          const TextSpan(text: ' '),
        ],
      ];
      textWidget = RichText(text: TextSpan(children: spans));
    } else {
      textWidget = Text(verse.text, style: textStyle);
    }

    return Container(
      color: widget.selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap:
                widget.onVerseTap == null ? null : () => widget.onVerseTap!(verse.verse),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Text(
                    '${verse.verse}',
                    style: TextStyle(
                      fontSize: widget.fontSize * 0.8,
                      fontWeight: FontWeight.bold,
                      color: widget.selected
                          ? colorScheme.primary
                          : colorScheme.primary.withValues(alpha: 0.85),
                    ),
                  ),
                  if (widget.note != null)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: textGesture,
              child: textWidget,
            ),
          ),
        ],
      ),
    );
  }

  TapGestureRecognizer _makeRecognizer(String word, String code) {
    final r = TapGestureRecognizer()
      ..onTap = () => showStrongDefinition(context, word, code);
    _recognizers.add(r);
    return r;
  }
}
