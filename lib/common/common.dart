// Dart imports:
import "dart:math";

// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:yaml/yaml.dart";
import "package:yaml_writer/yaml_writer.dart";

extension ReverseCall<T> on T {
  R call<R>(R Function(T) func) => func(this);
}

String ellipsis(String str, {int? maxLength}) {
  maxLength ??= 32;
  if (str.length > maxLength) {
    return "${str.substring(0, maxLength - 6)}..${str.substring(str.length - 4)}";
  }
  return str;
}

T ellipsisMessage<T>(T data, {int? limit, int? actualLength}) {
  late final int length;
  switch (data) {
    case String():
      length = data.length;
    case List():
      length = data.length;
    case Map():
      length = data.length;
    default:
      throw UnimplementedError();
  }
  limit ??= length;
  actualLength ??= length;
  if (actualLength <= limit) {
    return data;
  }
  switch (data) {
    case String string:
      return "${string.substring(0, limit)}\n\n...(showing $limit / $actualLength chars)"
          as T;
    case List list:
      return [...list.take(limit), "...(showing $limit / $actualLength items)"]
          as T;
    case Map map:
      return {
            ...Map.fromEntries(map.entries.take(limit)),
            "...": "...(showing $limit / $actualLength entries)",
          }
          as T;
    default:
      throw UnimplementedError();
  }
}

void nullCallback() {}

void nullCallback1(_) {}

Never unreachableCallback() => throw UnimplementedError();

Never unreachableCallback1(_) => throw UnimplementedError();

Never _mustProvide(_) => throw FormatException();

T identity<T>(T v) => v;

int estimateObjectLength(
  dynamic object, {
  int maxLength = 10_000_000,
  Object? Function(Object?) toEncodable = _mustProvide,
}) {
  int count = 0;
  void walk(dynamic node) {
    switch (node) {
      case null:
      case bool():
      case num():
        count += 4;
      case String():
        count += node.length;
      case List list:
        for (final item in list) {
          if (count > maxLength) {
            break;
          }
          walk(item);
        }
      case Map map:
        for (final entry in map.entries) {
          if (count > maxLength) {
            break;
          }
          walk(entry.key);
          walk(entry.value);
        }
    }
  }

  walk(object);
  return count;
}

T limitObjectLength<T>(
  T object, {
  int? stringLimit,
  int? lengthLimit,
  Object? Function(Object?) toEncodable = _mustProvide,
}) {
  int limit = lengthLimit ?? 1 << 62;
  dynamic walk(dynamic node) {
    switch (node) {
      case null:
      case bool():
      case num():
        limit -= 4;
        return node;
      case String():
        // final result = ellipsisMessage(node.toString(), limit: stringLimit);
        limit -= min(node.length, stringLimit ?? node.length);
        return node;
      case List list:
        final result = [];
        for (final item in list) {
          if (limit <= 0) {
            break;
          }
          result.add(walk(item));
          limit -= 4;
        }
        return ellipsisMessage(result, actualLength: list.length);
      case Map map:
        final result = {};
        for (final entry in map.entries) {
          if (limit <= 0) {
            break;
          }
          result[walk(entry.key)] = walk(entry.value);
          limit -= 4;
        }
        return ellipsisMessage(result, actualLength: map.length);
      default:
        return walk(toEncodable(node));
    }
  }

  return walk(object);
}

String yamlEncode(
  Object? data, {
  Object? Function(Object?) toEncodable = identity,
}) => YamlWriter(
  allowUnquotedStrings: true,
  toEncodable: toEncodable,
).write(data).trim();

dynamic yamlDecode(String yaml) {
  dynamic walk(dynamic node) {
    switch (node) {
      case YamlList list:
        return list.map(walk).toList();
      case YamlMap map:
        return Map.fromEntries(
          map.entries.map((e) => MapEntry(e.key, walk(e.value))),
        );
      default:
        return node;
    }
  }

  return walk(loadYaml(yaml));
}

Iterable<int> range(int v, [int? end, int step = 1]) sync* {
  if (end == null) {
    for (int i = 0; i < v; i += 1) {
      yield i;
    }
  } else {
    for (int i = v; i < end; i += step) {
      yield i;
    }
  }
}

class SingleUseWidget extends StatelessWidget {
  final Widget Function(BuildContext) _build;

  const SingleUseWidget(Widget Function(BuildContext) build, {super.key})
    : _build = build;

  @override
  Widget build(BuildContext context) => _build(context);
}

class SingleUseStatefulWidget extends StatefulWidget {
  final Widget Function(BuildContext, State<SingleUseStatefulWidget>) _build;

  const SingleUseStatefulWidget(
    Widget Function(BuildContext, State<SingleUseStatefulWidget>) build, {
    super.key,
  }) : _build = build;

  @override
  State<StatefulWidget> createState() => _SingleUseStatefulWidgetState();
}

class _SingleUseStatefulWidgetState extends State<SingleUseStatefulWidget> {
  @override
  Widget build(BuildContext context) => widget._build(context, this);
}
