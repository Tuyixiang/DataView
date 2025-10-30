// Dart imports:
import "dart:typed_data";

// Package imports:
import "package:zstandard_web/zstandard_web.dart";

// Project imports:
import "package:frontend/data/compress/common.dart";

Stream<Uint8List> zstdDecompress(Stream<Uint8List> source) async* {
  final result = await ZstandardWeb().decompress(await source.merge());
  if (result == null) {
    throw FormatException("Zstd decode failed");
  }
  yield result;
}

Stream<Uint8List> zstdCompress(Stream<Uint8List> source) async* {
  final result = await ZstandardWeb().compress(await source.merge(), zstdLevel);
  if (result == null) {
    throw FormatException("Zstd encode failed");
  }
  yield result;
}
