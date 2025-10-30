// Dart imports:
import "dart:js_interop";

// Package imports:
import "package:web/web.dart" as web;

Future<void> executePython(String code) async {
  throw UnsupportedError("Code execution is not supported on your platform.");
}

Future<void> executeCpp(String code) async {
  throw UnsupportedError("Code execution is not supported on your platform.");
}

/// Opens a new tab and writes the HTML string into it.
/// Must be called from a user gesture to avoid popup blockers.
Future<void> launchHtml(Future<String> code) async {
  final win = web.window.open("", "_blank");
  final codeJS = (await code).toJS;
  if (win != null) {
    // about:blank is same-origin; safe to write the full HTML.
    win.document.open();
    win.document.write(codeJS);
    win.document.close();
    return;
  }

  // Fallback: open as a Blob URL (still needs user gesture).
  final blob = web.Blob(
    [codeJS].toJS,
    web.BlobPropertyBag(type: "text/html;charset=utf-8"),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, "_blank");
  web.URL.revokeObjectURL(url);
}
