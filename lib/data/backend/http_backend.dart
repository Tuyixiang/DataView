// Dart imports:
import "dart:typed_data";

// Package imports:
import "package:http/http.dart" as http;
import "package:msgpack_dart/msgpack_dart.dart" as msgpack;

// Project imports:
import "package:frontend/data/data_path.dart";
import "package:frontend/data/data_type.dart";
import "package:frontend/data/loader.dart";
import "base_backend.dart";

class CachedHttpBackend extends Backend {
  final Map<DataPath, Future<dynamic>> httpCache = {};

  final Uri uri;

  CachedHttpBackend(this.uri, {String? initialPath}) {
    readDataInternal(DataPath(initialPath));
  }

  @override
  Future<Uri> toUri() => Future.sync(() => uri);

  @override
  Future<Object?> readDataInternal(DataPath path) =>
      httpCache.putIfAbsent(path, () async {
        final resp = await http.get(uri);
        if (resp.statusCode != 200) {
          return MarkdownString("""
## Cannot find data

```yaml
file: $file
path: $path
tried_uri: $uri
```
""");
        }
        final data = msgpack.deserialize(resp.bodyBytes);
        if (data is Uint8List) {
          return parseData(
            uri.path,
            (() async* {
              yield data;
            })(),
            exceptionCallback: (msg) => MarkdownString(msg),
          );
        }
        return data;
      });
}
