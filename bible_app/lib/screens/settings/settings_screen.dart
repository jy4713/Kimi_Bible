import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
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
              Text(strings.menuFontSize),
              Expanded(
                child: Slider(
                  value: settings.uiFontPct,
                  min: 90,
                  max: 110,
                  divisions: 20,
                  label: '${settings.uiFontPct.round()}%',
                  onChanged: settings.setUiFontSize,
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${settings.uiFontPct.round()}%',
                  textAlign: TextAlign.center,
                ),
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
              Text(strings.fontSize),
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
              SizedBox(
                width: 32,
                child: Text(
                  '${settings.fontSize.round()}',
                  textAlign: TextAlign.center,
                ),
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
              style: TextStyle(fontSize: settings.fontSize, height: 1.6),
            ),
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

        // ── 찬송가 목록 ───────────────────────────────────────────────────
        const Divider(),
        _SectionHeader(strings.hymnSources),
        ..._buildSourceList(context, settings, settings.hymns, SourceType.hymn),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(strings.addHymnFile),
          onTap: () => _importFile(context, SourceType.hymn),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              strings.madeBy,
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
    return sources.map((src) {
      return ListTile(
        leading: Icon(
          _iconFor(type),
          color: src.isEnabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        title: Text(src.name),
        subtitle: Text(src.isBuiltIn ? strings.builtIn : src.docPath),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: src.isEnabled,
              onChanged: (v) async {
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

  Future<void> _importFile(BuildContext context, SourceType type) async {
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
