/// Regex that captures ansi control sequences
final ansiRegex = RegExp(r"\x1B\[[0-?]*[ -/]*[@-~]");

/// Regex that captures non-printable ascii characters
final controlChars = RegExp(r"[\x00-\x08\x0B-\x1F\x7F]");

final ansiOrControl = RegExp(
  r"\x1B\[[0-?]*[ -/]*[@-~]|[\x00-\x08\x0B-\x1F\x7F]",
);

String escapeChar(String char, {bool prefix = true}) =>
    "${prefix ? r"\x" : ""}${char.codeUnitAt(0).toRadixString(16).padLeft(2, "0")}";

String escapeAllSpecial(String text, {bool prefix = true}) =>
    text.replaceAllMapped(
      controlChars,
      (match) => escapeChar(match.group(0)!, prefix: prefix),
    );
