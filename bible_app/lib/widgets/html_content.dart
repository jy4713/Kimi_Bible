import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 사용자 지정 글자 색에 대비되도록 보조 색을 자동 생성한다.
/// 배경이 어두우면 밝은 보조색, 밝으면 어두운 보조색으로 hue를 150° 돌린 색을 쓴다.
Color contrastingAccent(Color textColor, Color background) {
  final bgDark = background.computeLuminance() < 0.5;
  final hsl = HSLColor.fromColor(textColor);
  return HSLColor.fromAHSL(
    1.0,
    (hsl.hue + 150) % 360,
    0.72,
    bgDark ? 0.68 : 0.38,
  ).toColor();
}

/// Renders a small subset of HTML used in commentary and hymn texts:
///   <b>, <strong>, <i>, <em>, <br>, <font color="...">, and plain text.
class HtmlContent extends StatelessWidget {
  final String html;
  final double fontSize;

  /// 사용자가 설정한 읽기 글자 색. 지정되면 기본 텍스트에 적용된다.
  /// [rethemeHtmlColors]가 true면 HTML 내 강조색은 이 색과 구분되는 색으로
  /// 자동 교체되고, false면 강조색은 테마에 맞게 보정만 된다.
  /// 둘 다 null이면 테마 기본색을 사용한다.
  final Color? baseTextColor;
  final bool rethemeHtmlColors;

  const HtmlContent({
    super.key,
    required this.html,
    this.fontSize = 14.0,
    this.baseTextColor,
    this.rethemeHtmlColors = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 사용자 바탕 색이 scaffoldBackgroundColor에 적용되므로 여기서 읽으면
    // 실제 배경의 명도를 알 수 있다.
    final bg = theme.scaffoldBackgroundColor;
    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: 1.6,
      color: baseTextColor ?? theme.colorScheme.onSurface,
    );
    final isDark = theme.brightness == Brightness.dark;
    final doc = html_parser.parseFragment(html);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: doc.nodes
            .map((n) => _node(n, baseStyle, isDark, bg))
            .toList(),
      ),
    );
  }

  TextSpan _node(
      dom.Node node, TextStyle style, bool isDark, Color bg) {
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
            if (c != null) {
              if (baseTextColor != null && rethemeHtmlColors) {
                // 사용자 글자 색과 구분되는 대비색으로 자동 교체한다.
                s = s.copyWith(
                    color: contrastingAccent(baseTextColor!, bg));
              } else {
                // Dark HTML colors (e.g. #0000cc) disappear on a dark
                // background — swap them for a bright tint of the same hue.
                s = s.copyWith(color: _readableOn(c, isDark));
              }
            }
          }
          break;
        case 'br':
          return const TextSpan(text: '\n');
      }
      final children =
          node.nodes.map((n) => _node(n, s, isDark, bg)).toList();
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
