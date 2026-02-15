import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var splashOverlay: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Keep in sync with iOS LaunchScreen + Android splash.
    let brandGreen = UIColor(red: 15.0/255.0, green: 123.0/255.0, blue: 100.0/255.0, alpha: 1.0)
    window?.backgroundColor = brandGreen
    window?.rootViewController?.view.backgroundColor = brandGreen

    // Show a native overlay until Flutter draws its first frame.
    // This smooths the transition and avoids any brief "unbranded" flash.
    if let w = window {
      let overlay = UIView(frame: w.bounds)
      overlay.translatesAutoresizingMaskIntoConstraints = false
      overlay.backgroundColor = brandGreen

      let logo = UIImageView(image: UIImage(named: "LaunchImage"))
      logo.translatesAutoresizingMaskIntoConstraints = false
      logo.contentMode = .scaleAspectFit

      overlay.addSubview(logo)
      w.addSubview(overlay)

      NSLayoutConstraint.activate([
        overlay.leadingAnchor.constraint(equalTo: w.leadingAnchor),
        overlay.trailingAnchor.constraint(equalTo: w.trailingAnchor),
        overlay.topAnchor.constraint(equalTo: w.topAnchor),
        overlay.bottomAnchor.constraint(equalTo: w.bottomAnchor),

        logo.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        logo.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        logo.widthAnchor.constraint(equalToConstant: 120),
        logo.heightAnchor.constraint(equalToConstant: 120),
      ])

      splashOverlay = overlay
    }

    // Allow Flutter to hide the native overlay on first frame.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "fortunelog/splash", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "hide" {
          self?.hideSplashOverlay()
          result(nil)
          return
        }
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func hideSplashOverlay() {
    guard let overlay = splashOverlay else { return }
    splashOverlay = nil

    UIView.animate(withDuration: 0.22, delay: 0.05, options: [.curveEaseOut]) {
      overlay.alpha = 0.0
    } completion: { _ in
      overlay.removeFromSuperview()
    }
  }
}
