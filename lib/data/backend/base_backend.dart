// Dart imports:
import "dart:io";

// Flutter imports:
import "package:flutter/material.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/data/backend/common.dart";
import "package:frontend/data/backend/http_backend.dart";
import "package:frontend/data/common.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/data/data_type.dart";
import "package:frontend/data/loader.dart";
import "package:frontend/data/sample_data.dart";

final class DataSource extends ChangeNotifier {
  Backend? backend;
  DataPath initialPath;

  DataSource([this.backend, String? initialPath])
    : initialPath = DataPath(initialPath);

  static Future<DataSource> fromFile(
    String? path, {
    String? initialPath,
  }) async =>
      DataSource(await Backend.fromUri(path?.call(Uri.file)), initialPath);

  static Future<DataSource> fromUrl(String? url, {String? initialPath}) async =>
      DataSource(
        await Backend.fromUri(await Backend.parseUrl(url), initialPath),
        initialPath,
      );

  void update([Backend? backend, String? initialPath]) {
    this.backend = backend;
    this.initialPath = DataPath(initialPath);
    notifyListeners();
  }

  bool get isEmpty => backend == null;
  bool get isNotEmpty => backend != null;
}

abstract class Backend {
  /// Name of data source
  final String? file;

  /// Cache implemented in the [Backend] interface
  final Map<DataPath, Lazy<DataType>> dataCache = {};

  Backend({this.file});

  static Future<Backend?> fromUriString(String? str, [String? initialPath]) {
    if (str?.isNotEmpty != true) {
      return Future.sync(() => null);
    }
    return fromUri(Uri.tryParse(str!), initialPath);
  }

  static Future<Backend?> fromUri(Uri? uri, [String? initialPath]) async {
    if (uri == null) {
      return null;
    }
    if (uri.data != null) {
      return MemoryBackend.fromObject(await uriToObject(uri));
    }
    switch (uri.scheme) {
      case "file":
        final filePath = uri.toFilePath();
        final data = await parseData(
          filePath,
          File(filePath).openRead().cast(),
        );
        return MemoryBackend(data, filePath: filePath);
      case "http":
      case "https":
      case "":
        return CachedHttpBackend(uri, initialPath: initialPath);
      default:
        throw UnimplementedError("Unsupported uri scheme ${uri.scheme}");
    }
  }

  /// Parse a non-file path (maybe http relative path)
  static Future<Uri?> parseUrl(String? path) {
    if (path == null) return Future.sync(() => null);
    try {
      if (path == readmeFile) {
        return MemoryBackend.fromObject(readmeData, file: readmeTitle).toUri();
      } else if (path.startsWith("http://") ||
          path.startsWith("https://") ||
          path.startsWith("/")) {
        return Future.sync(() => Uri.parse(path));
      } else {
        return Future.sync(() => Uri.parse("/$path"));
      }
    } on FormatException catch (_) {
      return Future.sync(() => null);
    }
  }

  Future<Uri> toUri() => throw UnimplementedError();

  /// Returns a cached value for [path] if available.
  ///
  /// Looks up an exact cache hit first. If not found, it attempts to
  /// resolve from a cached ancestor by reading the parent structure and
  /// indexing into it using the last segment of [path]. Returns `null`
  /// when the data is not present in the cache.
  DataType? readCachedData(DataPath path) =>
      dataCache[path]?.unwrap() ??
      (path.parent?.call(readCachedData) as StructuredData?)?[path.last]
          .unwrap();

  /// Reads data for [path], using cache when possible.
  ///
  /// If the value is cached, completes synchronously with the cached value.
  /// Otherwise calls [readDataInternal], converts the result to a [DataType],
  /// stores it in the cache, and returns the materialized value.
  Future<DataType> readData(DataPath path) {
    final cached = readCachedData(path);
    if (cached != null) {
      return Future.sync(() => cached);
    }
    return readDataInternal(path)
        .then(DataType.deduce)
        .then((obj) => updateData(path, Lazy.value(obj)).unwrap());
  }

  /// Lists first-level keys for the structure at [path].
  ///
  /// If the structure is cached, returns its keys immediately; otherwise
  /// defers to [listKeysInternal].
  Future<List<String>> listKeys(DataPath path) {
    final cached = readCachedData(path);
    if (cached != null) {
      return Future.sync(() => (cached as StructuredData).firstLevelKeys);
    }
    return listKeysInternal(path);
  }

  /// Updates the cache at [path] with [data] and invalidates descendants.
  ///
  /// Removes any cached entries that are children of [path] to keep the
  /// cache coherent, then stores and returns the provided lazy value.
  Lazy<DataType> updateData(DataPath path, Lazy<DataType> data) {
    if (dataCache.containsKey(path)) {
      dataCache.removeWhere((key, _) => path.isAncestorOf(key));
    }
    return dataCache[path] = data;
  }

  /// Backend-specific implementation to load raw data for [path].
  ///
  /// Implementations may return any JSON-like object; the result is later
  /// converted to a [DataType] by the caller.
  Future<Object?> readDataInternal(DataPath path);

  /// Backend-specific implementation to list keys at [path].
  ///
  /// The default implementation reads the data and extracts the first-level
  /// keys from the resulting [StructuredData]. Backends can override for
  /// efficiency when listing keys is cheaper than reading full data.
  Future<List<String>> listKeysInternal(DataPath path) =>
      readData(path).then((data) => (data as StructuredData).firstLevelKeys);
}

class MemoryBackend extends Backend {
  final String? filePath;
  final DataType root;
  MemoryBackend(Object? data, {String? file, required this.filePath})
    : root = DataType.deduce(data),
      super(file: file ?? filePath?.split("/").last) {
    updateData(DataPath(""), Lazy.value(root));
  }

  MemoryBackend.fromObject(Object? data, {String? file})
    : this(DataType.deduce(data), file: file, filePath: null);

  @override
  readDataInternal(DataPath path) => throw UnimplementedError();

  @override
  listKeysInternal(DataPath path) => throw UnimplementedError();

  @override
  Future<Uri> toUri() {
    if (filePath != null) {
      return Future.sync(() => Uri.file(filePath!));
    }
    return objectToUri(root);
  }
}
