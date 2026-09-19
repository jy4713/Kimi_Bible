import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/note.dart';

/// Read-write SQLite store for user verse notes.
/// Unlike the bundled Bible/commentary DBs this database is writable and is
/// never copied from assets.
class NotesRepository {
  NotesRepository._();
  static final NotesRepository instance = NotesRepository._();

  static const _dbName = 'notes.db';
  Database? _db;

  Future<Database> get db async {
    final current = _db;
    if (current != null && current.isOpen) return current;

    if (kIsWeb) {
      final dbPath = await getDatabasesPath();
      _db = await openDatabase(
        p.join(dbPath, _dbName),
        version: 1,
        onCreate: _onCreate,
      );
    } else {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'bible_db'));
      if (!await dir.exists()) await dir.create(recursive: true);
      _db = await openDatabase(
        p.join(dir.path, _dbName),
        version: 1,
        onCreate: _onCreate,
      );
    }
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_id TEXT NOT NULL,
        book INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse_from INTEGER NOT NULL,
        verse_to INTEGER NOT NULL,
        text TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_notes_loc ON notes(source_id, book, chapter)');
  }

  Future<List<VerseNote>> all() async {
    final d = await db;
    final rows = await d.query('notes', orderBy: 'book, chapter, verse_from');
    return rows.map(_fromRow).toList();
  }

  Future<List<VerseNote>> forChapter(
      String sourceId, int book, int chapter) async {
    final d = await db;
    final rows = await d.query(
      'notes',
      where: 'source_id = ? AND book = ? AND chapter = ?',
      whereArgs: [sourceId, book, chapter],
      orderBy: 'verse_from',
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> upsert(VerseNote note) async {
    final d = await db;
    final values = _toRow(note);
    if (note.id != null) {
      await d.update('notes', values, where: 'id = ?', whereArgs: [note.id]);
      return note.id!;
    }
    return d.insert('notes', values);
  }

  Future<void> delete(int id) async {
    final d = await db;
    await d.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAll(List<VerseNote> notes) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('notes');
      for (final note in notes) {
        await txn.insert('notes', _toRow(note));
      }
    });
  }

  VerseNote _fromRow(Map<String, dynamic> r) => VerseNote(
        id: r['id'] as int?,
        sourceId: r['source_id'] as String? ?? '',
        book: r['book'] as int? ?? 0,
        chapter: r['chapter'] as int? ?? 0,
        verseFrom: r['verse_from'] as int? ?? 0,
        verseTo: r['verse_to'] as int? ?? 0,
        text: r['text'] as String? ?? '',
        updatedAt:
            DateTime.tryParse(r['updated_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> _toRow(VerseNote n) => {
        'source_id': n.sourceId,
        'book': n.book,
        'chapter': n.chapter,
        'verse_from': n.verseFrom,
        'verse_to': n.verseTo,
        'text': n.text,
        'updated_at': n.updatedAt.toIso8601String(),
      };
}
