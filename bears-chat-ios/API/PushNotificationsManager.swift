import Foundation
import UIKit
import UserNotifications

final class PushNotificationsManager {
    static let shared = PushNotificationsManager()

    var onTokenReceived: ((String) -> Void)?

    private init() {}

    func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications() //запросить у Apple push-токен для этого app+device,
                    //если успешно, вызовется appDelegate didRegisterForRemoteNotificationsWithDeviceToken,
                    //если нет, вызовется didFailToRegisterForRemoteNotificationsWithError.
            }
        }
    }

    func mapDeviceToken(_ deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02x", $0) }.joined()
    }
}
