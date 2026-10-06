import UIKit
import Flutter
import GoogleMaps
import FirebaseCore
import FirebaseAppCheck
import FirebaseAuth
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String,
       !mapsKey.isEmpty {
      GMSServices.provideAPIKey(mapsKey)
    }
    // This is required to make any communication available in the action isolate.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    #if DEBUG && targetEnvironment(simulator)
    // DeviceCheck/App Attest cannot attest a simulator. This still requires an
    // explicitly registered, scoped Firebase App Check debug token.
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
    #endif
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
