import '../models/verse.dart';

/// 선택한 절 번호(정렬됨)를 "1-3, 7" 같은 범위 표기로 만든다.
String verseRangesDesc(List<int> sortedVerses) {
  if (sortedVerses.isEmpty) return '';
  final ranges = <List<int>>[];
  for (final v in sortedVerses) {
    if (ranges.isNotEmpty && ranges.last.last == v - 1) {
      ranges.last.add(v);
    } else {
      ranges.add([v]);
    }
  }
  return ranges
      .map((r) => r.length == 1 ? '${r.first}' : '${r.first}-${r.last}')
      .join(', ');
}

/// 성경 읽기 화면용 복사/공유 텍스트. 선택된 역본의 내용만 포함한다.
///
///   [개역개정] 창세기 1:1-2
///   1 태초에 하나님이 천지를 창조하시니라
///   2 땅이 혼돈하고 공허하며 ...
String buildSingleTranslationCopyText({
  required String sourceName,
  required String bookName,
  required int chapter,
  required List<Verse> verses,
}) {
  final sorted = [...verses]..sort((a, b) => a.verse.compareTo(b.verse));
  final b = StringBuffer(
      '[$sourceName] $bookName $chapter:${verseRangesDesc(sorted.map((v) => v.verse).toList())}');
  for (final v in sorted) {
    b.write('\n${v.verse} ${v.text}');
  }
  return b.toString();
}

/// 역본대조 화면용 복사/공유 텍스트. 절별로 역본 순서대로 모두 포함한다.
///
///   창세기 1:1
///   [개역개정] 태초에 하나님이 천지를 창조하시니라
///   [NIV] In the beginning God created ...
///   창세기 1:2
///   [개역개정] 땅이 혼돈하고 ...
///   [NIV] And the earth was ...
///
/// 특정 역본에 해당 절이 없으면 그 역본 줄은 건다.
String buildCompareCopyText({
  required String bookName,
  required int chapter,
  required List<int> sortedVerseNumbers,
  required List<({String name, Map<int, String> byVerse})> translations,
}) {
  final b = StringBuffer();
  for (final n in sortedVerseNumbers) {
    if (b.isNotEmpty) b.write('\n');
    b.write('$bookName $chapter:$n');
    for (final t in translations) {
      final text = t.byVerse[n];
      if (text == null || text.isEmpty) continue;
      b.write('\n[${t.name}] $text');
    }
  }
  return b.toString();
}
