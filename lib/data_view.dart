// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:provider/provider.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/component/item_display.dart";
import "package:frontend/component/path_bread.dart";
import "package:frontend/data/backend/base_backend.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/data/data_type.dart";

class DataView extends StatefulWidget {
  final DataSource initialSource;
  final void Function() exitCallback;

  const DataView({
    super.key,
    required this.initialSource,
    this.exitCallback = nullCallback,
  });

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
      return widget.exitCallback();
    }
    if (path == newPath) {
      return;
    }
    final newData = await (backend ?? context.read<DataSource>().backend!)
        .readData(newPath);
    setState(() {
      pathBreadKey = GlobalKey();
      path = newPath;
      data = newData;
    });
  }

  @override
  Widget build(BuildContext context) => path != null
      ? Stack(
          children: [
            ItemDisplay(
              dataSource: context.watch<DataSource>().backend!,
              path: path!,
              callback: openPath,
            ),
            PathBread(
              key: pathBreadKey,
              dataSource: context.watch<DataSource>().backend!,
              path: path!,
              callback: openPath,
            ),
          ],
        )
      : SizedBox.expand();
}

Future<void> showDataDialog(
  BuildContext context, {
  String? title,
  required dynamic data,
}) {
  final source = DataSource(MemoryBackend.fromObject(data, file: title));
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ChangeNotifierProvider.value(
        value: source,
        child: DataView(
          initialSource: DataSource(
            MemoryBackend.fromObject(data, file: title),
          ),
          exitCallback: () => Navigator.of(context).pop(),
        ),
      ),
    ),
  );
}
