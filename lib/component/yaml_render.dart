// Dart imports:
import "dart:math";

// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:flutter_highlight/themes/github.dart";
import "package:styled_widget/styled_widget.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/common/config.dart";
import "package:frontend/component/common.dart";
import "package:frontend/component/text/escape.dart";
import "package:frontend/data/common.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/data/data_type.dart";
import "package:frontend/styles/base.dart";

/// Reference: [githubTheme]
class YamlTextStyles {
  static final key = AppTextStyles.monospace.copyWith(
    color: Color(0xff000080),
    fontVariations: [AppTextStyles.boldVariation],
  );
  static final symbol = AppTextStyles.monospace.copyWith(
    color: Color(0xff999999),
  );
  static final string = AppTextStyles.monospace.copyWith(
    color: Color(0xffdd1144),
  );
  static final number = AppTextStyles.monospace.copyWith(
    color: Color(0xff008080),
  );
  static final boolean = AppTextStyles.monospace.copyWith(
    color: Color(0xff990073),
    fontVariations: [AppTextStyles.boldVariation],
  );
  static final none = AppTextStyles.monospace.copyWith(
    color: Color(0xff999999),
    fontStyle: FontStyle.italic,
    fontVariations: [AppTextStyles.boldVariation],
  );
  static final emptyObject = AppTextStyles.monospace.copyWith(
    color: Color(0xff0086b3),
    fontVariations: [AppTextStyles.boldVariation],
  );
  static final ellipsis = AppTextStyles.monospace.copyWith(
    color: Color(0xff999999),
    fontStyle: FontStyle.italic,
    decoration: TextDecoration.underline,
    decorationColor: Color(0xff999999),
    decorationThickness: 2,
  );
  static final error = AppTextStyles.monospace.copyWith(
    color: Colors.white,
    backgroundColor: Colors.red,
    fontStyle: FontStyle.italic,
    fontVariations: [AppTextStyles.boldVariation],
  );
}

TextSpan highlightEscape(String text, TextStyle style) {
  final spans = <TextSpan>[];
  int end = 0;
  for (final match in controlChars.allMatches(text)) {
    if (match.start > end) {
      spans.add(TextSpan(text: text.substring(end, match.start), style: style));
    }
    spans.add(
      TextSpan(
        text: escapeChar(match.group(0)!, prefix: false),
        style: style.inversed(),
      ),
    );
    end = match.end;
  }
  if (end < text.length) {
    spans.add(TextSpan(text: text.substring(end), style: style));
  }
  return TextSpan(children: spans);
}

class YamlRender extends StatefulWidget {
  final DataType data;
  final DisplayObject display;

  /// All strings will be truncated at this limit
  final int stringLimit;

  /// Estimated total lines of display
  final int contentLimit;

  YamlRender(
    this.display, {
    super.key,
    this.stringLimit = PAGE_STRING_LIMIT,
    this.contentLimit = 160,
  }) : data = display.data;

  @override
  State<YamlRender> createState() => _YamlRenderState();
}

class _YamlRenderState extends State<YamlRender> {
  late final Lazy<Widget> tree;
  late int contentLimitRemainder;

  @override
  void initState() {
    super.initState();
    contentLimitRemainder = widget.contentLimit;
    tree = Lazy.getter(() => displayTree(buildTree(widget.data)));
  }

  @override
  Widget build(BuildContext context) {
    return tree.unwrap().paddingDirectional(horizontal: 12, vertical: 8);
  }

  Widget displayTree(({InlineSpan? span, Widget? widget}) data) => Column(
    mainAxisSize: .min,
    crossAxisAlignment: .start,
    children: [
      if (data.span != null) Text.rich(data.span!),
      if (data.widget != null) data.widget!,
    ],
  );

  Widget buildCopiable({
    required BuildContext context,
    required String text,
    String? displayText,
    required TextStyle style,
  }) => InkWell(
    onTap: () => copyToClipboard(text),
    hoverColor: style.color?.withAlpha(16) ?? Color(0x20808080),
    splashColor: Colors.transparent,
    child: Text.rich(highlightEscape(displayText ?? text, style)),
  );

  Widget buildEllipsisMessage(String message, DataType data) => InkWell(
    onTap: () => showDataDialog(data: data),
    hoverColor: Color(0x40808080),
    child: Text(message, style: YamlTextStyles.ellipsis),
  );

  ({InlineSpan? span, Widget? widget}) buildTree(
    DataType data, {
    int level = 0,
  }) {
    if (level >= 16) {
      return (
        span: TextSpan(text: "Too deeply nested", style: YamlTextStyles.error),
        widget: null,
      );
    }
    switch (data) {
      case LiteralNull():
      case LiteralBool():
      case LiteralNum():
        contentLimitRemainder -= 1;
        return (span: buildInline(data), widget: null);
      case DataType<String>():
        return buildString(data);
      case StructuredData():
        if (data.isMap) {
          return buildMap(data, level: level);
        } else {
          return buildList(data, level: level);
        }
    }
  }

  ({InlineSpan? span, Widget? widget}) buildList(
    StructuredData list, {
    int level = 0,
  }) {
    if (list.length == 0) {
      return (
        span: TextSpan(text: "[]", style: YamlTextStyles.emptyObject),
        widget: null,
      );
    }
    final rows = <Widget>[];
    for (final i in range(list.length)) {
      if (contentLimitRemainder <= 0) {
        rows.add(
          buildEllipsisMessage("showing $i / ${list.length} items", list),
        );
        break;
      }
      rows.add(
        Row(
          crossAxisAlignment: .start,
          children: [
            if (list.length >= 10) Text("$i: ", style: YamlTextStyles.symbol),
            if (list.length < 10) Text("- ", style: YamlTextStyles.symbol),
            Expanded(
              child: displayTree(
                buildTree(list[i.toString()].unwrap(), level: level + 1),
              ),
            ),
          ],
        ),
      );
    }
    return (
      span: null,
      widget: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: rows,
      ),
    );
  }

  ({InlineSpan? span, Widget? widget}) buildMap(
    StructuredData map, {
    int level = 0,
  }) {
    if (map.length == 0) {
      return (
        span: TextSpan(text: "{}", style: YamlTextStyles.emptyObject),
        widget: null,
      );
    }
    final rows = <Widget>[];
    final keys = map.firstLevelKeys;
    for (final i in range(map.length)) {
      if (contentLimitRemainder <= 0) {
        rows.add(buildEllipsisMessage("showing $i / ${map.length} items", map));
        break;
      }
      final child = buildTree(map[keys[i]].unwrap(), level: level + 1);
      rows.add(
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: .min,
          children: [
            Container(
              alignment: Alignment.topLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    buildInline(
                      MarkdownString.literal(DataPath.displayKey(keys[i])),
                      asKey: true,
                    ),
                    TextSpan(text: ": ", style: YamlTextStyles.symbol),
                    if (child.span != null) child.span!,
                  ],
                ),
              ),
            ),
            if (child.widget != null)
              Row(
                crossAxisAlignment: .start,
                children: [
                  Text("  ", style: AppTextStyles.monospace),
                  Expanded(child: child.widget!),
                ],
              ),
          ],
        ),
      );
    }
    return (
      span: null,
      widget: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: rows,
      ),
    );
  }

  ({InlineSpan? span, Widget? widget}) buildString(
    DataType<String> data, {
    bool asKey = false,
    bool forceInline = false,
  }) {
    final string = data.toString();
    if (forceInline || (string.length < 64 && !string.contains("\n"))) {
      late final String displayString;
      if (string.startsWith("'")) {
        displayString = '"${string.replaceAll('"', '""')}"';
      } else if (string.startsWith('"')) {
        displayString = "'${string.replaceAll("'", "''")}'";
      } else if (["true", "false", "null", "[]", "{}"].contains(string) ||
          int.tryParse(string) != null ||
          (string.startsWith("0x") &&
              int.tryParse(string, radix: 16) != null)) {
        displayString = '"$string"';
      } else {
        displayString = string;
      }
      if (asKey) {
        return (
          span: highlightEscape(displayString, YamlTextStyles.key),
          widget: null,
        );
      }
      // limit is subtracted only for non-key strings
      contentLimitRemainder -= (displayString.length / 80).ceil();
      return (
        span: WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: buildCopiable(
            context: context,
            text: string,
            displayText: displayString,
            style: YamlTextStyles.string,
          ),
        ),
        widget: null,
      );
    }
    final span = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: InkWell(
        onTap: () => showDataDialog(data: string),
        child: Row(
          mainAxisSize: .min,
          children: [
            Text(
              "preview",
              style: (Theme.of(context).textTheme.bodyMedium ?? TextStyle())
                  .copyWith(
                    color: Colors.white,
                    fontVariations: [FontVariation.weight(450)],
                  ),
            ).padding(left: 4),
            Icon(
              Icons.open_in_browser,
              size: AppTextStyles.monospace.fontSize,
              color: Colors.white,
            ).paddingDirectional(all: 2),
          ],
        ).backgroundColor(YamlTextStyles.string.color!),
      ),
    );
    // limit is subtracted only for non-key strings
    contentLimitRemainder -= (min(string.length, widget.stringLimit) / 80)
        .ceil();
    if (string.length >= widget.stringLimit) {
      return (
        span: span,
        widget: Column(
          crossAxisAlignment: .start,
          children: [
            buildCopiable(
              context: context,
              text: string,
              style: YamlTextStyles.string,
              displayText: "${string.substring(0, widget.stringLimit)}...",
            ),
            buildEllipsisMessage(
              "showing ${widget.stringLimit} / ${string.length} chars",
              data,
            ),
          ],
        ),
      );
    }
    return (
      span: span,
      widget: buildCopiable(
        context: context,
        text: string,
        style: YamlTextStyles.string,
      ),
    );
  }

  InlineSpan buildInline(DataType data, {bool asKey = false}) {
    switch (data) {
      case LiteralNull():
        return TextSpan(text: "null", style: YamlTextStyles.none);
      case LiteralNum():
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: buildCopiable(
            context: context,
            text: data.toString(),
            style: YamlTextStyles.number,
          ),
        );
      case LiteralBool():
        return TextSpan(text: data.toString(), style: YamlTextStyles.boolean);
      case DataType<String>():
        return buildString(data, asKey: asKey, forceInline: true).span!;
      case StructuredData():
        throw TypeError();
    }
  }
}
