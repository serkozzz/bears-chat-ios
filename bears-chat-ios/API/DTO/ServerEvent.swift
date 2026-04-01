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

enum ServerEvent: Decodable {
    case newMessage(Message)
    case messages([Message])
    case error(ServerErrorPayload)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum EventType: String, Codable {
        case newMessage
        case messages
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EventType.self, forKey: .type)

        switch type {
        case .newMessage:
            let payload = try container.decode(Message.self, forKey: .payload)
            self = .newMessage(payload)
        case .messages:
            let payload = try container.decode([Message].self, forKey: .payload)
            self = .messages(payload)
        case .error:
            let payload = try container.decode(ServerErrorPayload.self, forKey: .payload)
            self = .error(payload)
        }
    }
}
