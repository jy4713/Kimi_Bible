class VerseNote {
  final int? id;
  final String sourceId; // translation id the note belongs to
  final int book;
  final int chapter;
  final int verseFrom;
  final int verseTo;
  final String text;
  final DateTime updatedAt;

  const VerseNote({
    this.id,
    required this.sourceId,
    required this.book,
    required this.chapter,
    required this.verseFrom,
    required this.verseTo,
    required this.text,
    required this.updatedAt,
  });

  String get reference {
    if (verseFrom == verseTo) return '$book:$chapter:$verseFrom';
    return '$book:$chapter:$verseFrom-$verseTo';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'book': book,
        'chapter': chapter,
        'verseFrom': verseFrom,
        'verseTo': verseTo,
        'text': text,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VerseNote.fromJson(Map<String, dynamic> j) => VerseNote(
        id: j['id'] as int?,
        sourceId: j['sourceId'] as String? ?? '',
        book: j['book'] as int? ?? 0,
        chapter: j['chapter'] as int? ?? 0,
        verseFrom: j['verseFrom'] as int? ?? 0,
        verseTo: j['verseTo'] as int? ?? 0,
        text: j['text'] as String? ?? '',
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
