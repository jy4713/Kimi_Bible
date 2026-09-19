class Verse {
  final int id;
  final int book;
  final int chapter;
  final int verse;
  final String text;
  final String translationId;

  /// Original DB text before tag stripping. For Strong's-enabled sources
  /// (.sdb) this keeps the embedded `<WH7225>`-style markers so words can be
  /// tapped for dictionary lookup; empty for plain sources when not provided.
  final String rawText;

  const Verse({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.translationId,
    this.rawText = '',
  });

  static String _stripHtml(String raw) =>
      raw.replaceAll(RegExp(r'<[^>]+>'), '');

  /// Whether this verse carries Strong's number markers.
  bool get hasStrong => rawText.contains('<W');

  /// Matches an embedded Strong's marker, e.g. `<WH7225>` (Hebrew) or
  /// `<WG430>` (Greek); captures the code without the leading `W`.
  static final RegExp _strongRe = RegExp(r'<W([HG]\d+)>');

  /// Splits [rawText] into word segments paired with their Strong's code
  /// (null for trailing punctuation/words without a marker).
  List<WordSegment> strongSegments() {
    final result = <WordSegment>[];
    var index = 0;
    for (final m in _strongRe.allMatches(rawText)) {
      final word = _stripHtml(rawText.substring(index, m.start)).trim();
      if (word.isNotEmpty) result.add(WordSegment(word, m.group(1)));
      index = m.end;
    }
    final rest = _stripHtml(rawText.substring(index)).trim();
    if (rest.isNotEmpty) result.add(WordSegment(rest, null));
    return result;
  }

  factory Verse.fromMap(Map<String, dynamic> map, String translationId) {
    final raw = map['btext'] as String? ?? '';
    return Verse(
      id: map['id'] as int? ?? 0,
      book: map['book'] as int? ?? 0,
      chapter: map['chapter'] as int? ?? 0,
      verse: map['verse'] as int? ?? 0,
      text: _stripHtml(raw),
      translationId: translationId,
      rawText: raw,
    );
  }
}

/// A single word together with its optional Strong's dictionary code.
class WordSegment {
  final String word;
  final String? strongCode; // e.g. 'H7225' (Hebrew) or 'G430' (Greek)
  const WordSegment(this.word, this.strongCode);
}
