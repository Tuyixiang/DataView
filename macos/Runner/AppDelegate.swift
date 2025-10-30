import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return NSApp.windows.filter({ $0 is MainFlutterWindow })
      .count == 1
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    if !urls.isEmpty {
      let path = urls.first!.path
      let window = (mainFlutterWindow as! MainFlutterWindow)
      if !window.didFetchInitialFile {
        // Cold start: stash for Flutter to fetch via getCurrentFile
        window.currentFile = path
      } else if let channel = window.channel {
        // App already running and Flutter ready: send immediately
        channel.invokeMethod("onFileOpened", arguments: path)
      } else {
        // Fallback: stash if channel is not yet available
        window.currentFile = path
      }
    }
  }

  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    let item = NSMenuItem(
      title: "New Window",
      action: #selector(newWindowFromDock),
      keyEquivalent: "n"
    )
    item.target = self
    menu.addItem(item)
    return menu
  }

  @objc private func newWindowFromDock() {
    let window = (mainFlutterWindow as! MainFlutterWindow)
    window.channel?.invokeMethod("newWindow", arguments: nil)
  }
}
