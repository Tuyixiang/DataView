// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:flutter_math_fork/flutter_math.dart";
import "package:markdown/markdown.dart" as m;
import "package:markdown_widget/markdown_widget.dart";

SpanNodeGeneratorWithTag latexGenerator = SpanNodeGeneratorWithTag(
  tag: _latexTag,
  generator: (e, config, visitor) =>
      LatexNode(e.attributes, e.textContent, config),
);

const _latexTag = "latex";

class LatexSyntax extends m.InlineSyntax {
  LatexSyntax()
    : super(r"(\${2,})[\s\S]+?\1|\$.+?\$|\\\[[\s\S]+?\\\]|\\\([\s\S]+?\\\)");

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final text = match.group(0)!;
    late final String content;
    late final bool isInline;
    if (text.startsWith("\$\$")) {
      final dollarCount = RegExp(r"\$+").matchAsPrefix(text)!.group(0)!.length;
      content = text.substring(dollarCount, text.length - dollarCount);
      isInline = !content.contains("\n");
    } else if (text.startsWith("\\[") || text.startsWith("\\(")) {
      content = text.substring(2, text.length - 2);
      isInline = !content.contains("\n");
    } else {
      content = text.substring(1, text.length - 1);
      isInline = true;
    }
    m.Element el = m.Element.text(_latexTag, text);
    el.attributes["content"] = content;
    el.attributes["isInline"] = "$isInline";
    parser.addNode(el);
    return true;
  }
}

class LatexNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;
  final MarkdownConfig config;

  LatexNode(this.attributes, this.textContent, this.config);

  @override
  InlineSpan build() {
    final content = attributes["content"] ?? "";
    final isInline = attributes["isInline"] == "true";
    final style = parentStyle ?? config.p.textStyle;
    if (content.isEmpty) return TextSpan(style: style, text: textContent);
    final latex = Math.tex(
      content,
      mathStyle: MathStyle.text,
      textStyle: style.copyWith(color: Colors.black),
      // textStyle: style.copyWith(color: isDark ? Colors.white : Colors.black),
      textScaleFactor: 1,
      onErrorFallback: (error) {
        return Text(textContent, style: style.copyWith(color: Colors.red));
      },
    );
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: !isInline
          ? Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: latex),
            )
          : latex,
    );
  }
}
