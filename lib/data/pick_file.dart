// Dart imports:
import "dart:io";

// Flutter imports:
import "package:flutter/foundation.dart";

// Package imports:
import "package:file_picker/file_picker.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/data/compress/common.dart";

class FileContent {
  final String name;
  final String? path;
  final Stream<Uint8List> stream;

  FileContent({String? name, this.path, Stream<Uint8List>? stream})
    : name = name ?? path?.split("/").last ?? "",
      stream = stream ?? File(path!).openRead().map(listToUint8);
}

Future<List<FileContent>> pickFiles({
  String? title,
  List<String>? extensions,
  bool allowMultiple = false,
}) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: title,
    allowedExtensions: extensions,
    allowMultiple: allowMultiple,
    withData: kIsWeb,
  );
  return (result?.files ?? [])
      .map(
        (file) => FileContent(
          name: file.name,
          path: file.path,
          stream:
              file.readStream?.map(listToUint8) ??
              file.bytes?.call(Stream.value),
        ),
      )
      .toList();
}
