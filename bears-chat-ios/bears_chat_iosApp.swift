//
//  bears_chat_iosApp.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        PushNotificationsManager.shared.requestAuthorizationAndRegister()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = PushNotificationsManager.shared.mapDeviceToken(deviceToken)
        PushNotificationsManager.shared.onTokenReceived?(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

@main
struct bears_chat_iosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let serverAPI = ServerAPI()

    init() {
        serverAPI.connect()
        PushNotificationsManager.shared.onTokenReceived = { [serverAPI] token in
            serverAPI.updatePushToken(token)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(serverAPI: serverAPI)
                //.gradientBackground()
        }
    }
}
