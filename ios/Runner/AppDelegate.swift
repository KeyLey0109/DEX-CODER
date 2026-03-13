import UIKit
import Flutter
import flutter_local_notifications // Bắt buộc phải import dòng này

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 1. Đăng ký callback cho plugin thông báo (Bắt buộc để tránh crash khi app chạy ngầm)
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }
    
    // 2. Cấp quyền hiển thị thông báo popup khi app đang mở trên màn hình (Foreground)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    // 3. Đăng ký toàn bộ các plugin còn lại của Flutter
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}