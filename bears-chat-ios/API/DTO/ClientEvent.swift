//
//  ClientEvent.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import Foundation

struct SendMessagePayload: Codable {
    let text: String
    let sender: SenderDTO
}

struct GetAllMessagesFromPayload: Codable {
    let fromId: Int
}

enum ClientEvent: Encodable {
    case sendMessage(SendMessagePayload)
    case getAllMessagesFrom(GetAllMessagesFromPayload)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .sendMessage(let payload):
            try container.encode("sendMessage", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .getAllMessagesFrom(let payload):
            try container.encode("getAllMessagesFrom", forKey: .type)
            try container.encode(payload, forKey: .payload)
        }
    }
}
