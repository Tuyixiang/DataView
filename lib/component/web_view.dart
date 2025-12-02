// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:styled_widget/styled_widget.dart";

// Project imports:
import "package:frontend/data/loader.dart";
import "package:frontend/styles/base.dart";

class WebView extends StatefulWidget {
  final Future<String> html;
  final bool fillHeight;
  const WebView({super.key, required this.html, this.fillHeight = false});

  @override
  State<WebView> createState() => _WebViewState();
}

class _WebViewState extends State<WebView> {
  String? html;
  final List<String> errors = [];

  @override
  void initState() {
    super.initState();
    bool initialized = false;
    widget.html.then((data) {
      if (!mounted) return;
      if (!initialized) {
        html = data;
      } else {
        setState(() => html = data);
      }
    });
    initialized = true;
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: widget.fillHeight ? .infinity : AppLayout.cardMaxHeight,
    ),
    child: html == null
        ? SizedBox.expand()
        : Column(
            children: [
              InAppWebView(
                key: widget.key,
                initialData: InAppWebViewInitialData(data: html!),
                onWebViewCreated: (controller) {
                  controller.addUserScript(
                    userScript: UserScript(
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      source: r"""
window.onerror = function (message, source, lineno, colno, error) {
  window.flutter_inappwebview.callHandler("error", "runtime", `${message} (${source}:${lineno}:${colno})`);
  return false;
};
window.addEventListener("error", function (event) {
  const target = event.target;
  if (target) {
    const url = target.src || target.href;
    if (url) {
      window.flutter_inappwebview.callHandler("error", "resource", `Failed to load resource: ${url}`);
    }
  }
}, true);
window.addEventListener("unhandledrejection", function (event) {
  const reason = event.reason;
  if (reason instanceof Error) {
    window.flutter_inappwebview.callHandler("error", "runtime", reason.message);
  } else {
    window.flutter_inappwebview.callHandler("error", "runtime", reason);
  }
});
""",
                    ),
                  );
                  controller.addJavaScriptHandler(
                    handlerName: "error",
                    callback: (data) {
                      switch (data.firstOrNull) {
                        case "runtime":
                          setState(() => errors.add("⛔️ ${data.get(1)}"));
                        case "resource":
                          setState(() => errors.add("⚠️ ${data.get(1)}"));
                      }
                    },
                  );
                },
              ).expanded(),
              if (errors.isNotEmpty)
                Column(
                  mainAxisSize: .min,
                  children: errors
                      .map(
                        (message) => Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: AppTextStyles.label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ).paddingDirectional(horizontal: 12),
                          ],
                        ),
                      )
                      .toList(),
                ).scrollable().constrained(
                  maxHeight: AppLayout.labelHeight * 4,
                ),
            ],
          ),
  );
}
