import 'database_helper.dart';

/// Looks up Strong's dictionary entries (Hebrew `H####` / Greek `G####`)
/// from the bundled `.dct` lexicons.
///
/// - `HebGrkKo.dct` — Korean definitions
/// - `HebGrkEn.dct` — English definitions
///
/// Each row: Lexicon(id, scode, dtext) where scode is e.g. 'G1' / 'H7225'
/// and dtext is an HTML fragment.
class DictionaryRepository {
  DictionaryRepository._();
  static final DictionaryRepository instance = DictionaryRepository._();

  static const _koAsset = 'assets/dic/HebGrkKo.dct';
  static const _enAsset = 'assets/dic/HebGrkEn.dct';

  /// Returns the definition HTML for [code] (e.g. 'H7225'), or null when the
  /// code is not found. Pass [korean] false for the English lexicon.
  Future<String?> lookup(String code, {bool korean = true}) async {
    final db = await DatabaseHelper.instance
        .openAsset(korean ? _koAsset : _enAsset);
    final rows = await db.query(
      'Lexicon',
      where: 'scode = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['dtext'] as String?;
  }
}
