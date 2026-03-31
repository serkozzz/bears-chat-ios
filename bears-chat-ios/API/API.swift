//
//  Endpoint.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import Foundation

enum API {
    
    //    static let baseURL = URL(string: "http://127.0.0.1:3000")!
    static let baseURL = URL(string: "http://84.201.150.183:3000")!
    
    enum Endpoints {
        static let sendMessage = baseURL.appending(path: "sendMessage")
        static let getAllMessagesFrom = baseURL.appending(path: "getAllMessagesFrom")

    }
}
