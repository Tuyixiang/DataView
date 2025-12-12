// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:provider/provider.dart";

// Project imports:
import "package:frontend/component/common.dart";
import "package:frontend/component/item_display.dart";
import "package:frontend/component/path_bread.dart";
import "package:frontend/data/backend/base_backend.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/data/data_type.dart";
import "package:frontend/overlay.dart";

class DataView extends StatefulWidget {
  final DataSource initialSource;
  final bool expand;

  const DataView({super.key, required this.initialSource, this.expand = true});

  @override
  State<DataView> createState() => _ViewState();
}

class _ViewState extends State<DataView> {
  DataType? data;
  DataPath? path;
  GlobalKey? pathBreadKey;

  @override
  void initState() {
    super.initState();
    openPath(
      widget.initialSource.initialPath,
      backend: widget.initialSource.backend,
    );
  }

  void openPath(DataPath? newPath, {Backend? backend}) async {
    if (newPath == null) {
      return closeCallback();
    }
    if (path == newPath) {
      return;
    }
    final newData = await (backend ?? getBackend()).readData(newPath);
    setState(() {
      pathBreadKey = GlobalKey();
      path = newPath;
      data = newData;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return SizedBox.expand();
    }
    final child = Stack(
      children: [
        ItemDisplay(
          key: ValueKey((watchBackend(), path)),
          path: path!,
          titles: path!.isEmpty ? [] : [path!.last],
          displaySize: .page,
        ),
        PathBread(key: pathBreadKey, path: path!),
      ],
    );
    return Provider.value(
      value: previewStatus.child(
        openCallback: (path, {backend}) {
          openPath(path, backend: backend);
          previewCallback(null);
        },
      ),
      child: child,
    );
  }
}
