// Dart imports:
import "dart:convert";

// Flutter imports:
import "package:flutter/services.dart";

// Package imports:
import "package:desktop_multi_window/desktop_multi_window.dart";
import "package:flutter_platform_alert/flutter_platform_alert.dart";
import "package:window_manager/window_manager.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/data/backend/base_backend.dart";
import "package:frontend/data/backend/common.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/data/data_type.dart";

class WindowData {
  static const hostApi = MethodChannel("myChannel");

  final int windowId;
  final WindowController controller;

  WindowData({required this.windowId})
    : controller = WindowController.fromWindowId(windowId);

  static Future<void> createWindow({
    DataType? data,
    Uri? uri,
    Backend? backend,
    DataPath? path,
  }) async {
    uri ??= await data?.call(objectToUri) ?? await backend?.toUri();
    final window = await DesktopMultiWindow.createWindow(
      jsonEncode({"file": uri?.toString(), "path": path?.path}),
    );
    window.show();
  }

  static Future<void> close() async => windowManager.close();

  static Future<void> initialize() async {
    hostApi.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case "onFileOpened":
          final String? path = call.arguments;
          if (path != null) {
            createWindow(uri: Uri.file(path));
          }
        case "newWindow":
          createWindow();
      }
    });
  }

  static Future<void> alert(String message, {String? title}) =>
      FlutterPlatformAlert.showAlert(
        windowTitle: title ?? "Alert",
        text: message,
        alertStyle: AlertButtonStyle.ok,
        iconStyle: IconStyle.information,
      );

  static Future<bool> confirm(String message, {String? title}) =>
      FlutterPlatformAlert.showAlert(
        windowTitle: title ?? "Confirm",
        text: message,
        alertStyle: AlertButtonStyle.okCancel,
        iconStyle: IconStyle.information,
      ).then((value) => value == AlertButton.okButton);
}
