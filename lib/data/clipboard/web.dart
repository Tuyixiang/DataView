// Package imports:
import "package:web/web.dart" as web;

// This doesn't work due to lack of HTTPS
Future<void> writeToClipboard(String content) async {
  web.window.navigator.clipboard.writeText("Hello Web!");
}
