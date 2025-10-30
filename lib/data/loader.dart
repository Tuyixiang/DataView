// Dart imports:
import "dart:convert";
import "dart:math";
import "dart:typed_data";

// Flutter imports:
import "package:flutter/foundation.dart";

// Package imports:
import "package:csv/csv.dart";
import "package:fpdart/fpdart.dart";
import "package:spreadsheet_decoder/spreadsheet_decoder.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/data/compress/common.dart";

import "package:frontend/data/compress/stub.dart"
    if (dart.library.html) "package:frontend/data/compress/web.dart"
    if (dart.library.io) "package:frontend/data/compress/desktop.dart";

extension ListGetExtension<T> on List<T> {
  T get(int index) => index >= 0 ? this[index] : this[length + index];
  T? getOr(int index, {T? or}) =>
      index < length && index >= -length ? get(index) : or;
  int? index(T element) {
    final found = indexOf(element);
    return found >= 0 ? found : null;
  }
}

List<Map<String, dynamic>>? readFromTable(
  List<List> table, {
  void Function(String) exceptionCallback = nullCallback1,
}) {
  if (table.length < 2) {
    exceptionCallback("csv should contain at least 2 lines");
    return null;
  }
  final width = table.map((e) => e.length).reduce(max);
  final columns = List.generate(
    width,
    (i) => table[0].getOr(i, or: "column-$i").toString(),
  );
  final rows = table.skip(1);
  return rows
      .map((row) => {for (final i in range(width)) columns[i]: row.getOr(i)})
      .toList();
}

Future<Object?> parseData(
  String filename,
  Stream<Uint8List> data, {
  Function(String) exceptionCallback = nullCallback1,
}) async {
  final extension = filename.split(".").last.toLowerCase();
  final baseName = filename.length > extension.length + 1
      ? filename.substring(0, filename.length - extension.length - 1)
      : null;
  try {
    switch (extension) {
      case "txt":
      case "html":
      case "jsx":
      case "md":
        return utf8.decodeStream(data);
      case "json":
        return utf8.decodeStream(data).then(jsonDecode);
      case "jsonl":
        final string = await utf8.decodeStream(data);
        return LineSplitter.split(string).map(jsonDecode).toList();
      case "yml":
      case "yaml":
        return utf8.decodeStream(data).then(yamlDecode);
      case "csv":
        final table = await utf8
            .decodeStream(data)
            .then((text) => text.replaceAll("\r\n", "\n"))
            .then(CsvToListConverter(eol: "\n").convert);
        return readFromTable(table, exceptionCallback: exceptionCallback);
      case "xlsx":
        var excel = SpreadsheetDecoder.decodeBytes(await data.merge());
        final sheets = Map.from(
          excel.tables
              .map(
                (sheetName, sheetData) => MapEntry(
                  sheetName,
                  readFromTable(
                    sheetData.rows
                        .map(
                          (row) => row.map((cell) => cell?.toString()).toList(),
                        )
                        .toList(),
                    exceptionCallback: exceptionCallback,
                  ),
                ),
              )
              .filter((value) => value?.isNotEmpty == true),
        );
        if (sheets.length == 1) {
          return sheets.values.first;
        }
        return sheets;
      case "gz":
      case "gzip":
        if (baseName == null) {
          return exceptionCallback("Unsupported file: $filename");
        }
        return parseData(
          baseName,
          gzipDecompress(data),
          exceptionCallback: exceptionCallback,
        );
      case "zst":
      case "zstd":
        if (baseName == null) {
          return exceptionCallback("Unsupported file: $filename");
        }
        return parseData(
          baseName,
          zstdDecompress(data),
          exceptionCallback: exceptionCallback,
        );
      default:
        return await utf8.decodeStream(data);
        // return exceptionCallback("Unsupported type: $extension");
    }
  } on FormatException catch (e) {
    return exceptionCallback("Failed to read data: ${e.message}");
  } catch (e) {
    return exceptionCallback("Error encountered when reading $filename: $e");
  }
}
