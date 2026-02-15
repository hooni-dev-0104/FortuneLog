import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Prevent white flash between LaunchScreen and Flutter first frame.
    // Keep this in sync with the brand splash background.
    let brandGreen = UIColor(red: 15.0/255.0, green: 123.0/255.0, blue: 100.0/255.0, alpha: 1.0)
    window?.backgroundColor = brandGreen
    window?.rootViewController?.view.backgroundColor = brandGreen

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
