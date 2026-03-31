//
//  Sender.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

struct Sender: Codable {
    var userName: String
    
    static func == (lhs: Sender, rhs: Sender) -> Bool {
        lhs.userName == rhs.userName
    }
}
