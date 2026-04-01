//
//  ServerAPI.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import Foundation

class ServerAPI {
    private(set) var isConnected: Bool = false

    var onNewMessage: ((NewMessageServerPayload) -> Void)?
    var onRequestedMessages: ((RequestedMessagesServerPayload) -> Void)?
    var onError: ((String) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    private let webSocketClient: WebSocketManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.webSocketClient = WebSocketManager(url: API.webSocketURL, session: session)
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        webSocketClient.onConnectionChanged = { [weak self] connected in
            self?.updateConnectionState(connected)
        }

        webSocketClient.onError = { [weak self] error in
            self?.onError?(error)
        }

        webSocketClient.onTextMessage = { [weak self] text in
            self?.handleIncoming(text)
        }
    }

    func connect() {
        webSocketClient.connect()
    }

    func disconnect() {
        webSocketClient.disconnect()
    }

    func sendMessage(text: String, sender: Sender) {
        let event: ClientEvent = .sendMessage(SendMessagePayload(text: text, sender: sender))
        send(event)
    }

    func getAllMessages(fromID: Int) {
        let event: ClientEvent = .getAllMessagesFrom(GetAllMessagesFromPayload(fromId: fromID))
        send(event)
    }

    private func send(_ event: ClientEvent) {
        do {
            let data = try encoder.encode(event)
            guard let text = String(data: data, encoding: .utf8) else {
                onError?("Failed to encode websocket payload")
                return
            }

            webSocketClient.send(text: text)
        } catch {
            onError?(error.localizedDescription)
        }
    }

    private func handleIncoming(_ text: String) {
        do {
            guard let data = text.data(using: .utf8) else {
                onError?("Invalid UTF-8 payload")
                return
            }

            let event = try decoder.decode(ServerEvent.self, from: data)

            switch event {
            case .newMessage(let payload):
                onNewMessage?(payload)
            case .requestedMessages(let payload):
                onRequestedMessages?(payload)
            case .error(let payload):
                onError?(payload.message)
            }
        } catch {
            onError?(error.localizedDescription)
        }
    }

    private func updateConnectionState(_ connected: Bool) {
        guard isConnected != connected else { return }
        isConnected = connected
        onConnectionChanged?(connected)
    }
}
