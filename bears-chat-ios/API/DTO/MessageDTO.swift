//
//  Message.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import Foundation

struct MessageDTO: Codable {
    let id: Int
    let text: String
    let sender: SenderDTO
    let date: Date
}
