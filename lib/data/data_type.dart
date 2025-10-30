// Dart imports:
import "dart:collection";
import "dart:convert";

// Package imports:
import "package:http/http.dart" as http;
import "package:intl/intl.dart";
import "package:json5/json5.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/common/config.dart";
import "package:frontend/component/markdown_extension/md_preprocess.dart";
import "package:frontend/data/common.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/data/react/stub.dart";

part "display_type.dart";

Iterable<({String lang, String code})> extractCodeBlocks({
  String? text,
  List<String>? lines,
}) sync* {
  final buffer = <String>[];
  String? lang;
  int? tickCount;

  for (final line in lines ?? text!.split("\n")) {
    if (tickCount == null) {
      if (line.startsWith("```")) {
        tickCount = RegExp("`+").matchAsPrefix(line)!.end;
        lang = line.substring(tickCount).toLowerCase();
      }
    } else {
      if (line.startsWith("`" * tickCount)) {
        yield (lang: lang!, code: buffer.join("\n"));
        buffer.clear();
        lang = null;
        tickCount = null;
      } else {
        buffer.add(line);
      }
    }
  }
}

sealed class DataType<T> {
  final T data;
  DataType(this.data);

  DisplayStatus? cardDisplay;
  DisplayStatus? pageDisplay;

  Object? get encodable => data;

  static DataType? deduceLink(String text, Lazy<List<String>> lines) {
    if (!text.startsWith("http://") ||
        !text.startsWith("https://") ||
        text.contains("\n")) {
      return null;
    }
    try {
      final uri = Uri.parse(text);
      final path = uri.path;
      final extension = path.split(".").last.toLowerCase();
      if (["jpg", "jpeg", "webp", "png", "gif"].contains(extension)) {
        return MarkdownString.processed(text, text: "![image]($text)");
      }
      if (["htm", "html"].contains(extension)) {
        return WebString(
          htmlGetter: http
              .get(uri)
              .then((response) => response.body)
              .catchError(
                (e) =>
                    """<html>
  <h2>Error getting html</h2>
  <pre>source: $text
error: $e</pre>
</html>""",
              ),
        );
      }
    } on FormatException catch (_) {}

    return null;
  }

  static DataType? deduceSerialized(String text, Lazy<List<String>> lines) {
    late final Object parsed;
    try {
      if ("[{".contains(text.substring(0, 1))) {
        parsed = json5Decode(text);
      } else if (text.startsWith("- ") ||
          text.startsWith(RegExp(r"[^\s:]+: .+\n"))) {
        parsed = yamlDecode(text);
      } else {
        return null;
      }
    } on Exception catch (_) {
      return null;
    }
    return deduce(parsed);
  }

  static DataType? deduceHtml(String text, Lazy<List<String>> lines) {
    if (text.startsWith("```html\n") && text.endsWith("\n```")) {
      return WebString(html: text.substring(8, text.length - 4));
    }
    if (text.startsWith(RegExp("<!doctype html>", caseSensitive: false))) {
      return WebString(html: text);
    }
    for (final tag in ["html", "body", "svg"]) {
      if (text.startsWith("<$tag") &&
          (text.endsWith("</$tag>") || text.endsWith("/>"))) {
        return WebString(html: text);
      }
    }

    if (TEST_FEATURES) {
      if (text.startsWith("```jsx") && text.endsWith("\n```")) {
        return WebString(
          react: text.substring(text.indexOf("\n"), text.length - 4),
        );
      }
      if (!lines.unwrap().any((line) => line.startsWith("```")) &&
          (text.startsWith("export default") ||
              text.contains("\nexport default"))) {
        return WebString(react: text);
      }
    }

    final codeBlocks = extractCodeBlocks(lines: lines.unwrap()).toList();
    if (codeBlocks.length == 1) {
      switch (codeBlocks.first.lang) {
        case "html":
          return MixedWebString(text, WebString(html: codeBlocks.first.code));
        case "jsx":
        case "react":
          return MixedWebString(text, WebString(react: codeBlocks.first.code));
        default:
          return null;
      }
    } else {
      String? html;
      final List<String> js = [], css = [];
      for (final (:lang, :code) in codeBlocks) {
        switch (lang) {
          case "html":
            if (html != null) {
              return null;
            }
            html = code;
          case "js":
          case "javascript":
            js.add(code);
          case "css":
            css.add(code);
          case "":
            break;
          default:
            return null;
        }
      }
      if (html != null) {
        if (js.isNotEmpty) {
          html = html.replaceAllMapped(
            RegExp(
              r"""<script\b(?=[^>]*\bsrc=(["'])(?!https?://)\S+?\1)[^>]+>\s*</script>""",
              caseSensitive: false,
            ),
            (match) {
              if (js.isNotEmpty) {
                return "<script>\n${js.removeLast()}\n</script>";
              }
              return match.group(0)!;
            },
          );
        }
        if (css.isNotEmpty) {
          html = html.replaceAllMapped(
            RegExp(
              r"""<link\b(?=[^>]*\brel=(["'])stylesheet\1)(?=[^>]*\bhref=(["'])(?!https?://).+?\2)[^>]+>""",
              caseSensitive: false,
            ),
            (match) {
              if (css.isNotEmpty) {
                return "<style>\n${css.removeLast()}\n</style>";
              }
              return match.group(0)!;
            },
          );
        }
        return MixedWebString(text, WebString(html: html));
      }
    }

    return null;
  }

  static DataType deduce(Object? data) {
    switch (data) {
      case DataType dt:
        return dt;
      case null:
        return LiteralNull();
      case bool value:
        return LiteralBool(value);
      case num value:
        return LiteralNum(value);
      case List list:
        return list.isEmpty ? LiteralNull() : StructuredData.fromList(list);
      case Map map:
        return map.isEmpty ? LiteralNull() : StructuredData.fromMap(map);
      case String string:
        final text = string.trim();
        if (text.isEmpty) {
          return LiteralNull();
        }
        final lines = Lazy.getter(() => text.split("\n"));
        return deduceLink(text, lines) ??
            deduceSerialized(text, lines) ??
            deduceHtml(text, lines) ??
            MarkdownString(text);
      default:
        return CodeString(
          "Unsupported data type ${data.runtimeType}",
          lang: "shell",
        );
    }
  }
}

class LiteralNull extends DataType<Null> {
  LiteralNull([super.data]);

  @override
  String toString() => "null";
}

class LiteralBool extends DataType<bool> {
  LiteralBool(super.data);

  @override
  String toString() => data.toString();
}

class LiteralNum extends DataType<num> {
  static final formatter = NumberFormat.decimalPattern();

  LiteralNum(super.data);

  @override
  String toString() => data.toString();
}

class MarkdownString extends DataType<String> {
  /// Text used in rendering markdown (may differ from actual text)
  final String text;

  MarkdownString(super.data) : text = preprocessMarkdown(data);

  MarkdownString.processed(super.data, {required this.text});

  MarkdownString.literal(super.data) : text = data;

  @override
  String toString() => data;
}

class CodeString extends DataType<String> {
  final String lang;

  CodeString(super.data, {required this.lang});

  @override
  String toString() => data;
}

class MixedWebString extends DataType<String> {
  final WebString webString;

  MixedWebString(super.data, this.webString);
}

class WebString extends DataType<String> {
  late final String lang;
  String? react;
  String? html;
  Future<String>? htmlGetter;

  WebString({this.react, this.html, this.htmlGetter})
    : super(react ?? html ?? "") {
    if (react != null) {
      lang = "jsx";
    } else if (html != null || htmlGetter != null) {
      lang = "html";
    } else {
      throw Error();
    }
  }

  Future<String> getHtml() {
    if (html != null) {
      return Future.sync(() => html!);
    }
    if (htmlGetter != null) {
      return htmlGetter!.then((data) => html = data);
    }
    switch (lang) {
      case "html":
        return Future.sync(() => html = data);
      case "jsx":
        return compileReact(react ?? data).then((value) => html = value);
      default:
        throw UnimplementedError();
    }
  }

  @override
  String toString() => react ?? html ?? data;

  String get fenced => "```$lang\n${toString()}\n```";
}

/// Lazy evaluate:
/// * Upon construction, [DataType.deduce] is not called on children objects
/// * When [compoundKeys], [pivotable], etc. is called, children will be deduced into [DataType]
class StructuredData extends DataType<LinkedHashMap<String, Lazy<DataType>>> {
  /// [isMap] stores whether the original data is map (list otherwise)
  ///
  /// [data] is already converted to [Map]
  final bool isMap;

  /// Key of every child object
  final List<String> firstLevelKeys;

  /// Key that may be nested (like "0/0/0") if there's only one grandchild
  final Lazy<List<String>> compoundKeys;

  Lazy<DataType> operator [](String key) =>
      key == DataPath.pivotMark ? Lazy.getter(() => pivot) : data[key]!;

  int get length => data.length;

  String? _cachedJson;
  String? _cachedYaml;
  Object? _cachedBrief;
  String get json =>
      _cachedJson ??= JsonEncoder.withIndent("  ", toEncodable).convert(this);
  String get yaml => _cachedYaml ??= yamlEncode(this, toEncodable: toEncodable);
  Object get brief => _cachedBrief ??= limitObjectLength<Object>(
    this,
    toEncodable: toEncodable,
    stringLimit: CARD_STRING_LIMIT,
    lengthLimit: CARD_CHAR_LIMIT,
  );
  set json(String? data) => _cachedJson = data ?? _cachedJson;
  set yaml(String? data) => _cachedYaml = data ?? _cachedYaml;

  static Object? toEncodable(Object? obj) =>
      obj is DataType ? obj.encodable : obj;

  @override
  Object? get encodable => isMap
      ? data.map(
          (key, value) =>
              MapEntry(DataPath.unescapeKey(key), value.unwrap().encodable),
        )
      : data.values.map((e) => e.unwrap().encodable).toList();

  @override
  String toString() => json;

  StructuredData(super.data, {required this.isMap})
    : compoundKeys = Lazy.getter(() => listCompoundKeys(data)),
      firstLevelKeys = data.keys.toList();

  StructuredData.fromList(List list)
    : this(
        LinkedHashMap.fromIterables(
          List.generate(list.length, (i) => "$i"),
          list.map(Lazy.call(DataType.deduce)),
        ),
        isMap: false,
      );

  StructuredData.fromMap(Map map)
    : this(
        LinkedHashMap.fromIterables(
          map.keys.map((e) => DataPath.escapeKey(e.toString())),
          map.values.map(Lazy.call(DataType.deduce)),
        ),
        isMap: true,
      );

  /// List keys by entering nested list/map if there's only one child
  ///
  /// This will call [DataType.deduce] on children objects
  static List<String> listCompoundKeys(
    LinkedHashMap<String, Lazy<DataType>> data,
  ) => data.entries.map((entry) {
    final item = entry.value.unwrap();
    if (item is StructuredData && item.data.length == 1) {
      return "${entry.key}${DataPath.separator}${item.compoundKeys.unwrap().first}";
    }
    return entry.key;
  }).toList();

  StructuredData? _cachedPivot;
  StructuredData get pivot => _cachedPivot ??= _pivot();
  StructuredData _pivot() {
    final StructuredData row = data.values.first.unwrap() as StructuredData;
    return StructuredData(
      LinkedHashMap.fromIterable(
        row.firstLevelKeys,
        value: Lazy.call(
          (subKey) => StructuredData(
            LinkedHashMap.fromIterable(
              firstLevelKeys,
              value: (key) => data[key]!.unwrap().data[subKey]!,
            ),
            isMap: isMap,
          ),
        ),
      ),
      isMap: row.isMap,
    );
  }

  bool? _cachedPivotable;
  bool get pivotable => _cachedPivotable ??= _pivotable();
  bool _pivotable() {
    if (data.length <= 1) {
      return false;
    }
    switch (data.values.first.unwrap()) {
      case StructuredData item:
        final map = item.data;
        return data.values
            .skip(1)
            .map((e) => e.unwrap())
            .every(
              (item) =>
                  item is StructuredData &&
                  item.data.length == map.length &&
                  item.firstLevelKeys.every(map.containsKey),
            );
      default:
        return false;
    }
  }
}
