// Dart imports:
import "dart:math";

// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:markdown/markdown.dart" as m;
import "package:markdown_widget/markdown_widget.dart";

// Project imports:
import "package:frontend/common/config.dart";
import "package:frontend/component/text/escape.dart";
import "package:frontend/styles/base.dart";

const openMark = "@@#@@";
const closeMark = "@@&@@";
const insertMark = "@@~@@";

String wrapMark(String text) =>
    text.isNotEmpty ? "$openMark$text$closeMark" : "";

final tagRegex = RegExp(
  r"""</(?<close>[\w\.:\-]+)>|<(?<open>[\w\.:\-]+)(=\w+|='[^\n']*'|="[^\n"]*")?(\s+[\w\.:\-]+(=([\w\.:\-]+|"[^\n"]*"|'[^\n']*'))?)*\s*(?<self_close>/)?>""",
);

final codeBlockRegex = RegExp(
  r"^( *`{3,})\w*.*\n[\s\S]+?\n\1`*\s*?$|(`+)[^`\n]+\2",
  multiLine: true,
);

/// These will be stripped of tags like "<div ...>"
const ignoredTags = {"div", "body", "p"};

/// These will be preserved to markdown
const preservedTags = {"img", "b", "strong", "i", "em", "a"};

class _HtmlTagVisitor {
  final String text;

  _HtmlTagVisitor(this.text);

  Map<String, String> getAttributes(String tag) => {
    for (final match in RegExp(
      r"""\s+([\w\.:\-]+)(?:=([\w\.:\-])+|="(.*?)"|='(.*?)')?""",
    ).allMatches(tag))
      match.group(1)!:
          match.group(2) ?? match.group(3) ?? match.group(4) ?? "true",
  };

  static List<String> parseTag({
    String? tag,
    String? name,
    List<String> content = const [],
    String? closeTag,
  }) {
    if (tag == null) {
      return content;
    }
    if (preservedTags.contains(name)) {
      return [tag, ...content, closeTag ?? ""];
    }
    if (closeTag == null) {
      return [wrapMark(tag), ...content];
    }
    if (ignoredTags.contains(name)) {
      return ["${content.join().trim()} "];
    }
    return [wrapMark(tag), ...content, wrapMark(closeTag)];
  }

  static List<String> process(String text) =>
      _HtmlTagVisitor(text).parse(start: 0, end: 0).parts;

  /// Parse text starting from the given tag, up to where tag closes
  ({List<String> parts, int end}) parse({
    required int start,
    required int end,
    String? tag,
    String? name,
  }) {
    final parts = <String>[];
    int current = end;
    // If current tag self-closes, return its result
    while (true) {
      final match = tagRegex.allMatches(text, current).firstOrNull;
      if (match != null) {
        final isClosing = match.namedGroup("close") != null;
        final isSelfClosing = match.namedGroup("self_close") != null;
        final newTagName = match.namedGroup(isClosing ? "close" : "open")!;
        final newTagText = match.group(0)!;
        // Skip malformed tags
        if (isClosing && isSelfClosing) {
          parts.add(text.substring(current, match.end));
          current = match.end;
          continue;
        }
        // Store data so far
        parts.add(text.substring(current, match.start));
        // On self-clonsing tag
        if (isSelfClosing) {
          parts.addAll(
            parseTag(tag: newTagText, name: newTagName, closeTag: ""),
          );
          current = match.end;
          continue;
        }
        // On open tag, go recursive
        if (!isClosing) {
          final result = parse(
            start: match.start,
            end: match.end,
            tag: newTagText,
            name: newTagName,
          );
          parts.addAll(result.parts);
          current = result.end;
          continue;
        }
        // On closing tag
        if (newTagName == name) {
          // This tag closed properly
          return (
            parts: parseTag(
              tag: tag,
              name: name,
              content: parts,
              closeTag: newTagText,
            ),
            end: match.end,
          );
        } else if (tag == null) {
          // Close tag without open tag
          parts.add(wrapMark(newTagText));
          current = match.end;
          continue;
        } else {
          // Current open tag is not closed
          return (
            parts: parseTag(
              tag: tag,
              name: name,
              content: parts,
              closeTag: null,
            ),
            end: match.start,
          );
        }
      } else {
        // Reaching end of text
        parts.add(text.substring(current, text.length));
        return (
          parts: parseTag(tag: tag, name: name, content: parts, closeTag: null),
          end: text.length,
        );
      }
    }
  }
}

String wrapAnsiAndSpecial(String text) =>
    text.replaceAllMapped(ansiOrControl, (match) {
      final string = match.group(0)!;
      return wrapMark(
        "${escapeChar(string.substring(0, 1))}${string.substring(1)}",
      );
    });

/// On non-codeblock text:
/// * Call [_HtmlTagVisitor.process]
///   * Preserve HTML tags
///   * Wrap non-HTML or un-matched tags with [wrapMark]
/// * Escape special chars
/// * Wrap special chars and ANSI sequences
String preprocessMarkdown(String text) {
  // Maximum process length
  if (text.length > PAGE_CHAR_LIMIT) {
    text = text.substring(0, PAGE_CHAR_LIMIT);
  }
  // Find code blocks
  final parts = <String>[];
  int end = 0;
  for (final match in codeBlockRegex.allMatches("$text\n```")) {
    // non-codeblock: wrap and escape ansi and special chars
    parts.addAll(
      _HtmlTagVisitor.process(
        wrapAnsiAndSpecial(text.substring(end, match.start)),
      ),
    );
    // code block: escape special chars only
    parts.add(escapeAllSpecial(match.group(0)!));
    end = min(match.end, text.length);
  }
  parts.addAll(
    _HtmlTagVisitor.process(wrapAnsiAndSpecial(text.substring(end))),
  );
  return parts.join();
}

const wrappedTag = "disabled_tag";

SpanNodeGeneratorWithTag disabledTagGenerator = SpanNodeGeneratorWithTag(
  tag: wrappedTag,
  generator: (e, config, visitor) => DisabledNode(text: e.textContent),
);

class DisableWrapSyntax extends m.InlineSyntax {
  DisableWrapSyntax() : super("$openMark[\\s\\S]+?$closeMark");

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final matchValue = match.input.substring(
      match.start + openMark.length,
      match.end - closeMark.length,
    );
    parser.addNode(m.Element.text(wrappedTag, matchValue));
    return true;
  }
}

class DisabledNode extends SpanNode {
  final String text;

  DisabledNode({required this.text});

  @override
  InlineSpan build() => TextSpan(style: AppTextStyles.hint(), text: text);
}
