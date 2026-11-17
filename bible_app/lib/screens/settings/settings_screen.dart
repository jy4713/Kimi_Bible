import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../constants/app_strings.dart';
import '../../constants/build_info.dart';
import '../../models/source_info.dart';
import '../../providers/bible_provider.dart';
import '../../providers/compare_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = AppStrings(settings.appLanguage);

    return ListView(
      children: [
        // ── 보기 / 언어 ───────────────────────────────────────────────────
        _SectionHeader(strings.appearance),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(strings.menuFontSize,
                  style: Theme.of(context).textTheme.titleMedium),
              Expanded(
                child: Slider(
                  value: settings.uiFontPct,
                  min: 70,
                  max: 130,
                  divisions: 60,
                  label: '${settings.uiFontPct.round()}%',
                  onChanged: settings.setUiFontSize,
                ),
              ),
              _SliderValueBox(
                label: '${settings.uiFontPct.round()}%',
                value: settings.uiFontPct,
                min: 70,
                max: 130,
                width: 58,
                onChanged: settings.setUiFontSize,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              strings.menuFontHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(strings.fontSize,
                  style: Theme.of(context).textTheme.titleMedium),
              Expanded(
                child: Slider(
                  value: settings.fontSize,
                  min: 10,
                  max: 32,
                  divisions: 22,
                  label: '${settings.fontSize.round()}',
                  onChanged: settings.setFontSize,
                ),
              ),
              _SliderValueBox(
                label: '${settings.fontSize.round()}',
                value: settings.fontSize,
                min: 10,
                max: 32,
                width: 46,
                onChanged: settings.setFontSize,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              strings.fontPreview,
              style:
                  TextStyle(fontSize: settings.fontSize, height: settings.lineHeight),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(strings.lineSpacingLabel,
                  style: Theme.of(context).textTheme.titleMedium),
              Expanded(
                child: Slider(
                  value: settings.lineSpacingPct,
                  min: 50,
                  max: 150,
                  divisions: 100,
                  label: '${settings.lineSpacingPct.round()}%',
                  onChanged: settings.setLineSpacingPct,
                ),
              ),
              _SliderValueBox(
                label: '${settings.lineSpacingPct.round()}%',
                value: settings.lineSpacingPct,
                min: 50,
                max: 150,
                width: 58,
                onChanged: settings.setLineSpacingPct,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(strings.verseSpacingLabel,
                  style: Theme.of(context).textTheme.titleMedium),
              Expanded(
                child: Slider(
                  value: settings.verseSpacingPct,
                  min: 50,
                  max: 150,
                  divisions: 100,
                  label: '${settings.verseSpacingPct.round()}%',
                  onChanged: settings.setVerseSpacingPct,
                ),
              ),
              _SliderValueBox(
                label: '${settings.verseSpacingPct.round()}%',
                value: settings.verseSpacingPct,
                min: 50,
                max: 150,
                width: 58,
                onChanged: settings.setVerseSpacingPct,
              ),
            ],
          ),
        ),
        _SectionHeader(strings.language),
        RadioGroup<AppLanguage>(
          groupValue: settings.appLanguage,
          onChanged: (v) {
            if (v != null) settings.setLanguage(v);
          },
          child: Column(
            children: [
              RadioListTile<AppLanguage>(
                title: Text(strings.koreanLanguage),
                value: AppLanguage.korean,
              ),
              RadioListTile<AppLanguage>(
                title: Text(strings.englishLanguage),
                value: AppLanguage.english,
              ),
            ],
          ),
        ),

        // ── 테마 ─────────────────────────────────────────────────────────
        const Divider(),
        _SectionHeader(strings.theme),
        RadioGroup<ThemeMode>(
          groupValue: settings.themeMode,
          onChanged: (v) {
            if (v != null) settings.setThemeMode(v);
          },
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                title: Text(strings.systemTheme),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text(strings.lightTheme),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text(strings.darkTheme),
                value: ThemeMode.dark,
              ),
            ],
          ),
        ),

        // ── 화면 ─────────────────────────────────────────────────────────
        const Divider(),
        _SectionHeader(strings.display),
        SwitchListTile(
          secondary: const Icon(Icons.lightbulb_outline),
          title: Text(strings.keepScreenOn),
          subtitle: Text(strings.keepScreenOnHint),
          value: settings.keepScreenOn,
          onChanged: (v) async {
            await settings.setKeepScreenOn(v);
            // 즉시 적용: ON이면 앱 사용 중 화면이 꺼지지 않는다.
            await WakelockPlus.toggle(enable: v);
          },
        ),

        // ── 색상 ─────────────────────────────────────────────────────────
        const Divider(),
        _SectionHeader(strings.colorsSection),
        _ColorRow(
          label: strings.fontColorLabel,
          color: settings.customTextColor,
          onTap: () => _pickColor(context, settings, isText: true),
          onDefault: () => settings.setCustomTextColor(null),
        ),
        _ColorRow(
          label: strings.bgColorLabel,
          color: settings.customBgColor,
          onTap: () => _pickColor(context, settings, isText: false),
          onDefault: () => settings.setCustomBgColor(null),
        ),

        // ── 노트 ─────────────────────────────────────────────────────────
        const Divider(),
        _SectionHeader(strings.notes),
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: Text(strings.exportNotes),
          onTap: () => _exportNotes(context),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: Text(strings.importNotes),
          onTap: () => _importNotes(context),
        ),

        // ── 성경 목록 ─────────────────────────────────────────────────────
        const Divider(),
        _SectionHeader(strings.bibleTranslations),
        ..._buildSourceList(
            context, settings, settings.bibles, SourceType.bible),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(strings.addBibleFile),
          onTap: () => _importFile(context, SourceType.bible),
        ),

        // ── 주석 목록 ─────────────────────────────────────────────────────
        const Divider(),
        _SectionHeader(strings.commentarySources),
        ..._buildSourceList(
            context, settings, settings.commentaries, SourceType.commentary),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(strings.addCommentaryFile),
          onTap: () => _importFile(context, SourceType.commentary),
        ),

        // ── 찬송가 / 교독문 목록 (별개 관리: 추가·삭제·최소 1개 규칙 각각) ──
        const Divider(),
        _SectionHeader(strings.hymnSources),
        ..._buildSourceList(
          context,
          settings,
          settings.hymnalSources,
          SourceType.hymn,
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(strings.addHymnFile),
          onTap: () => _importFile(context, SourceType.hymn),
        ),
        const Divider(),
        _SectionHeader(strings.readingSources),
        ..._buildSourceList(
          context,
          settings,
          settings.readingSources,
          SourceType.hymn,
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(strings.addReadingFile),
          onTap: () => _importFile(context, SourceType.hymn, asReading: true),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              '${strings.madeBy}$kBuildVersion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSourceList(
    BuildContext context,
    SettingsProvider settings,
    List<SourceInfo> sources,
    SourceType type,
  ) {
    final strings = AppStrings(settings.appLanguage);
    // Count within the passed (already category-filtered) list, so the
    // "last one cannot be switched off" rule applies per category.
    final enabledCount = sources.where((s) => s.isEnabled).length;
    return sources.map((src) {
      // The last remaining enabled source of a type cannot be switched off.
      final isLastEnabled = src.isEnabled && enabledCount <= 1;
      return ListTile(
        leading: Icon(
          _iconFor(type),
          color: src.isEnabled
              ? (Theme.of(context).brightness == Brightness.dark
                  // The dark theme's primary is a deep blue that vanishes on
                  // dark surfaces — use a bright same-hue tint instead.
                  ? Colors.lightBlueAccent
                  : Theme.of(context).colorScheme.primary)
              : Theme.of(context).colorScheme.outline,
        ),
        title: Text(src.name),
        subtitle: Text(src.isBuiltIn ? strings.builtIn : src.docPath),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: strings.renameSource,
              onPressed: () => _renameSource(context, settings, src),
            ),
            Switch(
              value: src.isEnabled,
              onChanged: isLastEnabled
                  ? null
                  : (v) async {
                      final changed = await settings.toggleSource(src, v);
                      if (!changed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(strings.cannotDisableLastSource),
                          ),
                        );
                      }
                      if (type == SourceType.bible && context.mounted) {
                        await context.read<BibleProvider>().syncWithSources(
                              context.read<SettingsProvider>().enabledBibles,
                            );
                      }
                    },
            ),
            if (settings.canRemoveSource(src))
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: strings.delete,
                onPressed: () => _confirmRemove(context, settings, src),
              ),
          ],
        ),
      );
    }).toList();
  }

  IconData _iconFor(SourceType type) {
    switch (type) {
      case SourceType.bible:
        return Icons.menu_book;
      case SourceType.commentary:
        return Icons.comment_outlined;
      case SourceType.hymn:
        return Icons.music_note_outlined;
      case SourceType.dictionary:
        return Icons.abc;
    }
  }

  Future<void> _importFile(BuildContext context, SourceType type,
      {bool asReading = false}) async {
    final settings = context.read<SettingsProvider>();
    final bibleProvider = context.read<BibleProvider>();
    final strings = AppStrings(settings.appLanguage);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final srcPath = file.path;
    if (srcPath == null) return;

    final ext = p.extension(srcPath).toLowerCase();
    final allowed = {
      SourceType.bible: ['.bdb', '.sdb'],
      SourceType.commentary: ['.cdb'],
      SourceType.hymn: ['.hdb'],
      SourceType.dictionary: ['.dct'],
    }[type]!;

    if (!allowed.contains(ext)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.fileTypeAllowed(allowed.join(', ')))),
        );
      }
      return;
    }

    // Copy the selected database to the app's documents directory.
    final docs = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(docs.path, 'bible_db'));
    await destDir.create(recursive: true);
    final destPath = p.join(destDir.path, p.basename(srcPath));
    await File(srcPath).copy(destPath);

    // A hymnal sheet-music archive uses the same base name with a .cmp
    // extension. If it sits beside the selected .hdb, copy and link it too.
    var companionDestPath = '';
    if (type == SourceType.hymn) {
      final companionSrc = File(p.setExtension(srcPath, '.cmp'));
      if (companionSrc.existsSync()) {
        companionDestPath = p.join(
          destDir.path,
          p.basename(companionSrc.path),
        );
        await companionSrc.copy(companionDestPath);
      }
    }

    final id = p.basenameWithoutExtension(srcPath);
    final src = SourceInfo(
      id: id,
      name: id,
      type: type,
      docPath: destPath,
      companionPath: companionDestPath,
      isReading: asReading,
    );

    if (context.mounted) {
      await settings.addSource(src);
      if (type == SourceType.bible) {
        await bibleProvider.syncWithSources(settings.enabledBibles);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == SourceType.hymn && companionDestPath.isNotEmpty
                ? '${strings.sourceAdded(id)}\n${strings.cmpCopied}'
                : type == SourceType.hymn
                    ? '${strings.sourceAdded(id)}\n${strings.cmpMissing}'
                    : strings.sourceAdded(id),
          ),
        ),
      );
    }
  }

  Future<void> _exportNotes(BuildContext context) async {
    final notes = context.read<NotesProvider>();
    final strings = AppStrings(context.read<SettingsProvider>().appLanguage);
    if (notes.all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.noNotes)),
      );
      return;
    }

    // 1) Default: write straight to the public Downloads folder when the
    //    device allows it (no dialog needed).
    var path = await notes.tryExportToDownloads();
    if (!context.mounted) return;

    // 2) Otherwise let the user choose a folder.
    if (path == null) {
      final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: strings.chooseExportFolder,
      );
      if (!context.mounted) return;
      if (dir == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.exportNotesCancelled)),
        );
        return;
      }
      try {
        path = await notes.exportCsvTo(dir);
      } catch (_) {
        path = null;
      }
      if (!context.mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path != null
            ? strings.notesExported(path)
            : strings.exportNotesFailed),
      ),
    );
  }

  Future<void> _importNotes(BuildContext context) async {
    final strings = AppStrings(context.read<SettingsProvider>().appLanguage);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    if (!path.toLowerCase().endsWith('.csv')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.fileTypeAllowed('.csv'))),
        );
      }
      return;
    }
    try {
      final count = await context.read<NotesProvider>().importCsv(path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.notesImported(count))),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.notesImportFailed)),
      );
    }
  }

  Future<void> _pickColor(BuildContext context, SettingsProvider settings,
      {required bool isText}) async {
    final strings = AppStrings(settings.appLanguage);
    final label = isText ? strings.fontColorLabel : strings.bgColorLabel;
    final current = isText ? settings.customTextColor : settings.customBgColor;
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => _ColorPickerDialog(
        title: strings.colorPickerTitle(label),
        initial: current,
      ),
    );
    if (result is Color) {
      if (isText) {
        await settings.setCustomTextColor(result);
      } else {
        await settings.setCustomBgColor(result);
      }
    } else if (result == 'default') {
      // 기본값: 테마 기본색으로 복원한다.
      if (isText) {
        await settings.setCustomTextColor(null);
      } else {
        await settings.setCustomBgColor(null);
      }
    }
  }

  Future<void> _renameSource(
      BuildContext context, SettingsProvider settings, SourceInfo src) async {
    final strings = AppStrings(settings.appLanguage);
    final controller = TextEditingController(text: src.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.renameSourceTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: strings.renameSourceHint),
          onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.ok),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await settings.renameSource(src, controller.text);
    }
    controller.dispose();
  }

  Future<void> _confirmRemove(
      BuildContext context, SettingsProvider settings, SourceInfo src) async {
    final strings = AppStrings(settings.appLanguage);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(strings.delete),
        content: Text(strings.deleteSourceConfirm(src.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final removed = await settings.removeSource(src);
    if (!context.mounted) return;
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            src.type == SourceType.bible
                ? strings.cannotDeleteLastBible
                : strings.cannotDeleteDefaultSource,
          ),
        ),
      );
      return;
    }

    if (src.type == SourceType.bible) {
      final enabled = context.read<SettingsProvider>().enabledBibles;
      await context.read<BibleProvider>().syncWithSources(enabled);
      // Prune the removed translation from the comparison selection too.
      await context.read<CompareProvider>().syncWithSources(enabled);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

/// One settings row for a customizable color: shows the current swatch
/// (or "Default"), opens the picker on tap, and resets via the trailing
/// Default button.
class _ColorRow extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback onTap;
  final VoidCallback onDefault;

  const _ColorRow({
    required this.label,
    required this.color,
    required this.onTap,
    required this.onDefault,
  });

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(
        Provider.of<SettingsProvider>(context, listen: false).appLanguage);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
        child: color == null
            ? const Icon(Icons.format_color_reset, size: 16)
            : null,
      ),
      title: Text(label),
      subtitle: Text(color == null ? strings.defaultColor : _hex(color!)),
      trailing: TextButton(
        onPressed: color == null ? null : onDefault,
        child: Text(strings.defaultColor),
      ),
    );
  }
}

/// Color picker dialog: H/S/L sliders, preset swatches and a hex input
/// (#RRGGBB). Returns the chosen [Color], the string 'default' when the
/// user tapped 기본값, or null when cancelled.
class _ColorPickerDialog extends StatefulWidget {
  final String title;
  final Color? initial;

  const _ColorPickerDialog({required this.title, this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSLColor _hsl;
  final _hexController = TextEditingController();
  String? _hexError;

  static const _presets = [
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFD32F2F),
    Color(0xFFF57C00),
    Color(0xFFFBC02D),
    Color(0xFF388E3C),
    Color(0xFF1976D2),
    Color(0xFF7B1FA2),
    Color(0xFF795548),
    Color(0xFF384832),
  ];

  @override
  void initState() {
    super.initState();
    _hsl = HSLColor.fromColor(
        widget.initial ?? const Color(0xFFFFFFFF));
    _hexController.text = _hex(_hsl.toColor());
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  void _applyHex(String input) {
    var h = input.trim().replaceFirst('#', '');
    if (h.length == 3) {
      h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
    }
    final v = int.tryParse(h, radix: 16);
    if (h.length != 6 || v == null) {
      setState(() => _hexError = 'bad');
      return;
    }
    setState(() {
      _hexError = null;
      _hsl = HSLColor.fromColor(Color(0xFF000000 | v));
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(
        Provider.of<SettingsProvider>(context, listen: false).appLanguage);
    final color = _hsl.toColor();
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _slider('H', _hsl.hue, 0, 360, (v) => _hsl = _hsl.withHue(v)),
          _slider('S', _hsl.saturation, 0, 1, (v) => _hsl = _hsl.withSaturation(v)),
          _slider('L', _hsl.lightness, 0, 1, (v) => _hsl = _hsl.withLightness(v)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _presets)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _hsl = HSLColor.fromColor(p);
                      _hexController.text = _hex(p);
                      _hexError = null;
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: p,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hexController,
            decoration: InputDecoration(
              hintText: strings.hexColorHint,
              errorText: _hexError == null ? null : strings.invalidColorCode,
              isDense: true,
            ),
            onChanged: (v) {
              if (v.trim().replaceFirst('#', '').length >= 6) {
                _applyHex(v);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('default'),
          child: Text(strings.defaultColor),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () {
            final v = _hexController.text.trim();
            if (v.replaceFirst('#', '').length == 6) _applyHex(v);
            if (_hexError != null) return;
            Navigator.of(context).pop(_hsl.toColor());
          },
          child: Text(strings.colorPickerApply),
        ),
      ],
    );
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ),
      ],
    );
  }
}

/// Value box shown at the right end of a font-size slider. Tapping it opens
/// a small editor where the number can be typed directly or stepped with
/// +/- buttons; the value is clamped to the slider's min/max either way.
class _SliderValueBox extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double width;
  final ValueChanged<double> onChanged;

  const _SliderValueBox({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.width = 56,
  });

  Future<void> _edit(BuildContext context) async {
    final strings = AppStrings(context.read<SettingsProvider>().appLanguage);
    final controller = TextEditingController(text: value.round().toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          void bump(int delta) {
            final cur = int.tryParse(controller.text) ?? value.round();
            final v = (cur + delta).clamp(min.round(), max.round());
            controller.text = v.toString();
          }

          return AlertDialog(
            title: Text(label),
            content: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => bump(-1),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '${min.round()}–${max.round()}',
                    ),
                    onChanged: (_) => setDlg(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => bump(1),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(strings.apply),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed == true) {
      final v = (int.tryParse(controller.text) ?? value.round())
          .clamp(min.round(), max.round());
      onChanged(v.toDouble());
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _edit(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
