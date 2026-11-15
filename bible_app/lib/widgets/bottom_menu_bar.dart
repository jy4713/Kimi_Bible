import 'package:flutter/material.dart';

/// Custom five-segment bottom menu bar. The active segment is marked with a
/// full rectangular gray highlight (no pill indicator), so nothing gets
/// clipped. Label size follows the menu-font % setting, pre-capped by the
/// caller so text never wraps, overlaps, or runs off screen.
class BottomMenuBar extends StatelessWidget {
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> selectedIcons;
  final int selectedIndex;
  final double labelSize;
  final ValueChanged<int> onSelect;

  const BottomMenuBar({
    super.key,
    required this.labels,
    required this.icons,
    required this.selectedIcons,
    required this.selectedIndex,
    required this.labelSize,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = isDark ? Colors.white12 : Colors.black12;
    final bg = Theme.of(context).navigationBarTheme.backgroundColor ??
        scheme.surfaceContainer;
    return SizedBox(
      height: 52,
      child: Material(
        color: bg,
        child: Row(
          children: [
            for (int i = 0; i < labels.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Container(
                    color: selectedIndex == i
                        ? highlight
                        : Colors.transparent,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selectedIndex == i
                                ? selectedIcons[i]
                                : icons[i],
                            size: 20,
                            color: selectedIndex == i
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labels[i],
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: labelSize,
                              height: 1.0,
                              color: selectedIndex == i
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
