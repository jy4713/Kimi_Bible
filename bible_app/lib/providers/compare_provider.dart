import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/source_info.dart';
import '../models/verse.dart';
import '../repositories/bible_repository.dart';

/// State for the verse-by-verse translation comparison tab.
/// Keeps its own book/chapter so the user can browse freely; the screen syncs
/// the location from [BibleProvider] whenever the tab is opened.
class CompareProvider with ChangeNotifier {
  static const _kIds = 'compareBibleIds';
  static const _kAxis = 'bibleCompareAxis';
  static const maxCompareCount = 4;

  List<String> _selectedIds = [];
  Axis _axis = Axis.horizontal; // horizontal = side-by-side columns

  int _book = 1;
  int _chapter = 1;

  final Map<String, List<Verse>> _verses = {};
  String _loadedSignature = '';
  bool _loading = false;
  String? _error;

  List<String> get selectedIds => _selectedIds;
  Axis get axis => _axis;
  int get book => _book;
  int get chapter => _chapter;
  bool get loading => _loading;
  String? get error => _error;

  List<Verse> versesFor(String id) => _verses[id] ?? [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedIds = prefs.getStringList(_kIds) ?? [];
    final axisIndex = prefs.getInt(_kAxis) ?? _axis.index;
    _axis = Axis.values[axisIndex.clamp(0, Axis.values.length - 1)];
    notifyListeners();
  }

  /// Opens the comparison at the given location (usually the Bible reader's
  /// current book/chapter). No-ops when already there.
  Future<void> syncTo(
      List<SourceInfo> sources, int book, int chapter) async {
    _sanitizeSelection(sources);
    if (_book == book &&
        _chapter == chapter &&
        _loadedSignature == _signature) {
      return;
    }
    _book = book;
    _chapter = chapter;
    await _loadVerses(sources);
  }

  Future<void> navigate(
      List<SourceInfo> sources, int book, int chapter) async {
    _book = book;
    _chapter = chapter;
    await _loadVerses(sources);
  }

  /// Revalidates the selection after the enabled-source list changed.
  Future<void> syncWithSources(List<SourceInfo> sources) async {
    final before = _selectedIds.join('|');
    _sanitizeSelection(sources);
    if (before == _selectedIds.join('|') &&
        _loadedSignature == _signature) {
      return;
    }
    await _loadVerses(sources);
  }

  Future<void> setSelectedIds(
      List<String> ids, List<SourceInfo> sources) async {
    _selectedIds = List.from(ids);
    _sanitizeSelection(sources);
    await _persistSelection();
    await _loadVerses(sources);
  }

  Future<void> setAxis(Axis axis) async {
    _axis = axis;
    await _persistSelection();
    notifyListeners();
  }

  String get _signature => '${_selectedIds.join('|')}@$_book:$_chapter';

  void _sanitizeSelection(List<SourceInfo> sources) {
    final available = sources.map((s) => s.id).toSet();
    var ids = _selectedIds.where(available.contains).toList();
    if (ids.isEmpty && sources.isNotEmpty) {
      // Default: first two enabled Bibles.
      ids = sources.take(2).map((s) => s.id).toList();
    }
    if (ids.length > maxCompareCount) ids = ids.take(maxCompareCount).toList();
    _selectedIds = ids;
  }

  Future<void> _loadVerses(List<SourceInfo> sources) async {
    _sanitizeSelection(sources);
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _verses.clear();
      for (final id in _selectedIds) {
        final src = sources.firstWhere((s) => s.id == id);
        _verses[id] =
            await BibleRepository.instance.getChapter(src, _book, _chapter);
      }
      _loadedSignature = _signature;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _persistSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kIds, _selectedIds);
    await prefs.setInt(_kAxis, _axis.index);
  }
}
