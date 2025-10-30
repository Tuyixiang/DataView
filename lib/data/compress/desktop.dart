// Dart imports:
import "dart:typed_data";

// Package imports:
import "package:es_compression/zstd.dart";

// Project imports:
import "package:frontend/data/compress/common.dart";

Stream<Uint8List> zstdDecompress(Stream<Uint8List> source) async* {
  yield listToUint8(zstd.decode(await source.merge()));
}

Stream<Uint8List> zstdCompress(Stream<Uint8List> source) async* {
  yield listToUint8(zstd.encode(await source.merge()));
}
