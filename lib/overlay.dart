// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:provider/provider.dart";

// Project imports:
import "package:frontend/component/common.dart";
import "package:frontend/component/item_display.dart";
import "package:frontend/data/backend/base_backend.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/styles/base.dart";

enum NavigationStatus {
  main(preview: true, close: true, child: top),
  top(
    open: true,
    close: true,
    menu: true,
    expand: true,
    makeSub: true,
    child: topChild,
  ),
  topChild(open: true, openSelf: true, menu: true, child: topGrandchild),
  topGrandchild(preview: true),
  sub(
    open: true,
    openSelf: true,
    preview: true,
    close: true,
    menu: true,
    child: subChild,
  ),
  subChild(preview: true),
  overlay(close: true, menu: true, child: overlayChild),
  overlayChild(preview: true),
  hint(close: true);

  final bool open;
  final bool openSelf;
  final bool preview;
  final bool close;
  final bool menu;
  final bool expand;
  final bool makeSub;
  final NavigationStatus? _child;

  const NavigationStatus({
    this.open = false,
    this.openSelf = false,
    this.preview = false,
    this.close = false,
    this.menu = false,
    this.expand = false,
    this.makeSub = false,
    NavigationStatus? child,
  }) : _child = child;

  NavigationStatus get child => _child ?? this;
}

final class PreviewStatus {
  final NavigationStatus nav;
  final void Function(DataPath, {Backend? backend})? openCallback;
  final void Function(DataPath?, {Backend? backend})? previewCallback;
  final void Function()? closeCallback;

  PreviewStatus({
    required this.nav,
    this.openCallback,
    this.previewCallback,
    this.closeCallback,
  });

  PreviewStatus copyWith({
    NavigationStatus? nav,
    void Function(DataPath, {Backend? backend})? openCallback,
    void Function(DataPath?, {Backend? backend})? previewCallback,
    void Function()? closeCallback,
  }) => PreviewStatus(
    nav: nav ?? this.nav,
    openCallback: openCallback ?? this.openCallback,
    previewCallback: previewCallback ?? this.previewCallback,
    closeCallback: closeCallback ?? this.closeCallback,
  );

  PreviewStatus child({
    void Function(DataPath, {Backend? backend})? openCallback,
    void Function(DataPath?, {Backend? backend})? previewCallback,
    void Function()? closeCallback,
  }) => copyWith(
    nav: nav.child,
    openCallback: openCallback,
    previewCallback: previewCallback,
    closeCallback: closeCallback,
  );
}

extension OverlayStatusExt on State {
  PreviewStatus get previewStatus =>
      Provider.of<PreviewStatus>(context, listen: false);
  NavigationStatus get nav => previewStatus.nav;
  void Function(DataPath, {Backend? backend}) get openCallback =>
      previewStatus.openCallback!;
  void Function(DataPath?, {Backend? backend}) get previewCallback =>
      previewStatus.previewCallback!;
  void Function() get closeCallback => previewStatus.closeCallback!;
  void autoCallback(DataPath? path, {Backend? backend}) {
    if (path == null) {
      if (nav.close) {
        closeCallback();
      }
    } else if (nav.open) {
      openCallback(path, backend: backend);
    } else if (nav.preview) {
      previewCallback(path, backend: backend);
    }
  }
}

class OverlayView extends StatefulWidget {
  final DataSource? source;

  OverlayView({required this.source}) : super(key: ValueKey(source));

  @override
  State<OverlayView> createState() => _OverlayViewState();
}

class _OverlayViewState extends State<OverlayView> {
  late final Widget? itemDisplay = widget.source == null
      ? null
      : ChangeNotifierProvider.value(
          value: widget.source!,
          child: ItemDisplay(
            key: widget.key,
            path: widget.source!.initialPath,
            titles: [
              widget.source!.backend!.file ?? "data",
              if (widget.source!.initialPath.isNotEmpty) ...[
                ">",
                widget.source!.initialPath.path,
              ],
            ],
            displaySize: .preview,
          ),
        );

  @override
  Widget build(BuildContext context) {
    if (itemDisplay == null) {
      return SizedBox.shrink();
    }
    return Stack(
      children: [
        Container(
          color: Theme.of(context).disabledColor.withAlpha(128),
        ).onTap(() => previewCallback(null)),
        Dialog(
          alignment: .center,
          constraints: .new(maxWidth: AppLayout.centerMaxWidth),
          clipBehavior: Clip.antiAlias,
          insetPadding: EdgeInsets.all(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Provider.value(
            value: previewStatus.copyWith(
              nav: .overlay,
              closeCallback: () => previewCallback(null),
            ),
            child: itemDisplay,
          ),
        ),
      ],
    );
  }
}
