//
//  WebSocketManager.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 01.04.2026.
//

import Foundation

final class WebSocketManager: NSObject {
    var onTextMessage: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    private(set) var isConnected: Bool = false

    private let url: URL
    private let reconnectDelay: TimeInterval
    private let requestTimeout: TimeInterval
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private var socketTask: URLSessionWebSocketTask?
    private var shouldReconnect = true
    private var reconnectWorkItem: DispatchWorkItem?

    init(url: URL, reconnectDelay: TimeInterval = 1.5, requestTimeout: TimeInterval = 5) {
        self.url = url
        self.reconnectDelay = reconnectDelay
        self.requestTimeout = requestTimeout
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
                self?.reportErrorIfNeeded(error)
            }
        }
    }

    private func openSocket() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil

        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil

        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout

        let task = session.webSocketTask(with: request)
        socketTask = task
        task.resume()
        receiveNextSocketMessage()
    }

    private func receiveNextSocketMessage() {
        guard let socketTask else { return }

        socketTask.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                self.reportErrorIfNeeded(error)
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
        print("onConnectionChanged: \(connected)")
        onConnectionChanged?(connected)
    }

    private func reportErrorIfNeeded(_ error: Error) {
        guard WebSocketErrorsHelper.shouldDisplay(error) else { return }
        onError?(error.localizedDescription)
    }
}


extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        updateConnectionState(true)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        updateConnectionState(false)
        rescheduleReconnectIfNeeded()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard task == socketTask else { return }

        if let error {
            reportErrorIfNeeded(error)
        }

        updateConnectionState(false)
        rescheduleReconnectIfNeeded()
    }
}
