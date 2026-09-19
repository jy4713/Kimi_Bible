import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/hymn_entry.dart';
import '../models/source_info.dart';
import 'database_helper.dart';

class HymnRepository {
  HymnRepository._();
  static final HymnRepository instance = HymnRepository._();

  // Per-source caches: sourceId → hymnNumber → extracted image bytes.
  final Map<String, Map<int, Uint8List>> _imageCaches = {};
  final Map<String, Archive?> _archives = {};
  final Set<String> _archiveLoaded = {};

  Future<List<HymnEntry>> getAllHymns(SourceInfo source) async {
    final db = source.isBuiltIn
        ? await DatabaseHelper.instance.openAsset(source.assetPath)
        : await DatabaseHelper.instance.openExternal(source.docPath);

    final rows = await db.query('hymnal', orderBy: 'chapter');
    return rows.map((r) => HymnEntry.fromMap(r)).toList();
  }

  Future<HymnEntry?> getHymn(SourceInfo source, int chapter) async {
    final db = source.isBuiltIn
        ? await DatabaseHelper.instance.openAsset(source.assetPath)
        : await DatabaseHelper.instance.openExternal(source.docPath);

    final rows =
        await db.query('hymnal', where: 'chapter = ?', whereArgs: [chapter]);
    if (rows.isEmpty) return null;
    return HymnEntry.fromMap(rows.first);
  }

  Future<List<HymnEntry>> searchHymns(SourceInfo source, String query) async {
    if (query.trim().isEmpty) return getAllHymns(source);
    final db = source.isBuiltIn
        ? await DatabaseHelper.instance.openAsset(source.assetPath)
        : await DatabaseHelper.instance.openExternal(source.docPath);

    final rows = await db.query(
      'hymnal',
      where: 'title LIKE ? OR htext LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'chapter',
    );
    return rows.map((r) => HymnEntry.fromMap(r)).toList();
  }

  /// Returns sheet-music image bytes for a given hymn chapter number.
  /// The .cmp archive is matched by source: built-in 새찬송가 uses its bundled
  /// assets/hymn/새찬송가.cmp, while imported hymnals use the same-named .cmp
  /// copied beside their .hdb (or a previously copied companion path).
  Future<Uint8List?> getHymnImage(SourceInfo source, int chapter) async {
    final cache = _imageCaches.putIfAbsent(source.id, () => {});
    if (cache.containsKey(chapter)) return cache[chapter];

    await _ensureArchive(source);
    final archive = _archives[source.id];
    if (archive == null) return null;

    final file = archive.findFile('p$chapter.png');
    if (file == null) return null;

    final bytes = Uint8List.fromList(file.content as List<int>);
    cache[chapter] = bytes;
    return bytes;
  }

  Future<void> _ensureArchive(SourceInfo source) async {
    if (_archiveLoaded.contains(source.id)) return;
    _archiveLoaded.add(source.id);

    try {
      var cmpPath = source.effectiveCompanionPath;

      // Backward compatibility for hymnals imported before companion paths
      // were persisted: look for a same-named .cmp in the copied DB folder.
      if (cmpPath.isEmpty && source.docPath.isNotEmpty) {
        final docs = await getApplicationDocumentsDirectory();
        final fallback = p.join(
          docs.path,
          'bible_db',
          '${p.basenameWithoutExtension(source.docPath)}.cmp',
        );
        if (File(fallback).existsSync()) cmpPath = fallback;
      }
      if (cmpPath.isEmpty) return;

      final Uint8List bytes;
      if (cmpPath.startsWith('assets/')) {
        final data = await rootBundle.load(cmpPath);
        bytes = data.buffer.asUint8List();
      } else {
        final file = File(cmpPath);
        if (!file.existsSync()) return;
        bytes = await file.readAsBytes();
      }
      _archives[source.id] = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      // If anything fails, leave the archive empty for this hymnal.
      _archives[source.id] = null;
    }
  }
}
