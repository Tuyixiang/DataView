import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  open var currentFile: String?
  open var channel: FlutterMethodChannel?
  open var didFetchInitialFile: Bool = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // For file open: interop with Flutter
    let channel = FlutterMethodChannel(
      name: "myChannel", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler({
      (call: FlutterMethodCall, result: FlutterResult) -> Void in
      if call.method == "getCurrentFile" {
        result(self.currentFile)
        self.currentFile = nil
        self.didFetchInitialFile = true
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    self.channel = channel

    // desktop_multi_window
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      // Register the plugin which you want access from other isolate.
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }
}
