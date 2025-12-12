// Dart imports:
import "dart:math";

// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:styled_widget/styled_widget.dart";

// Project imports:
import "package:frontend/component/common.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/overlay.dart";
import "package:frontend/styles/base.dart";

class DropMenuInfo {
  Widget? widget;
  final DataPath parent;
  String? select;
  final List<String> keys;
  final double horizontalOffset;

  DropMenuInfo({
    required this.parent,
    required this.select,
    required this.keys,
    required this.horizontalOffset,
  });
}

/// Breadcrumbles to display the path
///
/// Should be used as Stack overlay. Will show at the top-left corner
class PathBread extends StatefulWidget with PositionInspect {
  final DataPath path;

  const PathBread({super.key, required this.path});

  @override
  State<PathBread> createState() => _PathBreadState();
}

class _PathBreadState extends State<PathBread> {
  DropMenuInfo? dropMenu;
  ScrollController menuController = ScrollController();
  static const dropMenuLines = 10;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        buildRow(context, widget.path),
        if (dropMenu != null) buildMenu(context).expanded(),
      ],
    );
  }

  void closeMenu([_]) => setState(() {
    dropMenu = null;
  });

  void openMenu(
    DataPath parent,
    String name,
    PositionInspect clickedWidget,
  ) async {
    // Try to measure the offset to put menu
    final widgetX = clickedWidget.renderPosition?.dx;
    final selfX = widget.renderPosition?.dx;
    final keys = await getBackend().listKeys(parent);
    if ([widgetX, selfX, keys].contains(null)) {
      return;
    }
    final offset = widgetX! - selfX!;
    // Compute offset to reveal selected item
    final index = keys.indexOf(name);
    final scrollOffset =
        AppLayout.labelHeight *
        max(min(index - dropMenuLines / 4, keys.length - dropMenuLines), 0);
    // Open menu
    setState(() {
      if (dropMenu == null || !menuController.hasClients) {
        // New menu: set initialScrollOffset
        menuController = ScrollController(initialScrollOffset: scrollOffset);
      } else {
        // Existing menu: jump to offset
        menuController.jumpTo(scrollOffset);
      }
      dropMenu = DropMenuInfo(
        parent: parent,
        select: name,
        keys: keys,
        horizontalOffset: offset,
      );
    });
  }

  Widget buildRow(BuildContext context, DataPath path) => Row(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      // Close button
      LabelCard(
        icon: Icons.close,
        tooltip: "close file",
        inverse: true,
      ).onTap(() => closeCallback()),
      // Back button
      LabelCard(
        icon: Icons.arrow_upward,
        tooltip: path.isNotEmpty ? "parent" : null,
        disabled: path.isEmpty,
      ).onTap(path.isEmpty ? () {} : () => openCallback(path.parent!)),
      // File
      LabelCard(
        text: watchBackend().file ?? "data",
        maxLength: 16,
      ).onTap(() => openCallback(const DataPath(""))),
      // Paths
      ...path.iterate().expand((path) {
        late final PositionInspect card;
        final isPivot = path.isPivot;
        final labelCard = isPivot
            ? LabelCard(icon: Icons.pivot_table_chart)
            : LabelCard(
                text: path.last,
                maxLength: 16,
                inverse: path.parent == dropMenu?.parent,
              );
        card = InspectableContainer(
          child: MouseRegion(
            onHover: (_) {
              if (!isPivot) {
                openMenu(path.parent!, path.last, card);
              }
            },
            child: labelCard.onTap(() => openCallback(path)),
          ),
        );
        return [LabelCard(text: ">"), card];
      }),
    ],
  );

  Widget buildMenu(BuildContext context) => Column(
    children: [
      Row(
        crossAxisAlignment: .start,
        children: [
          SizedBox(
            width: dropMenu!.horizontalOffset,
            height: .infinity,
          ).onHover(closeMenu),
          Row(
            mainAxisSize: .min,
            children: [
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: .stretch,
                  mainAxisSize: .min,
                  children: dropMenu!.keys
                      .map(
                        (key) =>
                            LabelCard(
                              text: DataPath.displayKey(key),
                              inverse: key == dropMenu!.select,
                              alignment: Alignment.centerLeft,
                            ).onTap(() {
                              openCallback(dropMenu!.parent.and(key));
                            }),
                      )
                      .toList(),
                ),
              ),
              // This space makes scroll bar go outside of labels
              SizedBox(width: 12),
            ],
          ).scrollable(controller: menuController),
          SizedBox.expand().onHover(closeMenu).expanded(),
        ],
      ).constrained(maxHeight: AppLayout.labelHeight * dropMenuLines),
      SizedBox.expand().onHover(closeMenu).expanded(),
    ],
  );
}
