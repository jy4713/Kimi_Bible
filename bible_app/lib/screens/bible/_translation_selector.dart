import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/source_info.dart';

/// Bottom-sheet that lets the user pick ONE translation (Bible reading tab).
Future<String?> showTranslationPicker(
  BuildContext context, {
  required List<SourceInfo> allSources,
  required String selectedId,
  required AppStrings strings,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TranslationPickerSheet(
      allSources: allSources,
      selectedIds: [selectedId],
      maxCount: 1,
      title: strings.translationSelection,
      hint: strings.singleSelectionHint,
      strings: strings,
    ),
  );
}

/// Bottom-sheet that lets the user pick MULTIPLE translations for comparison.
Future<List<String>?> showCompareTranslationPicker(
  BuildContext context, {
  required List<SourceInfo> allSources,
  required List<String> selectedIds,
  required AppStrings strings,
}) async {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TranslationPickerSheet(
      allSources: allSources,
      selectedIds: selectedIds,
      maxCount: 4,
      title: strings.compareTranslationSelection,
      hint: strings.compareSelectionHint,
      strings: strings,
    ),
  );
}

class _TranslationPickerSheet extends StatefulWidget {
  final List<SourceInfo> allSources;
  final List<String> selectedIds;
  final int maxCount;
  final String title;
  final String hint;
  final AppStrings strings;

  const _TranslationPickerSheet({
    required this.allSources,
    required this.selectedIds,
    required this.maxCount,
    required this.title,
    required this.hint,
    required this.strings,
  });

  @override
  State<_TranslationPickerSheet> createState() =>
      _TranslationPickerSheetState();
}

class _TranslationPickerSheetState extends State<_TranslationPickerSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedIds);
  }

  void _toggle(String id) {
    if (widget.maxCount == 1) {
      // Single-select sheet: return the chosen id directly.
      Navigator.pop(context, id);
      return;
    }
    setState(() {
      if (_selected.contains(id)) {
        if (_selected.length > 1) _selected.remove(id);
      } else {
        if (_selected.length >= widget.maxCount) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.strings.maxCompareReached)),
          );
          return;
        }
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          const _Handle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (widget.maxCount > 1)
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text(widget.strings.apply),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.hint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: widget.allSources.length,
              itemBuilder: (_, i) {
                final src = widget.allSources[i];
                final selectedIndex = _selected.indexOf(src.id);
                final selected = selectedIndex >= 0;
                return ListTile(
                  leading: selected
                      ? CircleAvatar(
                          radius: 14,
                          child: Text('${selectedIndex + 1}'),
                        )
                      : const SizedBox(width: 28),
                  title: Text(src.name),
                  trailing: Checkbox(
                    value: selected,
                    onChanged: (_) => _toggle(src.id),
                  ),
                  onTap: () => _toggle(src.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
