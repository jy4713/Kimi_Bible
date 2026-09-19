import 'dart:io';

import 'package:flutter/foundation.dart';

import '../constants/book_names.dart';
import '../models/note.dart';
import '../repositories/notes_repository.dart';

class NotesProvider with ChangeNotifier {
  List<VerseNote> _all = [];

  List<VerseNote> get all => _all;

  Future<void> init() => reload();

  Future<void> reload() async {
    try {
      _all = await NotesRepository.instance.all();
    } catch (_) {
      _all = [];
    }
    notifyListeners();
  }

  /// Notes attached to any verse within [verseFrom]..[verseTo] of the chapter.
  List<VerseNote> forChapter(
      String sourceId, int book, int chapter) {
    return _all
        .where((n) =>
            n.sourceId == sourceId &&
            n.book == book &&
            n.chapter == chapter)
        .toList();
  }

  VerseNote? noteCovering(
      String sourceId, int book, int chapter, int verse) {
    for (final n in _all) {
      if (n.sourceId == sourceId &&
          n.book == book &&
          n.chapter == chapter &&
          verse >= n.verseFrom &&
          verse <= n.verseTo) {
        return n;
      }
    }
    return null;
  }

  Future<void> save({
    int? id,
    required String sourceId,
    required int book,
    required int chapter,
    required int verseFrom,
    required int verseTo,
    required String text,
  }) async {
    final note = VerseNote(
      id: id,
      sourceId: sourceId,
      book: book,
      chapter: chapter,
      verseFrom: verseFrom,
      verseTo: verseTo,
      text: text,
      updatedAt: DateTime.now(),
    );
    await NotesRepository.instance.upsert(note);
    await reload();
  }

  Future<void> remove(int id) async {
    await NotesRepository.instance.delete(id);
    await reload();
  }

  // ── CSV export / import ────────────────────────────────────────────────

  static const csvHeader =
      'source_id,book,book_name,chapter,verse_from,verse_to,text,updated_at';
  static const exportFileName = 'bible_notes.csv';

  String _bookName(int book) {
    try {
      return bookInfoOf(book).korean;
    } catch (_) {
      return '$book';
    }
  }

  /// CSV content of all notes.
  String buildCsv() {
    final buf = StringBuffer()
      ..writeln(csvHeader)
      ..writeAll(_all.map((n) => [
            _csvField(n.sourceId),
            n.book,
            _csvField(_bookName(n.book)),
            n.chapter,
            n.verseFrom,
            n.verseTo,
            _csvField(n.text),
            _csvField(n.updatedAt.toIso8601String()),
          ].join(',')).map((line) => '$line\n'));
    return buf.toString();
  }

  /// Best-effort direct write to the public Downloads folder. Works on
  /// devices/versions that still allow it; returns null when blocked so the
  /// caller can fall back to a folder picker. This is the default
  /// export location.
  Future<String?> tryExportToDownloads() async {
    if (kIsWeb) return null;
    try {
      final file =
          File('/storage/emulated/0/Download/$exportFileName');
      await file.writeAsString(buildCsv(), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Writes the CSV into [directory] (chosen by the user) and returns the
  /// saved file path.
  Future<String> exportCsvTo(String directory) async {
    final path = directory.endsWith('/')
        ? '$directory$exportFileName'
        : '$directory/$exportFileName';
    final file = File(path);
    await file.writeAsString(buildCsv(), flush: true);
    return file.path;
  }

  /// Imports notes from a CSV file (merging with existing notes).
  /// Returns the number of notes imported.
  ///
  /// Columns are matched by header name, so both the current format (with
  /// `book_name`) and older exports (without it) import correctly.
  Future<int> importCsv(String path) async {
    final content = await File(path).readAsString();
    final rows = _parseCsv(content);
    if (rows.isEmpty) return 0;
    final header = rows.first.map((h) => h.trim()).toList();
    int col(String name) => header.indexOf(name);
    final iSource = col('source_id');
    final iBook = col('book');
    final iChapter = col('chapter');
    final iFrom = col('verse_from');
    final iTo = col('verse_to');
    final iText = col('text');
    final iUpdated = col('updated_at');
    if (iSource < 0 || iBook < 0 || iChapter < 0 || iFrom < 0 || iText < 0) {
      return 0;
    }
    String field(List<String> row, int i) =>
        i >= 0 && i < row.length ? row[i] : '';

    final notes = <VerseNote>[];
    for (final row in rows.skip(1)) {
      final book = int.tryParse(field(row, iBook).trim());
      final chapter = int.tryParse(field(row, iChapter).trim());
      final from = int.tryParse(field(row, iFrom).trim());
      final to = int.tryParse(field(row, iTo).trim());
      if (field(row, iSource).isEmpty ||
          book == null ||
          chapter == null ||
          from == null) {
        continue;
      }
      notes.add(VerseNote(
        sourceId: field(row, iSource),
        book: book,
        chapter: chapter,
        verseFrom: from,
        verseTo: to ?? from,
        text: field(row, iText),
        updatedAt:
            DateTime.tryParse(field(row, iUpdated)) ?? DateTime.now(),
      ));
    }
    if (notes.isNotEmpty) {
      final repo = NotesRepository.instance;
      for (final n in notes) {
        await repo.upsert(n);
      }
      await reload();
    }
    return notes.length;
  }

  String _csvField(String s) {
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Minimal RFC-4180 style parser (quoted fields, escaped quotes, CRLF).
  List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    final field = StringBuffer();
    final row = <String>[];
    var inQuotes = false;
    var i = 0;
    while (i < content.length) {
      final ch = content[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        row.add(field.toString());
        field.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++;
        }
        row.add(field.toString());
        field.clear();
        if (row.isNotEmpty && !(row.length == 1 && row.first.isEmpty)) {
          rows.add(List.of(row));
        }
        row.clear();
      } else {
        field.write(ch);
      }
      i++;
    }
    row.add(field.toString());
    if (row.isNotEmpty && !(row.length == 1 && row.first.isEmpty)) {
      rows.add(List.of(row));
    }
    return rows;
  }
}
