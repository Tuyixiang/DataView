part of "item_display.dart";

extension _ListDisplay on _ItemDisplayState {
  Widget _buildItem(int index, String key) => Provider.value(
    value: previewStatus.child(),
    child: ItemDisplay(
      path: widget.path.and(key),
      displaySize: .card,
      titles: [DataPath.displayKey(key)],
      preferSize: expandAll,
      margin: .fromLTRB(0, index == 0 ? 16 : 0, 0, 16),
    ),
  );

  Widget buildList(DisplayExpand display) {
    final keys = _ItemDisplayState.showSorted
        ? display.sortedKeys
        : display.keys;
    return keys.length > 16
        ? ListView.builder(
            key: ValueKey(_ItemDisplayState.showSorted),
            itemCount: keys.length,
            cacheExtent: AppLayout.cardMaxHeight * 4,
            itemBuilder: (context, index) => _buildItem(index, keys[index]),
          )
        : Column(
            key: ValueKey(_ItemDisplayState.showSorted),
            children: [
              for (final index in range(keys.length))
                _buildItem(index, keys[index]),
            ],
          ).scrollable();
  }
}
