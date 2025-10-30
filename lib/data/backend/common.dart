// Dart imports:
import "dart:convert";

// Project imports:
import "package:frontend/data/compress/common.dart";
import "package:frontend/data/data_type.dart";

import "package:frontend/data/compress/stub.dart"
    if (dart.library.html) "package:frontend/data/compress/web.dart"
    if (dart.library.io) "package:frontend/data/compress/desktop.dart";

Future<Uri> objectToUri(dynamic object) async {
  final json = jsonEncode(object is DataType ? object.encodable : object);
  return Uri.dataFromBytes(
    await zstdCompress(Stream.value(utf8.encode(json))).merge(),
  );
}

Future<dynamic> uriToObject(Uri uri) async {
  final json = await utf8.decodeStream(
    zstdDecompress(Stream.value(uri.data!.contentAsBytes())),
  );
  return jsonDecode(json);
}
