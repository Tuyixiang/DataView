part of "item_display.dart";

class PreviewItem {
  final String row;
  final String col;
  final Widget item;

  PreviewItem({required this.row, required this.col, required this.item});
}

class TableDisplay extends StatefulWidget {
  final DataPath path;
  final StructuredData data;
  final DisplayTable display;

  const TableDisplay({
    super.key,
    required this.path,
    required this.data,
    required this.display,
  });

  @override
  State<TableDisplay> createState() => _TableDisplayState();
}

class _TableDisplayState extends State<TableDisplay> {
  static const double defaultWidth = 120;
  late double indexWidth = widget.data.isMap ? defaultWidth : 60;
  late final List<double> columnWidths = List.generate(
    columns.length,
    (_) => max(
      defaultWidth,
      (AppLayout.centerMaxWidth - indexWidth) / columns.length,
    ),
  );

  List<String> get columns => widget.display.columns;
  List<String> get sortedKeys => widget.display.sortedKeys;

  PreviewItem? previewItem;

  void updatePreviewItem(PreviewItem? preview, {bool rebuild = false}) {
    previewItem = preview;
    if (previewItem == null) {
      widget.display.previewItem = null;
    } else {
      widget.display.previewItem = (previewItem!.row, previewItem!.col);
    }
    if (rebuild) {
      setState(() {});
    }
  }

  PreviewItem? buildPreview(String row, String col) {
    if (row.isEmpty && col.isEmpty) {
      return PreviewItem(
        row: "",
        col: "",
        item: Provider.value(
          value: PreviewStatus(
            nav: .hint,
            openCallback: openCallback,
            previewCallback: previewCallback,
            closeCallback: () => updatePreviewItem(null, rebuild: true),
          ),
          child: ChangeNotifierProvider.value(
            value: DataSource(
              MemoryBackend.fromObject("Click on any cell to preview data."),
            ),
            child: ItemDisplay(
              path: const DataPath(""),
              displaySize: .preview,
              titles: ["hint"],
            ),
          ),
        ),
      );
    }
    if (!widget.data.firstLevelKeys.contains(row) ||
        !(widget.data[row].unwrap() as StructuredData).firstLevelKeys.contains(
          col,
        )) {
      return null;
    }
    final path = widget.path.and(row).and(col);
    return PreviewItem(
      row: row,
      col: col,
      item: Provider.value(
        value: PreviewStatus(
          nav: .sub,
          openCallback: openCallback,
          previewCallback: previewCallback,
          closeCallback: () => updatePreviewItem(null, rebuild: true),
        ),
        child: ItemDisplay(
          key: ValueKey(path),
          path: path,
          displaySize: .preview,
          titles: [row, ">", col],
        ),
      ),
    );
  }

  void openPreview(String row, String col) {
    final path = widget.path.and(row).and(col);
    if (!nav.makeSub) {
      previewCallback(path);
    } else {
      setState(() => updatePreviewItem(buildPreview(row, col), rebuild: true));
    }
  }

  Color? getHighlight({String? row, String? col}) {
    if (previewItem == null || (row ?? col) == null) {
      return null;
    }
    if ((row == null || row == previewItem!.row) &&
        (col == null || col == previewItem!.col)) {
      return Theme.of(context).highlightColor.withAlpha(128);
    }
    return null;
  }

  Widget buildCell(
    String text, {
    required TextStyle style,
    String? row,
    String? col,
  }) => Container(
    padding: .symmetric(horizontal: 4),
    color: getHighlight(row: row, col: col),
    child: Text(
      escapeAllSpecial(
        text.substring(0, min(text.length, 80)).split("\n").first,
      ),
      style: style,
      textAlign: .left,
      overflow: .ellipsis,
      maxLines: 1,
      softWrap: false,
    ),
  );

  Widget buildLabelCell(String text, {String? row, String? col}) => buildCell(
    text,
    style: AppTextStyles.monospace.merge(AppTextStyles.boldStyle),
    row: row,
    col: col,
  );

  Widget buildValueCell(DataType data, {String? row, String? col}) {
    final theme = Theme.of(context);
    switch (data) {
      case LiteralNull():
        return buildCell(
          "<empty>",
          style: AppTextStyles.monospace.copyWith(
            color: theme.hintColor.withAlpha(48),
            fontStyle: .italic,
          ),
          row: row,
          col: col,
        );
      case LiteralBool():
      case LiteralNum():
        return buildCell(
          data.toString(),
          style: AppTextStyles.monospace.copyWith(color: theme.primaryColor),
          row: row,
          col: col,
        );
      case MarkdownString():
      case CodeString():
      case MixedWebString():
      case WebString():
        final text = data.toString();
        return buildCell(
          text.substring(0, min(text.length, 128)),
          style: AppTextStyles.monospace,
          row: row,
          col: col,
        );
      case StructuredData data:
        return buildCell(
          data.isMap ? "<map>" : "<list>",
          style: AppTextStyles.monospace.copyWith(color: theme.hintColor),
          row: row,
          col: col,
        );
    }
  }

  Widget buildTable(BuildContext context) => TableView.builder(
    columns: [
      TableColumn(width: indexWidth, sticky: true, freezePriority: 100),
      for (var i in range(columns.length)) TableColumn(width: columnWidths[i]),
    ],
    rowCount: sortedKeys.length,
    rowHeight: AppTextStyles.defaultSize * 1.5,
    rowBuilder: (BuildContext context, int rowIndex, contentBuilder) {
      return contentBuilder(context, (context, colIndex) {
        final row = sortedKeys[rowIndex];
        if (colIndex == 0) {
          return buildLabelCell(
            row,
            row: row,
          ).onTap(() => autoCallback(widget.path.and(row)));
        }
        final col = columns[colIndex - 1];
        final rowData = widget.data[row].unwrap() as StructuredData;
        final data = rowData[col].unwrap();
        return buildValueCell(data, row: row, col: col).onTap(() {
          if (data is! LiteralNull) {
            openPreview(row, col);
          }
        });
      });
    },
    headerBuilder: (context, contentBuilder) =>
        contentBuilder(context, (context, colIndex) {
          if (colIndex == 0) {
            return buildLabelCell("index");
          }
          final col = columns[colIndex - 1];
          return buildLabelCell(
            col,
            col: col,
          ).onTap(() => autoCallback(widget.path.pivot().and(col)));
        }),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.display.previewItem != null && previewItem == null) {
      final (row, col) = widget.display.previewItem!;
      previewItem = buildPreview(row, col);
    }
    updatePreviewItem(previewItem);
    if (widget.display.isHorizontal) {
      return LayoutBuilder(
        builder: (context, constraints) => Flex(
          direction: .vertical,
          children: [
            buildTable(context)
                .paddingDirectional(
                  horizontal: 8,
                  top: 8,
                  bottom: previewItem == null ? 8 : 0,
                )
                .expanded(),
            if (previewItem != null)
              Container(
                child: previewItem!.item.constrained(
                  maxHeight: constraints.maxHeight / 2,
                ),
              ),
          ],
        ),
      );
    } else {
      return LayoutBuilder(
        builder: (context, constraints) => Flex(
          direction: .horizontal,
          children: [
            buildTable(context)
                .paddingDirectional(
                  start: 8,
                  vertical: 8,
                  end: previewItem == null ? 8 : 0,
                )
                .expanded(),
            if (previewItem != null)
              Container(
                alignment: .topCenter,
                child: previewItem!.item.constrained(
                  maxWidth: min(
                    constraints.maxWidth / 2,
                    AppLayout.centerMaxWidth,
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }
}

extension _TableDisplay on _ItemDisplayState {
  Widget buildTable(DisplayTable display) {
    final d = data! as StructuredData;
    return TableDisplay(
      key: ValueKey((getBackend(), widget.path)),
      path: widget.path,
      data: d,
      display: display,
    );
  }
}
