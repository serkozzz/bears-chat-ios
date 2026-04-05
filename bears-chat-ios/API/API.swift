//
//  Endpoint.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import Foundation

enum API {
    // static let baseURL = URL(string: "http://127.0.0.1:3000")!
    static let baseURL = URL(string: "http://84.201.150.183:3000")!

    static var webSocketURL: URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.scheme = (components.scheme == "https") ? "wss" : "ws"
        return components.url!
    }

    static var registerPushTokenURL: URL {
        baseURL.appendingPathComponent("push/register")
    }

    static var authRegisterURL: URL {
        baseURL.appendingPathComponent("auth/register")
    }
}
