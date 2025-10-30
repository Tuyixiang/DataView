part of "item_display.dart";

extension _WebDisplay on _ItemDisplayState {
  Widget buildHtml(BuildContext context, Future<String> html) =>
      WebView(html: html);
}
