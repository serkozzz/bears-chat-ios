//
//  ServerEvent.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import Foundation


struct ServerErrorPayload: Codable {
    let message: String
}

struct NewMessageServerPayload: Codable {
    let historyGeneration: String
    let message: Message
}

struct RequestedMessagesServerPayload: Codable {
    let historyGeneration: String
    let messages: [Message]
}

enum ServerEvent: Decodable {
    case newMessage(NewMessageServerPayload)
    case requestedMessages(RequestedMessagesServerPayload) // server sends requested history chunk
    case error(ServerErrorPayload)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum EventType: String, Codable {
        case newMessage
        case requestedMessages
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EventType.self, forKey: .type)

        switch type {
        case .newMessage:
            let payload = try container.decode(NewMessageServerPayload.self, forKey: .payload)
            self = .newMessage(payload)
        case .requestedMessages:
            let payload = try container.decode(RequestedMessagesServerPayload.self, forKey: .payload)
            self = .requestedMessages(payload)
        case .error:
            let payload = try container.decode(ServerErrorPayload.self, forKey: .payload)
            self = .error(payload)
        }
    }
}
