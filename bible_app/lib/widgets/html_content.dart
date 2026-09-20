import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Renders a small subset of HTML used in commentary and hymn texts:
///   <b>, <strong>, <i>, <em>, <br>, <font color="...">, and plain text.
class HtmlContent extends StatelessWidget {
  final String html;
  final double fontSize;

  const HtmlContent({super.key, required this.html, this.fontSize = 14.0});

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: 1.6,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doc = html_parser.parseFragment(html);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: doc.nodes.map((n) => _node(n, baseStyle, isDark)).toList(),
      ),
    );
  }

  TextSpan _node(dom.Node node, TextStyle style, bool isDark) {
    if (node is dom.Text) {
      return TextSpan(text: node.text, style: style);
    }
    if (node is dom.Element) {
      TextStyle s = style;
      switch (node.localName) {
        case 'b':
        case 'strong':
          s = s.copyWith(fontWeight: FontWeight.bold);
          break;
        case 'i':
        case 'em':
          s = s.copyWith(fontStyle: FontStyle.italic);
          break;
        case 'font':
          final colorHex = node.attributes['color'];
          if (colorHex != null) {
            final c = _parseColor(colorHex);
            // Dark HTML colors (e.g. #0000cc) disappear on a dark background —
            // swap them for a bright tint of the same hue.
            if (c != null) s = s.copyWith(color: _readableOn(c, isDark));
          }
          break;
        case 'br':
          return const TextSpan(text: '\n');
      }
      final children =
          node.nodes.map((n) => _node(n, s, isDark)).toList();
      return TextSpan(style: s, children: children);
    }
    return const TextSpan();
  }

  /// Returns [c] as-is on light surfaces; on dark surfaces dark colors are
  /// re-lit to the same hue so they stay readable.
  static Color _readableOn(Color c, bool isDark) {
    if (!isDark) return c;
    final luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    if (luminance >= 0.55) return c;
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(0.72).withSaturation(0.75).toColor();
  }

  static Color? _parseColor(String hex) {
    try {
      var h = hex.trim().replaceFirst('#', '');
      if (h.length == 3) {
        h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
      }
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return null;
    }
  }
}
