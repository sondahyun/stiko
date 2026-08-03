import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register plugins for every additional (sticky) window so Firebase and
    // other plugins work inside them too, and make each sticky window able to
    // be see-through so a low-opacity sticky shows the desktop behind it
    // instead of compositing over black.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      // The FlutterView defaults to a black background, which makes a
      // low-opacity sticky look dark. Clearing it lets the desktop show through.
      controller.backgroundColor = NSColor.clear
      DispatchQueue.main.async {
        if let window = controller.view.window {
          window.isOpaque = false
          window.backgroundColor = NSColor.clear
        }
      }
    }

    super.awakeFromNib()
  }
}
