// Dart imports:
import "dart:io";
import "dart:typed_data";

const zstdLevel = 3;

Uint8List listToUint8(List<int> list) =>
    list is Uint8List ? list : Uint8List.fromList(list);

Stream<Uint8List> gzipDecompress(Stream<Uint8List> source) async* {
  yield listToUint8(gzip.decode(await source.merge()));
}

extension JoinStreamExtension on Stream<Uint8List> {
  Future<Uint8List> merge() async {
    final builder = BytesBuilder(copy: false);
    await forEach(builder.add);
    return builder.takeBytes();
  }
}
