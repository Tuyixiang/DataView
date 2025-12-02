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
import "package:frontend/component/page_menu.dart";
import "package:frontend/component/text/escape.dart";
import "package:frontend/component/web_view.dart";
import "package:frontend/component/yaml_render.dart";
import "package:frontend/data/backend/base_backend.dart";
import "package:frontend/data/common.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/data/data_type.dart";
import "package:frontend/data_view.dart";
import "package:frontend/styles/base.dart";

import "package:frontend/data/code_run/stub.dart"
    if (dart.library.io) "package:frontend/data/code_run/desktop.dart"
    if (dart.library.html) "package:frontend/data/code_run/web.dart";

part "table_display.dart";
part "text_display.dart";
part "list_display.dart";
part "web_display.dart";

class ItemDisplay extends StatefulWidget {
  final Backend dataSource;
  final DataPath path;
  final String? title;
  final DisplaySizeEnum displaySize;
  final bool? preferSize;
  final void Function(DataPath?) callback;

  int get charLimit => displaySize.charLimit;
  int get stringLimit => displaySize.stringLimit;
  int get lineLimit => displaySize.lineLimit;

  ItemDisplay({
    required this.dataSource,
    required this.path,
    this.title,
    this.callback = nullCallback1,
    this.preferSize,
    this.displaySize = .page,
  }) : super(key: ValueKey((dataSource, path)));

  ItemDisplay.card({
    required this.dataSource,
    required this.path,
    this.title,
    this.callback = nullCallback1,
    this.preferSize,
  }) : displaySize = .card,
       super(key: ValueKey((dataSource, path)));

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
    final cachedDisplay = displayCache[widget.title];
    for (final dt in displayStatus.supported) {
      if (dt == cachedDisplay) {
        displayStatus.current = dt;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final newData = widget.dataSource.readCachedData(widget.path);
    if (newData != null) {
      updateData(newData);
    } else {
      widget.dataSource
          .readData(widget.path)
          .then(updateData)
          .whenComplete(() => setState(() {}));
    }
  }

  void updateDisplayType(DisplayType dt) {
    displayStatus.current = dt;
    if (widget.title != null) {
      displayCache[widget.title!] = dt;
    }
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
      return buildAsCard(context);
    }
    return Stack(
      children: [
        buildAsPage(context),
        if (data is StructuredData)
          PageMenu(
            actions: [
              MenuAction(
                name: "Sort Keys",
                icon: Icons.sort,
                callback: () => setState(() => showSorted ^= true),
                inverse: (showSorted && (data as StructuredData).isMap),
                disabled: !(data as StructuredData).isMap,
              ),
              expandAll == false
                  ? MenuAction(
                      name: "Show All",
                      icon: Symbols.expand_all,
                      callback: () => setState(() => expandAll = true),
                      inverse: true,
                      disabled: data is! StructuredData,
                    )
                  : MenuAction(
                      name: "Fold All",
                      icon: Symbols.collapse_all,
                      callback: () => setState(() => expandAll = false),
                    ),
              hideEmpty
                  ? MenuAction(
                      name: "Show Empty",
                      icon: Icons.visibility,
                      callback: () => setState(() => hideEmpty = false),
                      inverse: true,
                    )
                  : MenuAction(
                      name: "Hide Empty",
                      icon: Icons.visibility_off,
                      callback: () => setState(() => hideEmpty = true),
                    ),
              MenuAction(
                name: "Pivot",
                icon: Icons.pivot_table_chart,
                disabled: !(data as StructuredData).pivotable,
                callback: () => widget.callback(widget.path.pivot()),
                inverse: widget.path.isPivot,
              ),
            ],
            activated: menuOpen,
          ),
      ],
    );
  }

  Widget buildTitle(BuildContext context) => LabelCard(text: widget.title!);

  Widget buildAsPage(BuildContext context) => Column(
    children: [
      // Option top bar
      buildMenuBar(
        context,
      ).backgroundColor(Theme.of(context).colorScheme.surfaceContainer),
      // Card content
      Card(
        color: Theme.of(context).colorScheme.surface,
        margin: EdgeInsetsGeometry.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: buildContent(context),
      ).expanded(),
    ],
  );

  Widget buildAsCard(BuildContext context) =>
      Card(
            margin: EdgeInsets.only(top: 12, bottom: 4),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            color: Theme.of(context).colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Option top bar
                buildMenuBar(
                  context,
                ).backgroundColor(Theme.of(context).colorScheme.surfaceDim),
                // Card content
                buildContent(
                  context,
                ).scrollable().constrained(maxHeight: AppLayout.cardMaxHeight),
              ],
            ),
          )
          .constrained(maxWidth: AppLayout.centerMaxWidth)
          .paddingDirectional(horizontal: 16)
          .center();

  Widget buildMenuBar(BuildContext context) => Row(
    children: [
      // left-aligned:
      // title if applicable
      if (widget.title != null) buildTitle(context),
      // space between
      Spacer(),
      // right-aligned:
      // open browser button
      if (displayStatus.current.supportBrowserOpen)
        LabelCard(text: "open browser", icon: Icons.open_in_browser).onTap(() {
          launchHtml(displayStatus.current.browserOpenHtml);
        }),
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
      LabelCard(
        icon: Icons.copy,
      ).onTap(() => copyToClipboard(context: context, text: data.toString())),
      // open button
      if (widget.displaySize == .card)
        LabelCard(text: "open", icon: Icons.open_in_full, inverse: true).onTap(
          () {
            widget.callback(widget.path);
          },
        ),
      // menu button
      if (widget.displaySize == .page && data is StructuredData)
        LabelCard(
          text: "options",
          icon: Icons.more_horiz,
          inverse: true,
        ).onHover((state) {
          if (state != menuOpen) setState(() => menuOpen = state);
        }),
    ],
  );

  Widget buildContent(BuildContext context) {
    switch (displayStatus.current) {
      case DisplayNone _:
        return widget.displaySize == .card
            ? SizedBox.shrink()
            : buildPlainText(
                context,
                "<empty>",
                style: AppTextStyles.hint(context),
              );
      case DisplayPlain display:
        return buildPlainText(
          context,
          display.content,
          style: display.isHint ? AppTextStyles.hint(context) : null,
        );
      case DisplayMarkdown display:
        return buildMarkdown(context, display.content);
      case DisplayCode display:
        return buildHighlighted(context, display.content, display.lang);
      case DisplayFold display:
        return buildPlainText(
          context,
          display.content,
          style: AppTextStyles.hint(context),
        );
      case DisplayExpand display:
        return buildList(
          context,
          (showSorted && (data as StructuredData).isMap)
              ? display.sortedKeys
              : display.keys,
        ).backgroundColor(Theme.of(context).colorScheme.surfaceContainer);
      case DisplayWeb display:
        return buildHtml(context, display.html);
      case DisplayObject display:
        return YamlRender(
          display.data,
          stringLimit: widget.stringLimit,
          contentLimit: widget.lineLimit,
        ).constrained(maxWidth: AppLayout.centerMaxWidth).center().scrollable();
      case DisplayTable display:
        return buildTable(
          context,
          sortedKeys: display.sortedKeys,
          columns: display.columns,
        );
    }
  }
}
