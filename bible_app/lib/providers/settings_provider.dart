import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_strings.dart';
import '../models/source_info.dart';

class SettingsProvider with ChangeNotifier {
  static const _kFontSize = 'fontSize';
  static const _kUiFontPct = 'uiFontPct';
  static const _kThemeMode = 'themeMode';
  static const _kLanguage = 'appLanguage';
  static const _kBibles = 'bibles';
  static const _kCommentaries = 'commentaries';
  static const _kHymns = 'hymns';
  static const _defaultCommentaryId = '만나주석';
  static const _defaultHymnId = '새찬송가';
  static const _readingHymnId = '교독문'; // protected like the default hymnal

  double _fontSize = 16.0; // Bible / commentary content text
  double _uiFontPct = 100.0; // menus, titles, buttons (90–110 % of default)
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.korean;
  List<SourceInfo> _bibles = [];
  List<SourceInfo> _commentaries = [];
  List<SourceInfo> _hymns = [];

  double get fontSize => _fontSize;
  double get uiFontPct => _uiFontPct;
  double get uiScale => _uiFontPct / 100.0;
  ThemeMode get themeMode => _themeMode;
  AppLanguage get appLanguage => _language;
  List<SourceInfo> get bibles => _bibles;
  List<SourceInfo> get commentaries => _commentaries;
  List<SourceInfo> get hymns => _hymns;

  List<SourceInfo> get enabledBibles =>
      _bibles.where((s) => s.isEnabled).toList();

  List<SourceInfo> get enabledCommentaries =>
      _commentaries.where((s) => s.isEnabled).toList();

  List<SourceInfo> get enabledHymns =>
      _hymns.where((s) => s.isEnabled).toList();

  /// 찬송가(교독문 제외) 소스 — 관리/선택 단위가 별개다.
  List<SourceInfo> get hymnalSources =>
      _hymns.where((s) => !s.isReading).toList();

  /// 교독문 소스 — 찬송가와 별개로 관리된다.
  List<SourceInfo> get readingSources =>
      _hymns.where((s) => s.isReading).toList();

  bool canRemoveSource(SourceInfo source) {
    return switch (source.type) {
      SourceType.bible => _bibles.length > 1,
      SourceType.commentary => source.id != _defaultCommentaryId,
      SourceType.hymn =>
        source.id != _defaultHymnId && source.id != _readingHymnId,
      SourceType.dictionary => false,
    };
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _fontSize = prefs.getDouble(_kFontSize) ?? 16.0;
    _uiFontPct = prefs.getDouble(_kUiFontPct) ?? 100.0;
    _themeMode = ThemeMode.values[prefs.getInt(_kThemeMode) ?? 0];
    final languageIndex = prefs.getInt(_kLanguage) ?? AppLanguage.korean.index;
    _language = AppLanguage
        .values[languageIndex.clamp(0, AppLanguage.values.length - 1)];

    final biblesJson = prefs.getString(_kBibles);
    if (biblesJson != null && biblesJson.isNotEmpty) {
      _bibles = SourceInfo.decodeList(biblesJson);
      // Prune built-in entries whose asset was removed from the APK (e.g.
      // translations no longer shipped) so stale rows never try to open a
      // missing asset. User-imported copies (docPath) are left untouched.
      final validAssets = kBuiltInBibles.map((s) => s.assetPath).toSet();
      final pruned = _bibles
          .where((s) => !(s.isBuiltIn &&
              s.docPath.isEmpty &&
              !validAssets.contains(s.assetPath)))
          .toList();
      if (pruned.length != _bibles.length) {
        _bibles = pruned;
        await _persist();
      }
      // Merge in built-in translations added since the list was saved, using
      // their default enabled state. Existing entries keep their state.
      final known = _bibles.map((s) => s.id).toSet();
      final added = kBuiltInBibles.where((s) => !known.contains(s.id)).toList();
      if (added.isNotEmpty) {
        _bibles = [..._bibles, ...added.map(_copySource)];
        await _persist();
      }
    } else {
      _bibles = kBuiltInBibles.map(_copySource).toList();
    }
    // A Bible source may be built-in and still removable, but the app must
    // always retain at least one Bible.
    if (_bibles.isEmpty) _bibles = kBuiltInBibles.map(_copySource).toList();

    final commJson = prefs.getString(_kCommentaries);
    if (commJson != null && commJson.isNotEmpty) {
      _commentaries = SourceInfo.decodeList(commJson);
    } else {
      _commentaries = kBuiltInCommentaries.map(_copySource).toList();
    }

    final hymnsJson = prefs.getString(_kHymns);
    if (hymnsJson != null && hymnsJson.isNotEmpty) {
      _hymns = SourceInfo.decodeList(hymnsJson);
      // Merge in built-in hymnals added since the list was saved.
      final knownHymns = _hymns.map((s) => s.id).toSet();
      final newHymns =
          kBuiltInHymns.where((s) => !knownHymns.contains(s.id)).toList();
      if (newHymns.isNotEmpty) {
        _hymns = [..._hymns, ...newHymns.map(_copySource)];
        await _persist();
      }
    } else {
      _hymns = kBuiltInHymns.map(_copySource).toList();
    }
    // Entries saved before the hymn/교독문 split lack the isReading flag.
    for (final s in _hymns) {
      if (s.id == _readingHymnId) s.isReading = true;
    }

    _ensureProtectedDefaults();
    notifyListeners();
  }

  SourceInfo _copySource(SourceInfo source) => SourceInfo(
        id: source.id,
        name: source.name,
        type: source.type,
        assetPath: source.assetPath,
        companionAssetPath: source.companionAssetPath,
        docPath: source.docPath,
        companionPath: source.companionPath,
        isEnabled: source.isEnabled,
        isBuiltIn: source.isBuiltIn,
        isReading: source.isReading,
      );

  void _ensureProtectedDefaults() {
    if (_commentaries.every((s) => s.id != _defaultCommentaryId)) {
      final builtIn = kBuiltInCommentaries.firstWhere(
        (s) => s.id == _defaultCommentaryId,
        orElse: () => kBuiltInCommentaries.first,
      );
      _commentaries.insert(0, _copySource(builtIn));
    }
    if (_hymns.every((s) => s.id != _defaultHymnId)) {
      final builtIn = kBuiltInHymns.firstWhere(
        (s) => s.id == _defaultHymnId,
        orElse: () => kBuiltInHymns.first,
      );
      _hymns.insert(0, _copySource(builtIn));
    }
    // 교독문 is also protected: restore it if a previous build let the user
    // delete it.
    if (_hymns.every((s) => s.id != _readingHymnId)) {
      final builtIn = kBuiltInHymns.where((s) => s.id == _readingHymnId);
      if (builtIn.isNotEmpty) _hymns.add(_copySource(builtIn.first));
    }
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(10.0, 32.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, _fontSize);
  }

  Future<void> setUiFontSize(double pct) async {
    _uiFontPct = pct.clamp(90.0, 110.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kUiFontPct, _uiFontPct);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, mode.index);
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLanguage, language.index);
  }

  Future<bool> toggleSource(SourceInfo source, bool enabled) async {
    if (!enabled) {
      // The last ENABLED source of its category cannot be switched off. For
      // hymnals the categories are separate: at least one 찬송가 AND at least
      // one 교독문 must stay enabled.
      final enabledCount = switch (source.type) {
        SourceType.bible => _bibles.where((s) => s.isEnabled).length,
        SourceType.commentary =>
          _commentaries.where((s) => s.isEnabled).length,
        SourceType.hymn => _hymns
            .where((s) => s.isEnabled && s.isReading == source.isReading)
            .length,
        SourceType.dictionary => 0,
      };
      if (enabledCount <= 1) return false;
    }

    source.isEnabled = enabled;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> addSource(SourceInfo source) async {
    switch (source.type) {
      case SourceType.bible:
        if (!_bibles.any((s) => s.id == source.id)) {
          _bibles.add(source);
        }
        break;
      case SourceType.commentary:
        if (!_commentaries.any((s) => s.id == source.id)) {
          _commentaries.add(source);
        }
        break;
      case SourceType.hymn:
        if (!_hymns.any((s) => s.id == source.id)) {
          _hymns.add(source);
        }
        break;
      case SourceType.dictionary:
        break;
    }
    notifyListeners();
    await _persist();
  }

  Future<bool> removeSource(SourceInfo source) async {
    switch (source.type) {
      case SourceType.bible:
        // Built-in Bibles are removable, but at least one Bible must remain.
        if (_bibles.length <= 1) return false;
        _bibles.removeWhere((s) => s.id == source.id);
        break;
      case SourceType.commentary:
        if (source.id == _defaultCommentaryId) return false;
        _commentaries.removeWhere((s) => s.id == source.id);
        break;
      case SourceType.hymn:
        if (source.id == _defaultHymnId || source.id == _readingHymnId) {
          return false;
        }
        _hymns.removeWhere((s) => s.id == source.id);
        break;
      case SourceType.dictionary:
        return false;
    }
    _ensureProtectedDefaults();
    notifyListeners();
    await _persist();
    // Delete only the app's internal copies (in the documents directory).
    // The original file the user imported from is never touched, so it can
    // be re-imported later. Built-in sources have no docPath — nothing to do.
    if (!source.isBuiltIn) {
      try {
        if (source.docPath.isNotEmpty) {
          final f = File(source.docPath);
          if (f.existsSync()) await f.delete();
        }
        if (source.companionPath.isNotEmpty) {
          final c = File(source.companionPath);
          if (c.existsSync()) await c.delete();
        }
      } catch (_) {
        // File deletion failure must not block the removal itself.
      }
    }
    return true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBibles, SourceInfo.encodeList(_bibles));
    await prefs.setString(_kCommentaries, SourceInfo.encodeList(_commentaries));
    await prefs.setString(_kHymns, SourceInfo.encodeList(_hymns));
  }
}
