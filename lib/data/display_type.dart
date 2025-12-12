part of "data_type.dart";

enum DisplaySizeEnum {
  card,
  page,
  preview;

  int get charLimit {
    switch (this) {
      case .card:
        return CARD_CHAR_LIMIT;
      case .page:
        return PAGE_CHAR_LIMIT;
      case .preview:
        return CARD_CHAR_LIMIT;
    }
  }

  int get stringLimit {
    switch (this) {
      case .card:
        return CARD_STRING_LIMIT;
      case .page:
        return PAGE_STRING_LIMIT;
      case .preview:
        return CARD_STRING_LIMIT;
    }
  }

  int get lineLimit {
    switch (this) {
      case .card:
        return 80;
      case .page:
        return 320;
      case .preview:
        return 80;
    }
  }
}

class DisplayStatus {
  final List<DisplayType> supported;
  final DisplayType defaultDisplay;
  DisplayType current;

  DisplayStatus(
    this.supported, {
    DisplayType? defaultDisplay,
    DisplayType? currentDisplay,
  }) : defaultDisplay = defaultDisplay ?? supported.first,
       current = currentDisplay ?? defaultDisplay ?? supported.first;

  static DisplayStatus card(DataType data) => deduce(data, size: .card);
  static DisplayStatus page(DataType data) => deduce(data, size: .page);
  static DisplayStatus preview(DataType data) => deduce(data, size: .preview);

  static DisplayStatus deduce(DataType data, {required DisplaySizeEnum size}) {
    final charLimit = size.charLimit;
    switch (data) {
      case LiteralNull():
        return DisplayStatus([const DisplayNone()]);
      case LiteralBool obj:
        return DisplayStatus([
          DisplayCode(value: obj.toString(), lang: "json"),
        ]);
      case LiteralNum obj:
        return DisplayStatus([
          DisplayCode(value: obj.toString(), lang: "json"),
        ]);
      case MarkdownString obj:
        final text = obj.data;
        final showText = ellipsisMessage(obj.text, limit: charLimit);
        return DisplayStatus([
          DisplayMarkdown(value: showText),
          DisplayPlain(value: text),
          if (size == .card && (text.length >= 80 || text.contains("\n")))
            DisplayFold(value: "<text length=${text.length}>"),
        ]);
      case CodeString obj:
        final text = ellipsisMessage(obj.data, limit: charLimit);
        return DisplayStatus([
          DisplayCode(value: text, lang: obj.lang),
          if (size == .card && (text.length >= 80 || text.contains("\n")))
            DisplayFold(
              value: "<code lang=${obj.lang} length=${obj.data.length}>",
            ),
        ]);
      case MixedWebString obj:
        return DisplayStatus([
          DisplayWeb(html: obj.webString.getHtml(), lang: obj.webString.lang),
          DisplayMarkdown(value: obj.data),
          DisplayCode(
            value: obj.webString.toString(),
            lang: obj.webString.lang,
          ),
          DisplayPlain(value: obj.data),
          if (size == .card)
            DisplayFold(value: "<text length=${obj.data.length}>"),
        ]);
      case WebString obj:
        return DisplayStatus([
          DisplayWeb(html: obj.getHtml(), lang: obj.lang),
          DisplayCode(value: obj.toString(), lang: obj.lang),
          if (size == .card)
            DisplayFold(
              value: "<code lang=${obj.lang} length=${obj.data.length}>",
            ),
        ]);
      case StructuredData obj:
        switch (size) {
          case .card:
            return DisplayStatus([
              if (obj.pivotable)
                DisplayTable(
                  keys: obj.firstLevelKeys,
                  columns:
                      (obj[obj.firstLevelKeys.first].unwrap() as StructuredData)
                          .firstLevelKeys,
                ),
              DisplayObject(obj),
              DisplayCode(
                getter: () => ellipsisMessage(obj.json, limit: charLimit),
                lang: "json",
              ),
              DisplayFold(value: "<data length=${obj.data.length}>"),
            ]);
          case .page:
            return DisplayStatus([
              if (obj.pivotable)
                DisplayTable(
                  keys: obj.firstLevelKeys,
                  columns:
                      (obj[obj.firstLevelKeys.first].unwrap() as StructuredData)
                          .firstLevelKeys,
                ),
              DisplayExpand(keys: obj.compoundKeys.unwrap()),
              DisplayObject(obj),
              DisplayCode(
                getter: () => ellipsisMessage(obj.json, limit: charLimit),
                lang: "json",
              ),
            ]);
          case .preview:
            return DisplayStatus([
              if (obj.pivotable)
                DisplayTable(
                  keys: obj.firstLevelKeys,
                  columns:
                      (obj[obj.firstLevelKeys.first].unwrap() as StructuredData)
                          .firstLevelKeys,
                ),
              DisplayObject(obj),
              DisplayExpand(keys: obj.compoundKeys.unwrap()),
              DisplayCode(
                getter: () => ellipsisMessage(obj.json, limit: charLimit),
                lang: "json",
              ),
            ]);
        }
    }
  }
}

sealed class DisplayType {
  final String? value;
  final String Function()? getter;
  const DisplayType({this.value, this.getter});

  String get name;
  String get content => value ?? getter!();

  /// Copy display styles from another item
  void copyStyleFrom(DisplayType other) {}

  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class DisplayNone extends DisplayType {
  const DisplayNone() : super(value: "");
  @override
  String get name => "empty";
}

class DisplayObject extends DisplayType {
  final DataType data;

  DisplayObject(this.data);

  @override
  String get name => "yaml";
}

class DisplayPlain extends DisplayType {
  final bool isHint;
  const DisplayPlain({super.value, super.getter, this.isHint = false});
  @override
  String get name => "plain";
}

class DisplayMarkdown extends DisplayType {
  const DisplayMarkdown({super.value, super.getter});
  @override
  String get name => "markdown";
}

class DisplayCode extends DisplayType {
  final String lang;
  const DisplayCode({super.value, super.getter, required this.lang});
  @override
  String get name => lang;

  @override
  bool operator ==(Object other) => other is DisplayCode && lang == other.lang;

  @override
  int get hashCode => super.hashCode ^ lang.hashCode;
}

class DisplayWeb extends DisplayType {
  final Future<String> html;
  final String lang;
  const DisplayWeb({required this.html, required this.lang});
  @override
  String get name => "preview";
}

class DisplayFold extends DisplayType {
  const DisplayFold({super.value, super.getter});
  @override
  String get name => "fold";
}

class DisplayExpand extends DisplayType {
  final List<String> keys;
  late final List<String> sortedKeys;

  DisplayExpand({required this.keys}) {
    final parsedKeys = keys.map((s) {
      final first = s.split(DataPath.separator).first;
      return (int.tryParse(first) ?? first, s);
    }).toList();
    parsedKeys.sort((a, b) {
      final (a0, a1) = a;
      final (b0, b1) = b;
      if (a0 is int && b0 is int) {
        return a0.compareTo(b0);
      }
      if (a0 is String && b0 is String) {
        return a0.compareTo(b0);
      }
      return a0 is int ? -1 : 1;
    });
    sortedKeys = parsedKeys.map((e) => e.$2).toList();
  }
  @override
  String get name => "expand";
}

class DisplayTable extends DisplayType {
  final List<String> keys;
  final List<String> columns;
  late final List<String> sortedKeys;
  bool isHorizontal;
  (String row, String col)? previewItem;

  DisplayTable({
    required this.keys,
    required this.columns,
    this.isHorizontal = true,
  }) {
    final parsedKeys = keys.map((s) {
      final first = s.split(DataPath.separator).first;
      return (int.tryParse(first) ?? first, s);
    }).toList();
    parsedKeys.sort((a, b) {
      final (a0, a1) = a;
      final (b0, b1) = b;
      if (a0 is int && b0 is int) {
        return a0.compareTo(b0);
      }
      if (a0 is String && b0 is String) {
        return a0.compareTo(b0);
      }
      return a0 is int ? -1 : 1;
    });
    sortedKeys = parsedKeys.map((e) => e.$2).toList();
  }

  @override
  String get name => "table";

  @override
  void copyStyleFrom(DisplayType other) {
    other = other as DisplayTable;
    isHorizontal = other.isHorizontal;
    previewItem = other.previewItem;
  }
}
