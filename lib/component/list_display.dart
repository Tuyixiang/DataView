part of "item_display.dart";

extension _ListDisplay on _ItemDisplayState {
  Widget buildList(BuildContext context, List<String> keys) => keys.length > 32
      ? ListView.builder(
          key: ValueKey(widget.path),
          itemCount: keys.length,
          cacheExtent: AppLayout.cardMaxHeight * 4,
          itemBuilder: (context, index) => ItemDisplay.card(
            dataSource: widget.dataSource,
            path: widget.path.and(keys[index]),
            title: DataPath.displayKey(keys[index]),
            callback: widget.callback,
            preferSize: expandAll,
          ),
        )
      : Column(
          children: keys
              .map(
                (key) => ItemDisplay.card(
                  dataSource: widget.dataSource,
                  path: widget.path.and(key),
                  title: DataPath.displayKey(key),
                  callback: widget.callback,
                  preferSize: expandAll,
                ),
              )
              .toList(),
        ).scrollable();
}
