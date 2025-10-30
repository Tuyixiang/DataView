// Flutter imports:
import "package:flutter/services.dart";

Future<void> writeToClipboard(String content) =>
    Clipboard.setData(ClipboardData(text: content));
