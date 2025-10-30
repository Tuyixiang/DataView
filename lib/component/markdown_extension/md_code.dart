// Dart imports:
import "dart:math";

// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:markdown/markdown.dart" as m;
import "package:markdown_widget/markdown_widget.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/common/config.dart";
import "package:frontend/common/platform.dart";
import "package:frontend/component/common.dart";
import "package:frontend/component/item_display.dart";
import "package:frontend/data_view.dart";

import "package:frontend/data/code_run/stub.dart"
    if (dart.library.io) "package:frontend/data/code_run/desktop.dart"
    if (dart.library.html) "package:frontend/data/code_run/web.dart";

SpanNodeGeneratorWithTag codeSpanGenerator = SpanNodeGeneratorWithTag(
  tag: "code",
  generator: (e, config, visitor) => CodeSpanNode(e.textContent, config.code),
);

class CodeSpanNode extends CodeNode {
  CodeSpanNode(super.text, super.codeConfig);

  @override
  InlineSpan build() => TextSpan(
    children: [
      WidgetSpan(child: SizedBox(width: 2)),
      TextSpan(style: style, text: text),
      WidgetSpan(child: SizedBox(width: 2)),
    ],
  );
}

SpanNodeGeneratorWithTag codeBlockGenerator = SpanNodeGeneratorWithTag(
  tag: "pre",
  generator: (e, config, visitor) =>
      CodeBlockExtendedNode(e, config.pre, visitor),
);

class CodeBlockExtendedNode extends CodeBlockNode {
  CodeBlockExtendedNode(super.element, super.preConfig, super.visitor);

  Widget buildBlockHeading({
    String? lang,
    required String code,
  }) => SingleUseWidget(
    (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceDim,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (lang != null) LabelCard(text: lang),
          Spacer(),
          // Preview button for json or yaml
          if (["json", "yaml"].contains(lang))
            LabelCard(text: "preview", icon: Icons.open_in_browser).onTap(() {
              showDataDialog(
                context,
                title: "Data Preview",
                data: code,
              );
            }),
          // Preview button for html and jsx
          if (["html", if (TEST_FEATURES) "jsx"].contains(lang))
            LabelCard(text: "preview", icon: Icons.open_in_browser).onTap(() {
              showDataDialog(
                context,
                title: "Web Preview",
                data: "```$lang\n$code\n```",
              );
            }),
          // Run button for python
          if (kIsMac && ["py", "python", "python3"].contains(lang))
            LabelCard(text: "run", icon: Icons.terminal).onTap(() {
              executePython(code).catchError((e) {
                if (context.mounted) {
                  showSnackBar(context, e.toString());
                }
              });
            }),
          // Run button for cpp
          if (kIsMac && ["cpp", "c++"].contains(lang))
            LabelCard(text: "run", icon: Icons.terminal).onTap(() {
              executeCpp(code).catchError((e) {
                if (context.mounted) {
                  showSnackBar(context, e.toString());
                }
              });
            }),
          LabelCard(
            icon: Icons.copy,
          ).onTap(() => copyToClipboard(context: context, text: code)),
        ],
      ),
    ),
  );

  Widget buildText(String text, String? language) => ProxyRichText(
    TextSpan(
      children: highLightSpans(
        text,
        language: language ?? preConfig.language,
        theme: preConfig.theme,
        textStyle: style,
        styleNotMatched: preConfig.styleNotMatched,
      ),
    ),
    richTextBuilder: visitor.richTextBuilder,
  );

  @override
  InlineSpan build() {
    String? language = preConfig.language;
    if (element.children?.first is m.Element) {
      try {
        final languageValue =
            (element.children?.first as m.Element).attributes["class"]!;
        language = languageValue.split("-").last;
      } catch (e) {
        language = null;
      }
    }
    late final Widget codeWidget;
    final content = this.content.trim().replaceAll("\t", "    ");
    if (highlighterSupportedLang.containsKey(language)) {
      codeWidget = Container(
        alignment: Alignment.topLeft,
        child: HighlightDisplay(text: content, lang: language!),
      );
    } else {
      final lines = content.split(
        visitor.splitRegExp ?? WidgetVisitor.defaultSplitRegExp,
      );
      if (lines.last.isEmpty) lines.removeLast();
      final lineNumberWidth = (log(lines.length) * log10e).ceil();
      codeWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines.length, (i) {
          final line = lines[i];
          final number = Text(
            "${(i + 1).toString().padLeft(lineNumberWidth)}  ",
            style: style.copyWith(
              color: style.color?.toOpacity(0.5) ?? Colors.grey,
            ),
          );
          final spaces = RegExp(r"\s*").matchAsPrefix(line)!.group(0)!;
          if (spaces.length == line.length) {
            return number;
          }
          if (spaces.length >= 32 || spaces.isEmpty) {
            return Row(
              children: [
                number,
                Expanded(child: buildText(line, language)),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              number,
              Text(spaces, style: style),
              Expanded(
                child: buildText(line.substring(spaces.length), language),
              ),
            ],
          );
        }),
      );
    }
    final widget = Container(
      decoration: preConfig.decoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildBlockHeading(code: content, lang: language),
          Container(
            margin: preConfig.margin,
            padding: preConfig.padding,
            width: double.infinity,
            child: codeWidget,
          ),
        ],
      ),
    );
    return WidgetSpan(
      child: preConfig.wrapper?.call(widget, content, language ?? "") ?? widget,
    );
  }
}

class CodeLine {
  final String text;
  final List<TextSpan>? spans;
  final Widget Function(String)? builder;
  final TextStyle defaultStyle;

  CodeLine({
    required this.text,
    this.spans,
    this.builder,
    this.defaultStyle = const TextStyle(),
  });
}
