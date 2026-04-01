//
//  ServerAPI.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import Foundation

class ServerAPI {
    var onNewMessage: ((Message) -> Void)?
    var onMessages: (([Message]) -> Void)?
    var onError: ((String) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    private let session: URLSession
    private var socketTask: URLSessionWebSocketTask?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func connect() {
        disconnect()

        let task = session.webSocketTask(with: API.webSocketURL)
        socketTask = task
        task.resume()
        onConnectionChanged?(true)
        receiveNextMessage()
    }

    func disconnect() {
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        onConnectionChanged?(false)
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
        guard let socketTask else { return }

        do {
            let data = try encoder.encode(event)
            guard let text = String(data: data, encoding: .utf8) else {
                onError?("Failed to encode websocket payload")
                return
            }

            socketTask.send(.string(text)) { [weak self] error in
                if let error {
                    self?.onError?(error.localizedDescription)
                }
            }
        } catch {
            onError?(error.localizedDescription)
        }
    }

    private func receiveNextMessage() {
        guard let socketTask else { return }

        socketTask.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                self.onError?(error.localizedDescription)
                self.onConnectionChanged?(false)
            case .success(let message):
                self.handleIncoming(message)
                self.receiveNextMessage()
            }
        }
    }

    private func handleIncoming(_ message: URLSessionWebSocketTask.Message) {
        let data: Data

        switch message {
        case .data(let raw):
            data = raw
        case .string(let raw):
            guard let converted = raw.data(using: .utf8) else {
                onError?("Invalid UTF-8 payload")
                return
            }
            data = converted
        @unknown default:
            onError?("Unsupported websocket message")
            return
        }

        do {
            let event = try decoder.decode(ServerEvent.self, from: data)

            switch event {
            case .newMessage(let message):
                onNewMessage?(message)
            case .messages(let messages):
                onMessages?(messages)
            case .error(let payload):
                onError?(payload.message)
            }
        } catch {
            onError?(error.localizedDescription)
        }
    }
}
