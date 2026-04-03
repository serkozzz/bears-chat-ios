//
//  bears_chat_iosApp.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import SwiftUI

@main
struct bears_chat_iosApp: App {
    private let serverAPI = ServerAPI()

    init() {
        serverAPI.connect()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(serverAPI: serverAPI)
                //.gradientBackground()
        }
    }
}
