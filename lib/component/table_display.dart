part of "item_display.dart";

class TableDisplay extends StatefulWidget {
  final DataPath path;
  final StructuredData data;
  final List<String> sortedKeys;
  final List<String> columns;
  final void Function(DataPath? path) callback;

  const TableDisplay({
    super.key,
    required this.path,
    required this.data,
    required this.sortedKeys,
    required this.columns,
    this.callback = nullCallback1,
  });

  @override
  State<TableDisplay> createState() => _TableDisplayState();
}

class _TableDisplayState extends State<TableDisplay> {
  static const double defaultWidth = 120;
  late double indexWidth = widget.data.isMap ? defaultWidth : 60;
  late final List<double> columnWidths = List.generate(
    widget.columns.length,
    (_) => max(
      defaultWidth,
      (AppLayout.centerMaxWidth - indexWidth) / widget.columns.length,
    ),
  );

  Widget buildCell(String text, {required TextStyle style}) => Text(
    escapeAllSpecial(text).substring(0, min(text.length, 128)),
    style: style,
    textAlign: .left,
    overflow: .ellipsis,
    maxLines: 1,
    softWrap: false,
  ).paddingDirectional(horizontal: 4);

  Widget buildLabelCell(String text) => buildCell(
    text,
    style: AppTextStyles.monospace.merge(AppTextStyles.boldStyle),
  );

  Widget buildValueCell(DataType data) {
    final theme = Theme.of(context);
    switch (data) {
      case LiteralNull():
        return buildCell(
          "<empty>",
          style: AppTextStyles.monospace.copyWith(
            color: theme.hintColor.withAlpha(48),
            fontStyle: .italic,
          ),
        );
      case LiteralBool():
      case LiteralNum():
        return buildCell(
          data.toString(),
          style: AppTextStyles.monospace.copyWith(color: theme.primaryColor),
        );
      case MarkdownString():
      case CodeString():
      case MixedWebString():
      case WebString():
        final text = data.toString();
        return buildCell(
          text.substring(0, min(text.length, 128)),
          style: AppTextStyles.monospace,
        );
      case StructuredData data:
        return buildCell(
          data.isMap ? "<map>" : "<list>",
          style: AppTextStyles.monospace.copyWith(color: theme.hintColor),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TableView.builder(
      columns: [
        TableColumn(width: indexWidth, sticky: true, freezePriority: 100),
        for (var i in range(widget.columns.length))
          TableColumn(width: columnWidths[i]),
      ],
      rowCount: widget.sortedKeys.length,
      rowHeight: AppTextStyles.defaultSize * 1.5,
      rowBuilder: (BuildContext context, int row, contentBuilder) {
        return contentBuilder(context, (context, column) {
          final key = widget.sortedKeys[row];
          if (column == 0) {
            return buildLabelCell(
              key,
            ).onTap(() => showDataDialog(context, data: widget.data[key]));
          }
          final rowData = widget.data[key].unwrap() as StructuredData;
          final data = rowData[widget.columns[column - 1]].unwrap();
          return buildValueCell(data).onTap(() {
            if (data is! LiteralNull) {
              showDataDialog(context, data: data);
            }
          });
        });
      },
      headerBuilder: (context, contentBuilder) =>
          contentBuilder(context, (context, column) {
            if (column == 0) {
              return buildLabelCell("index");
            }
            final col = widget.columns[column - 1];
            return buildLabelCell(col).onTap(
              () => showDataDialog(context, data: widget.data.pivot[col]),
            );
          }),
    ).paddingDirectional(all: 8);
  }
}

extension _TableDisplay on _ItemDisplayState {
  Widget buildTable(
    BuildContext context, {
    required List<String> sortedKeys,
    required List<String> columns,
  }) {
    final d = data! as StructuredData;
    return TableDisplay(
      path: widget.path,
      data: d,
      sortedKeys: sortedKeys,
      columns: columns,
      callback: widget.callback,
    );
  }
}
