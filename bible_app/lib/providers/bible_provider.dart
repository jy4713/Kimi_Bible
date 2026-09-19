import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/source_info.dart';
import '../models/verse.dart';
import '../repositories/bible_repository.dart';

/// State for the single-translation Bible reader tab.
/// The verse-by-verse comparison lives in [CompareProvider].
class BibleProvider with ChangeNotifier {
  static const _kBook = 'currentBook';
  static const _kChapter = 'currentChapter';
  static const _kSelectedId = 'selectedBibleId';

  int _book = 1;
  int _chapter = 1;
  int _verseIndex = 0; // scroll-to target when navigating from search/pickers
  int _visibleVerse = 1; // first verse currently visible in the reader
  int _epoch = 0; // bumped on every navigation (scroll reset signal)

  String? _selectedId; // single reading translation

  List<Verse> _verses = [];
  String _loadedSignature = '';
  bool _loading = false;
  String? _error;

  int get book => _book;
  int get chapter => _chapter;
  int get verseIndex => _verseIndex;
  int get visibleVerse => _visibleVerse;
  int get epoch => _epoch;

  String? get selectedId => _selectedId;
  List<Verse> get verses => _verses;
  bool get loading => _loading;
  String? get error => _error;

  int get verseCount => _verses.length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _book = prefs.getInt(_kBook) ?? 1;
    _chapter = prefs.getInt(_kChapter) ?? 1;
    _selectedId = prefs.getString(_kSelectedId);
    notifyListeners();
  }

  /// Call whenever the set of enabled Bibles may have changed so the reader
  /// can prune a removed translation from its selection.
  Future<void> syncWithSources(List<SourceInfo> sources) async {
    _sanitizeSelection(sources);
    if (_loadedSignature == _signature) return;
    await _loadVerses(sources);
  }

  Future<void> navigate(
    List<SourceInfo> sources,
    int book,
    int chapter, {
    int verseIndex = 0,
  }) async {
    _book = book;
    _chapter = chapter;
    _verseIndex = verseIndex;
    _visibleVerse = verseIndex + 1;
    _epoch++;
    await _loadVerses(sources);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBook, book);
    await prefs.setInt(_kChapter, chapter);
  }

  Future<void> setSelectedId(String? id, List<SourceInfo> sources) async {
    if (_selectedId == id) return;
    _selectedId = id;
    _sanitizeSelection(sources);
    final prefs = await SharedPreferences.getInstance();
    if (_selectedId != null) {
      await prefs.setString(_kSelectedId, _selectedId!);
    }
    await _loadVerses(sources);
  }

  /// Updates the first visible verse (used to jump Commentary to the verse
  /// the user is actually looking at). Only notifies when the value changes
  /// so scrolling does not rebuild the whole tree every frame.
  void setVisibleVerse(int verse) {
    if (_visibleVerse == verse || verse < 1) return;
    _visibleVerse = verse;
    notifyListeners();
  }

  String get _signature => '${_selectedId ?? ''}@$_book:$_chapter';

  void _sanitizeSelection(List<SourceInfo> sources) {
    if (sources.isEmpty) {
      _selectedId = null;
      return;
    }
    final available = sources.map((s) => s.id).toSet();
    if (_selectedId == null || !available.contains(_selectedId)) {
      _selectedId = sources.first.id;
    }
  }

  Future<void> _loadVerses(List<SourceInfo> sources) async {
    _sanitizeSelection(sources);
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final id = _selectedId;
      if (id == null) {
        _verses = [];
      } else {
        final src = sources.firstWhere((s) => s.id == id);
        _verses =
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
}
