part of "item_display.dart";

extension _WebDisplay on _ItemDisplayState {
  Widget buildHtml(DisplayWeb display) =>
      WebView(html: display.html);
}
