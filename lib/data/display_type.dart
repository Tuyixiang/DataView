part of "data_type.dart";

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

  static DisplayStatus card(DataType data) => deduce(data, asCard: true);
  static DisplayStatus page(DataType data) => deduce(data, asCard: false);

  static DisplayStatus deduce(DataType data, {required bool asCard}) {
    final charLimit = asCard ? CARD_CHAR_LIMIT : PAGE_CHAR_LIMIT;
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
          if (asCard && (text.length >= 80 || text.contains("\n")))
            DisplayFold(value: "<text length=${text.length}>"),
        ]);
      case CodeString obj:
        final text = ellipsisMessage(obj.data, limit: charLimit);
        return DisplayStatus([
          DisplayCode(value: text, lang: obj.lang),
          if (asCard && (text.length >= 80 || text.contains("\n")))
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
          if (asCard) DisplayFold(value: "<text length=${obj.data.length}>"),
        ]);
      case WebString obj:
        return DisplayStatus([
          DisplayWeb(html: obj.getHtml(), lang: obj.lang),
          DisplayCode(value: obj.toString(), lang: obj.lang),
          if (asCard)
            DisplayFold(
              value: "<code lang=${obj.lang} length=${obj.data.length}>",
            ),
        ]);
      case StructuredData obj:
        if (asCard) {
          return DisplayStatus([
            DisplayObject(obj),
            DisplayCode(
              getter: () => ellipsisMessage(obj.json, limit: charLimit),
              lang: "json",
            ),
            DisplayFold(value: "<data length=${obj.data.length}>"),
          ]);
        } else {
          return DisplayStatus([
            DisplayExpand(keys: obj.compoundKeys.unwrap()),
            DisplayObject(obj),
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

  bool get supportBrowserOpen => false;
  Future<String> get browserOpenHtml => throw UnimplementedError();

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
  @override
  bool get supportBrowserOpen => true;
  @override
  Future<String> get browserOpenHtml => html;
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
