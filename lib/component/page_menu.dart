// Flutter imports:
import "package:flutter/material.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/component/common.dart";
import "package:frontend/styles/base.dart";

class MenuAction {
  final String? name;
  final IconData? icon;
  final bool inverse;
  final bool disabled;
  final void Function() callback;

  const MenuAction({
    this.name,
    this.icon,
    this.inverse = false,
    this.disabled = false,
    this.callback = nullCallback,
  });
}

class PageMenu extends StatefulWidget {
  final bool activated;
  final List<MenuAction> actions;
  const PageMenu({super.key, required this.actions, required this.activated});

  @override
  State<PageMenu> createState() => _PageMenuState();
}

class _PageMenuState extends State<PageMenu> {
  bool isOpen = false;

  void closeMenu([_]) => setState(() => isOpen = false);

  @override
  Widget build(BuildContext context) => !(isOpen |= widget.activated)
      ? SizedBox.shrink()
      : Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: AppLayout.labelHeight),
                IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: widget.actions
                        .map(
                          (action) => LabelCard(
                            text: action.name,
                            icon: action.icon,
                            inverse: action.inverse,
                            disabled: action.disabled,
                            alignment: AlignmentGeometry.centerRight,
                          ).onTap(action.callback),
                        )
                        .toList(),
                  ),
                ),
              ],
            ).onHover((state) {
              if (!state) closeMenu();
            }),
          ],
        );
}
