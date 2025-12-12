// Dart imports:
import "dart:collection";
import "dart:math";

// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:flutter_highlight/flutter_highlight.dart";
import "package:flutter_highlight/themes/github.dart";
import "package:markdown_widget/markdown_widget.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:material_table_view/material_table_view.dart";
import "package:provider/provider.dart";
import "package:styled_widget/styled_widget.dart";
import "package:syntax_highlight/syntax_highlight.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/component/common.dart";
import "package:frontend/component/markdown_extension/md_code.dart";
import "package:frontend/component/markdown_extension/md_html.dart";
import "package:frontend/component/markdown_extension/md_latex.dart";
import "package:frontend/component/markdown_extension/md_preprocess.dart";
import "package:frontend/component/markdown_extension/strong.dart";
import "package:frontend/component/text/escape.dart";
import "package:frontend/component/web_view.dart";
import "package:frontend/component/yaml_render.dart";
import "package:frontend/data/backend/base_backend.dart";
import "package:frontend/data/common.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/data/data_type.dart";
import "package:frontend/overlay.dart";
import "package:frontend/styles/base.dart";

import "package:frontend/data/code_run/stub.dart"
    if (dart.library.io) "package:frontend/data/code_run/desktop.dart"
    if (dart.library.html) "package:frontend/data/code_run/web.dart";

part "table_display.dart";
part "text_display.dart";
part "list_display.dart";
part "web_display.dart";

class ItemDisplay extends StatefulWidget {
  final DataPath path;
  final List<String> titles;
  final DisplaySizeEnum displaySize;
  final bool? preferSize;
  final EdgeInsets margin;

  int get charLimit => displaySize.charLimit;
  int get stringLimit => displaySize.stringLimit;
  int get lineLimit => displaySize.lineLimit;

  const ItemDisplay({
    super.key,
    required this.path,
    this.titles = const [],
    this.preferSize,
    required this.displaySize,
    this.margin = .zero,
  });

  @override
  State<ItemDisplay> createState() => _ItemDisplayState();
}

class _ItemDisplayState extends State<ItemDisplay> {
  DataType? data;
  bool menuOpen = false;
  bool? expandAll;
  static bool showSorted = false;
  static bool hideEmpty = false;

  bool? lastPreferSize;

  static final Map<String, DisplayType> displayCache = {};

  DisplayStatus get displayStatus => data!.getDisplay(widget.displaySize);

  void updateData(DataType newData) {
    if (data == newData) {
      return;
    }
    menuOpen = false;
    expandAll = null;
    data = newData;
    // use cached display type if available
    final cachedDisplay = displayCache[widget.path.lastNonPivot];
    if (cachedDisplay != null) {
      for (final dt in displayStatus.supported) {
        if (dt.runtimeType == cachedDisplay.runtimeType) {
          dt.copyStyleFrom(cachedDisplay);
          displayStatus.current = dt;
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final backend = getBackend();
    final newData = backend.readCachedData(widget.path);
    if (newData != null) {
      updateData(newData);
    } else {
      backend
          .readData(widget.path)
          .then(updateData)
          .whenComplete(() => setState(() {}));
    }
  }

  void updateDisplayType(DisplayType dt) {
    displayStatus.current = dt;
    displayCache[widget.path.lastNonPivot] = dt;
  }

  @override
  Widget build(BuildContext context) {
    if (data == null || (displayStatus.current is DisplayNone && hideEmpty)) {
      return SizedBox.shrink();
    }
    if (lastPreferSize != widget.preferSize) {
      switch (lastPreferSize = widget.preferSize) {
        case true:
          updateDisplayType(displayStatus.supported.first);
        case false:
          updateDisplayType(displayStatus.supported.last);
        case null:
      }
    }
    if (widget.displaySize == .card) {
      return buildAsCard();
    }
    return buildAsPage();
  }

  Widget buildAsPage() {
    final card = Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      margin: widget.margin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: buildContent(),
    );
    return Column(
      mainAxisSize: .min,
      children: [
        // Option top bar
        buildMenuBar().backgroundColor(
          Theme.of(context).colorScheme.surfaceContainer,
        ),
        // Card content
        nav.expand
            ? card.expanded()
            : card
                  .constrained(minHeight: AppLayout.previewMinHeight)
                  .flexible(),
      ],
    );
  }

  Widget buildAsCard() => Row(
    mainAxisAlignment: .center,
    children: [
      Card(
            margin: widget.margin,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            color: Theme.of(context).colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: .min,
              children: [
                // Option top bar
                buildMenuBar().backgroundColor(
                  Theme.of(context).colorScheme.surfaceDim,
                ),
                // Card content
                buildContent()
                    // .scrollable()
                    .flexible(),
              ],
            ),
          )
          .constrained(maxWidth: AppLayout.centerMaxWidth)
          .constrained(maxHeight: AppLayout.cardMaxHeight)
          .paddingDirectional(horizontal: 16)
          .flexible(),
    ],
  );

  Widget buildMenuBar() {
    return Row(
      children: [
        // left-aligned:
        // close button if applicable
        if (nav.close)
          LabelCard(
            icon: Icons.close,
            tooltip: "close preview",
            inverse: true,
          ).onTap(() => closeCallback()),
        // title if applicable
        for (final text in widget.titles) LabelCard(text: text),
        // space between
        Spacer(),
        // right-aligned:
        // options from display type
        ...buildOptions(),
        // display type switch
        ...displayStatus.supported.map(
          (display) =>
              LabelCard(
                text: display.name,
                inverse: display == displayStatus.current,
              ).onTap(() {
                setState(() => updateDisplayType(display));
              }),
        ),
        // copy button
        if (data is! LiteralNull)
          LabelCard(
            tooltip: data is StructuredData ? "copy as json" : "copy",
            icon: Icons.copy,
          ).onTap(() => copyToClipboard(data.toString())),
        // preview button
        if (nav.preview && data is! LiteralNull)
          LabelCard(
            text: nav.openSelf ? null : "preview",
            tooltip: nav.openSelf ? "preview" : null,
            icon: Icons.open_in_browser,
            inverse: !nav.openSelf,
          ).onTap(() {
            previewCallback(widget.path);
          }),
        // open button
        if (nav.openSelf && data is! LiteralNull)
          LabelCard(
            text: "open",
            icon: Icons.open_in_full,
            inverse: true,
          ).onTap(() {
            openCallback(widget.path);
          }),
      ],
    );
  }

  List<Widget> buildOptions() {
    if (!nav.menu) {
      return [];
    }
    switch (displayStatus.current) {
      case DisplayNone _:
      case DisplayPlain _:
      case DisplayMarkdown _:
      case DisplayCode _:
      case DisplayFold _:
      case DisplayObject _:
        return [];
      case DisplayExpand _:
        return [
          if ((data as StructuredData).isMap)
            LabelCard(
              icon: Icons.sort,
              tooltip: "sort keys",
              inverse: showSorted,
            ).onTap(() => setState(() => showSorted ^= true)),
          if (expandAll == false)
            LabelCard(
              icon: Symbols.expand_all,
              tooltip: "show all",
              inverse: true,
            ).onTap(() => setState(() => expandAll = true)),
          if (expandAll != false)
            LabelCard(
              icon: Symbols.collapse_all,
              tooltip: "fold all",
            ).onTap(() => setState(() => expandAll = false)),
          if (hideEmpty)
            LabelCard(
              icon: Icons.visibility,
              tooltip: "show empty",
              inverse: true,
            ).onTap(() => setState(() => hideEmpty = false)),
          if (!hideEmpty)
            LabelCard(
              icon: Icons.visibility_off,
              tooltip: "hide empty",
            ).onTap(() => setState(() => hideEmpty = true)),
          if ((data as StructuredData).pivotable)
            LabelCard(
              icon: Icons.pivot_table_chart,
              tooltip: "pivot",
            ).onTap(() => autoCallback(widget.path.pivot())),
        ];
      case DisplayWeb display:
        return [
          LabelCard(
            icon: Icons.open_in_new,
            tooltip: "open browser",
          ).onTap(() => launchHtml(display.html)),
        ];
      case DisplayTable display:
        return [
          LabelCard(
            icon: display.isHorizontal
                ? Symbols.splitscreen_right
                : Symbols.splitscreen_bottom,
            tooltip: "toggle layout",
          ).onTap(
            () => setState(() {
              display.previewItem ??= ("", "");
              display.isHorizontal ^= true;
              updateDisplayType(display);
            }),
          ),
          LabelCard(icon: Icons.pivot_table_chart, tooltip: "pivot").onTap(() {
            if (display.previewItem != null) {
              final (row, col) = display.previewItem!;
              display.previewItem = (col, row);
              updateDisplayType(display);
            }
            autoCallback(widget.path.pivot());
          }),
        ];
    }
  }

  Widget buildContent() {
    switch (displayStatus.current) {
      case DisplayNone _:
        return widget.displaySize == .card
            ? SizedBox.shrink()
            : buildPlainText("<empty>", style: AppTextStyles.hint(context));
      case DisplayPlain display:
        return buildPlainText(
          display.content,
          style: display.isHint ? AppTextStyles.hint(context) : null,
        );
      case DisplayMarkdown display:
        return buildMarkdown(display);
      case DisplayCode display:
        return buildHighlighted(display);
      case DisplayFold display:
        return buildPlainText(
          display.content,
          style: AppTextStyles.hint(context),
        );
      case DisplayExpand display:
        return buildList(
          display,
        ).backgroundColor(Theme.of(context).colorScheme.surfaceContainer);
      case DisplayWeb display:
        return buildHtml(display);
      case DisplayObject display:
        return YamlRender(
          display,
          stringLimit: widget.stringLimit,
          contentLimit: widget.lineLimit,
        ).constrained(maxWidth: AppLayout.centerMaxWidth).center().scrollable();
      case DisplayTable display:
        return buildTable(display);
    }
  }
}
