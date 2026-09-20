import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../models/hymn_entry.dart';
import '../../models/source_info.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/hymn_repository.dart';
import '../../widgets/settings_action_button.dart';
import 'hymn_detail_screen.dart';

class HymnListScreen extends StatefulWidget {
  /// The 교독문 bottom-nav tab sets this: the screen then lists 교독문
  /// sources instead of 찬송가 sources. Both kinds are managed separately
  /// (settings / DB), like Bible vs hymnal.
  final bool readingMode;

  const HymnListScreen({super.key, this.readingMode = false});

  @override
  State<HymnListScreen> createState() => _HymnListScreenState();
}

class _HymnListScreenState extends State<HymnListScreen> {
  List<HymnEntry> _allHymns = [];
  List<HymnEntry> _filtered = [];
  SourceInfo? _source;
  bool _loading = true;
  final _search = TextEditingController();
  String _sourceSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context, listen: true);
    final signature =
        settings.enabledHymns.map((s) => '${s.id}:${s.isEnabled}').join('|');
    if (signature != _sourceSignature) {
      _sourceSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = context.read<SettingsProvider>();
    final all = settings.enabledHymns;
    List<SourceInfo> hymns;
    if (widget.readingMode) {
      hymns = all.where((s) => s.isReading).toList();
      // The 교독문 tab always shows something: fall back to the built-in
      // definition even if the user disabled it in settings.
      hymns = hymns.isEmpty
          ? kBuiltInHymns.where((s) => s.isReading).toList()
          : hymns;
    } else {
      hymns = all.where((s) => !s.isReading).toList();
    }
    if (hymns.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final current = _source;
    if (current == null || !hymns.any((s) => s.id == current.id)) {
      _source = hymns.first;
    }
    try {
      final list = await HymnRepository.instance.getAllHymns(_source!);
      if (mounted) {
        setState(() {
          _allHymns = list;
          _filtered = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    final lq = q.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allHymns
          : _allHymns
              .where((h) =>
                  h.title.toLowerCase().contains(lq) ||
                  h.chapter.toString().contains(lq))
              .toList();
    });
  }

  void _openHymn(int chapter) {
    if (_source == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HymnDetailScreen(
          source: _source!,
          initialChapter: chapter,
          allHymns: _allHymns,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = AppStrings(settings.appLanguage);
    if (settings.enabledHymns.isEmpty) {
      return Center(child: Text(strings.noActiveHymns));
    }
    // 교독문 등 악보(.cmp)가 없는 소스는 목록이 짧고 번호·제목으로 충분해
    // 검색 창을 숨긴다.
    final hasCompanion =
        _source?.effectiveCompanionPath.isNotEmpty ?? false;
    // 같은 종류(찬송가/교독문)가 2개 이상 켜져 있으면 종류 선택 드롭다운 표시.
    final pickerHymns = widget.readingMode
        ? settings.enabledHymns.where((s) => s.isReading).toList()
        : settings.enabledHymns.where((s) => !s.isReading).toList();
    final showPicker = pickerHymns.length > 1;
    return Scaffold(
      appBar: AppBar(
        title: showPicker
            ? DropdownButtonHideUnderline(
                child: DropdownButton<SourceInfo>(
                  value:
                      pickerHymns.any((s) => s.id == _source?.id && s.isEnabled)
                          ? _source
                          : null,
                  items: [
                    for (final s in pickerHymns)
                      DropdownMenuItem(value: s, child: Text(s.name)),
                  ],
                  onChanged: (s) {
                    if (s == null || s.id == _source?.id) return;
                    setState(() {
                      _source = s;
                      _loading = true;
                      _search.clear();
                    });
                    _load();
                  },
                ),
              )
            : Text(widget.readingMode
                ? strings.responsiveReading
                : strings.hymns),
        actions: const [SettingsActionButton()],
        bottom: hasCompanion
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: strings.hymnSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                _filter('');
                              },
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      filled: true,
                    ),
                    onChanged: _filter,
                  ),
                ),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? Center(child: Text(strings.noResults))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    // Slim tiles (~2/3 height); titles ellipsis after 2 lines.
                    childAspectRatio: 2.1,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _HymnCard(
                    hymn: _filtered[i],
                    onTap: () => _openHymn(_filtered[i].chapter),
                  ),
                ),
    );
  }
}

class _HymnCard extends StatelessWidget {
  final HymnEntry hymn;
  final VoidCallback onTap;

  const _HymnCard({required this.hymn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${hymn.chapter}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(
              hymn.plainTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
