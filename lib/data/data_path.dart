// Dart imports:
import "dart:math";

/// Path must not start or end with "/", and should not contain consecutive "/"
final class DataPath {
  final String path;
  static const String pivotMark = "*";
  static const String separator = "/";

  const DataPath(String? path) : path = path ?? "";

  bool get isEmpty => path.isEmpty;
  bool get isNotEmpty => path.isNotEmpty;
  bool get isPivot => isNotEmpty && last == pivotMark;

  DataPath? get parent => isEmpty
      ? null
      : DataPath(path.substring(0, max(0, path.lastIndexOf(separator))));

  String get last => path.substring(path.lastIndexOf(separator) + 1);

  DataPath and(String sub) {
    if (path.isEmpty) {
      return DataPath(sub);
    }
    if (sub == DataPath.pivotMark && last == pivotMark) {
      return parent!;
    }
    return DataPath("$path$separator$sub");
  }

  DataPath pivot() => and(pivotMark);

  /// Incremental iterate from first item
  Iterable<DataPath> iterate() sync* {
    if (isEmpty) {
      return;
    }
    for (final match in separator.allMatches(path)) {
      yield DataPath(path.substring(0, match.start));
    }
    yield this;
  }

  bool isAncestorOf(DataPath other) =>
      path.length > other.path.length &&
      path.substring(0, other.path.length + separator.length) ==
          "${other.path}$separator";

  @override
  String toString() => path;

  @override
  int get hashCode => path.hashCode;

  @override
  bool operator ==(Object other) {
    return other is DataPath && path == other.path;
  }

  /// Escape key for use in [DataPath]
  static String escapeKey(String key) {
    if (key == DataPath.pivotMark) {
      return "%0";
    }
    return key.replaceAll("%", "%1").replaceAll(DataPath.separator, "%2");
  }

  /// Restore escaped key
  static String unescapeKey(String key) =>
      key.replaceAllMapped(RegExp("%."), (match) {
        switch (match.group(0)!) {
          case "%0":
            return DataPath.pivotMark;
          case "%1":
            return "%";
          case "%2":
            return DataPath.separator;
          default:
            throw FormatException();
        }
      });

  /// Restore key for display (also replaces whitespaces)
  static String displayKey(String key) =>
      unescapeKey(key).replaceAll(RegExp(r"\s+"), " ");
}
