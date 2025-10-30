// Project imports:
import "package:frontend/data/backend/base_backend.dart";
import "package:frontend/data/data_path.dart";
import "package:frontend/data/data_type.dart";

class WindowData {
  static Future<void> createWindow({
    DataType? data,
    Backend? backend,
    DataPath? path,
  }) async {}
  static Future<void> close() async {}
  static Future<void> initialize() async {}
  static Future<void> alert(String message, {String? title}) async {}
  static Future<bool> confirm(String message, {String? title}) async => false;
}
