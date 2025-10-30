// Package imports:
import "package:web/web.dart" as web;

Map<String, String> getQueryParams() {
  final uri = Uri.parse(web.window.location.href);
  return uri.queryParameters;
}

Uri? getCurrentUrl() => Uri.parse(web.window.location.href);
