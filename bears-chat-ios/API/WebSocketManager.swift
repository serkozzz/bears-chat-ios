//
//  WebSocketClient.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 01.04.2026.
//

import Foundation

final class WebSocketManager {
    var onTextMessage: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    private(set) var isConnected: Bool = false

    private let url: URL
    private let session: URLSession
    private let reconnectDelay: TimeInterval

    private var socketTask: URLSessionWebSocketTask?
    private var shouldReconnect = true
    private var reconnectWorkItem: DispatchWorkItem?

    init(url: URL, session: URLSession = .shared, reconnectDelay: TimeInterval = 1.5) {
        self.url = url
        self.session = session
        self.reconnectDelay = reconnectDelay
    }

    func connect() {
        shouldReconnect = true
        openSocket()
    }

    func disconnect() {
        shouldReconnect = false
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        updateConnectionState(false)
    }

    func send(text: String) {
        guard let socketTask else { return }

        socketTask.send(.string(text)) { [weak self] error in
            if let error {
                self?.onError?(error.localizedDescription)
            }
        }
    }

    private func openSocket() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil

        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil

        let task = session.webSocketTask(with: url)
        socketTask = task
        task.resume()
        updateConnectionState(true)
        receiveNextSocketMessage()
    }

    private func receiveNextSocketMessage() {
        guard let socketTask else { return }

        socketTask.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                self.onError?(error.localizedDescription)
                self.updateConnectionState(false)
                self.rescheduleReconnectIfNeeded()
            case .success(let message):
                self.handleIncoming(message)
                self.receiveNextSocketMessage()
            }
        }
    }

    private func handleIncoming(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            onTextMessage?(text)
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8) else {
                onError?("Invalid UTF-8 payload")
                return
            }
            onTextMessage?(text)
        @unknown default:
            onError?("Unsupported websocket message")
        }
    }

    private func rescheduleReconnectIfNeeded() {
        guard shouldReconnect else { return }
        guard reconnectWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            guard self.shouldReconnect else { return }
            self.openSocket()
        }

        reconnectWorkItem = workItem
        DispatchQueue.global().asyncAfter(deadline: .now() + reconnectDelay, execute: workItem)
    }

    private func updateConnectionState(_ connected: Bool) {
        guard isConnected != connected else { return }
        isConnected = connected
        onConnectionChanged?(connected)
    }
}
