import Flutter
import UIKit

/// Bridges widget deep links (stiko://sticker/<id>) to Dart. The app uses the
/// UIScene lifecycle, so URL opens arrive here rather than on the AppDelegate,
/// which is why home_widget's own click handling does not fire.
class SceneDelegate: FlutterSceneDelegate {
  private var pendingURL: String?
  private var channel: FlutterMethodChannel?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Cold start from a widget tap: remember the URL until Dart asks for it.
    pendingURL = connectionOptions.urlContexts.first?.url.absoluteString
    setUpChannel()
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    setUpChannel()
    if let url = URLContexts.first?.url.absoluteString {
      channel?.invokeMethod("open", arguments: url)
    }
  }

  private func setUpChannel() {
    guard channel == nil,
          let controller = window?.rootViewController as? FlutterViewController
    else { return }
    let ch = FlutterMethodChannel(
      name: "stiko/deeplink",
      binaryMessenger: controller.binaryMessenger
    )
    ch.setMethodCallHandler { [weak self] call, result in
      if call.method == "getInitial" {
        result(self?.pendingURL)
        self?.pendingURL = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    channel = ch
  }
}
