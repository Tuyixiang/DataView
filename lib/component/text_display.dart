part of "item_display.dart";

extension _PlainTextDisplay on _ItemDisplayState {
  Widget buildPlainText(String text, {TextStyle? style}) =>
      Container(
            alignment: Alignment.centerLeft,
            width: .infinity,
            child: SelectableText(
              escapeAllSpecial(text),
              style: AppTextStyles.monospace.merge(style),
            ),
          )
          .paddingDirectional(horizontal: 12, vertical: 8)
          .constrained(maxWidth: AppLayout.centerMaxWidth)
          .center()
          .scrollable();

  // Widget buildSingleLinePlainText(
  //   BuildContext context,
  //   String text, {
  //   TextStyle? style,
  // }) => Text(
  //   escapeAllSpecial(text),
  //   style: AppTextStyles.monospace.merge(style),
  //   maxLines: 1,
  //   softWrap: false,
  //   overflow: TextOverflow.fade,
  // ).paddingDirectional(horizontal: 12, vertical: 8).center();
}

final highlighterSupportedLang = Map.fromEntries(
  {
    "python": ["python", "python3", "py", "py3"],
    // "cpp": ["cpp", "c++", "c"],
    "javascript": ["javascript", "js", "typescript", "ts"],
    "json": ["json"],
    "html": ["html"],
  }.entries.expand(
    (element) => element.value.map((v) => MapEntry(v, element.key)),
  ),
);

class HighlightDisplay extends StatefulWidget {
  final String text;
  final String lang;
  final bool? showNumber;
  const HighlightDisplay({
    super.key,
    required this.text,
    required this.lang,
    this.showNumber,
  });

  @override
  State<HighlightDisplay> createState() => _HighlightDisplayState();
}

class _HighlightDisplayState extends State<HighlightDisplay> {
  static final highlightViewTheme = initHighlightViewTheme();

  static Map<String, TextStyle> initHighlightViewTheme() {
    final theme = {...githubTheme};
    theme["root"] = (theme["root"] ?? TextStyle()).apply(
      backgroundColor: Colors.transparent,
    );
    return theme;
  }

  static late final HighlighterTheme highlighterTheme;
  static final Lazy<Future<void>> highlighterInitialization = Lazy.value(
    (() async {
      await Highlighter.initialize(
        highlighterSupportedLang.values.toSet().toList(),
      );
      highlighterTheme = await HighlighterTheme.loadLightTheme();
      highlighterInitialized = true;
    })(),
  );
  static final Map<String, Highlighter> highlighters = {};
  static bool highlighterInitialized = false;
  bool initialized = false;
  String? highlighterLang;

  @override
  void initState() {
    super.initState();
    highlighterLang = highlighterSupportedLang[widget.lang];
    if (highlighterLang != null && !highlighterInitialized) {
      highlighterInitialization.unwrap().then((_) {
        if (mounted) {
          setState(() {
            prebuiltWidget.rerun();
          });
        }
      });
    }
  }

  late Lazy<Widget> prebuiltWidget = Lazy.getter(() {
    final text = escapeAllSpecial(widget.text);
    if (highlighterLang == null || text.length > 1000000) {
      return HighlightView(
        text,
        language: widget.lang,
        textStyle: AppTextStyles.monospace,
        tabSize: 2,
        theme: highlightViewTheme,
      );
    }
    if (!highlighterInitialized) {
      return SizedBox.shrink();
    }
    final parsed = highlighters
        .putIfAbsent(
          highlighterLang!,
          () =>
              Highlighter(language: highlighterLang!, theme: highlighterTheme),
        )
        .highlight(text);
    final lines = [<TextSpan>[]];
    void walk(TextSpan span, TextStyle parentStyle) {
      final style = parentStyle.merge(span.style);
      if (span.text != null) {
        if (span.text!.contains("\n")) {
          final multiline = span.text!.split("\n");
          for (final i in range(multiline.length)) {
            walk(TextSpan(text: multiline[i]), style);
            if (i < multiline.length - 1) {
              lines.add([]);
            }
          }
          return;
        }
        lines.last.add(TextSpan(text: span.text!, style: style));
      }
      if (span.children?.isNotEmpty == true) {
        for (final s in span.children!) {
          walk(s as TextSpan, style);
        }
      }
    }

    parsed.children?.forEach(
      (e) => walk(e as TextSpan, AppTextStyles.monospace),
    );
    while (lines.lastOrNull?.isEmpty == true) {
      lines.removeLast();
    }

    final showNumber =
        widget.showNumber ?? !["", "json", "yaml"].contains(widget.lang);
    final lineNumberWidth = (log(lines.length + 1) * log10e).ceil();
    final numberStyle = AppTextStyles.monospace.copyWith(
      color: Color(0x40808080),
    );

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: List.generate(lines.length, (i) {
        final spans = Queue<TextSpan>.from(lines[i]);
        int spaceCount = 0;
        while (spans.isNotEmpty && spans.first.text!.startsWith(" ")) {
          final first = spans.removeFirst();
          final text = first.text!;
          final match = RegExp(" *").matchAsPrefix(text)!;
          if (match.end == text.length) {
            spaceCount += text.length;
          } else {
            spaceCount += match.end;
            spans.addFirst(
              TextSpan(text: text.substring(match.end), style: first.style),
            );
          }
        }
        final number = Text(
          "${(i + 1).toString().padLeft(lineNumberWidth)}  ",
          style: numberStyle,
        );
        if (spans.isEmpty) {
          return showNumber ? number : Text(" ", style: numberStyle);
        }
        if (spaceCount == 0 || spaceCount >= 32) {
          return Row(
            crossAxisAlignment: .start,
            children: [
              if (showNumber) number,
              Expanded(child: Text.rich(TextSpan(children: lines[i]))),
            ],
          );
        }
        return Row(
          crossAxisAlignment: .start,
          children: [
            if (showNumber) number,
            Text(" " * spaceCount, style: numberStyle),
            Expanded(child: Text.rich(TextSpan(children: spans.toList()))),
          ],
        );
      }),
    );
  });

  @override
  Widget build(BuildContext context) => prebuiltWidget.unwrap();
}

extension _HighlightedDisplay on _ItemDisplayState {
  Widget buildHighlighted(DisplayCode display) =>
      Container(
            alignment: Alignment.centerLeft,
            width: .infinity,
            child: HighlightDisplay(
              key: ObjectKey(display.content),
              text: display.content,
              lang: display.lang,
            ),
          )
          .paddingDirectional(horizontal: 12, vertical: 8)
          .constrained(maxWidth: AppLayout.centerMaxWidth)
          .center()
          .scrollable();
}

extension _MarkdownDisplay on _ItemDisplayState {
  Widget buildMarkdown(DisplayMarkdown display) =>
      Container(
            alignment: Alignment.centerLeft,
            width: .infinity,
            child: MarkdownBlock(
              data: display.content,
              selectable: false,
              generator: MarkdownGenerator(
                generators: [
                  latexGenerator,
                  disabledTagGenerator,
                  strongGenerator,
                  codeSpanGenerator,
                  codeBlockGenerator,
                ],
                textGenerator: (node, config, visitor) =>
                    CustomTextNode(node.textContent, config, visitor),
                inlineSyntaxList: [LatexSyntax(), DisableWrapSyntax()],
              ),
              config: MarkdownConfig(
                configs: [
                  CodeConfig(style: AppTextStyles.monospaceWithBack),
                  PreConfig(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    textStyle: AppTextStyles.monospace,
                    margin: EdgeInsetsGeometry.zero,
                    padding: EdgeInsetsGeometry.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    styleNotMatched: AppTextStyles.monospace,
                  ),
                  H1Config(
                    style: H1Config().style.merge(AppTextStyles.boldStyle),
                  ),
                  H2Config(
                    style: H2Config().style.merge(AppTextStyles.boldStyle),
                  ),
                  H3Config(
                    style: H3Config().style.merge(AppTextStyles.boldStyle),
                  ),
                  H4Config(
                    style: H4Config().style.merge(AppTextStyles.boldStyle),
                  ),
                  H5Config(
                    style: H5Config().style.merge(AppTextStyles.boldStyle),
                  ),
                  H6Config(
                    style: H6Config().style.merge(AppTextStyles.boldStyle),
                  ),
                ],
              ),
            ),
          )
          .paddingDirectional(horizontal: 12)
          .constrained(maxWidth: AppLayout.centerMaxWidth)
          .center()
          .scrollable();
}
