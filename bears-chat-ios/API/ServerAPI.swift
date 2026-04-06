//
//  ServerAPI.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import Foundation

enum ServerAPIError: LocalizedError {
    case missingRequiredParameters([String])
    case invalidURL
    case invalidResponse
    case emptyResponse
    case httpStatus(code: Int, message: String?)
    case decodingFailed(type: String)
    case encodingFailed(underlying: Error)
    case network(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .missingRequiredParameters(let names):
            let joined = names.joined(separator: ", ")
            return "Required parameters are missing: \(joined)"
        case .invalidURL:
            return "Failed to build request URL"
        case .invalidResponse:
            return "Invalid server response"
        case .emptyResponse:
            return "Empty server response"
        case .httpStatus(let code, let message):
            return message ?? "Request failed with status \(code)"
        case .decodingFailed(let type):
            return "Failed to decode response: \(type)"
        case .encodingFailed(let underlying):
            return "Failed to encode request: \(underlying.localizedDescription)"
        case .network(let underlying):
            return underlying.localizedDescription
        }
    }
}

class ServerAPI {
    private(set) var isConnectedAndAuthorized: Bool = false

    var onNewMessage: ((NewMessageServerPayload) -> Void)?
    var onRequestedMessages: ((RequestedMessagesServerPayload) -> Void)?
    var onError: ((String) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    private let webSocketClient: WebSocketManager
    private let authSessionStorage: AuthSessionStorage
    private var pushToken: String?
    private var isWebSocketConnected = false
    private var isAuthorized = false

    var hasAccessToken: Bool {
        accessToken != nil
    }
    private(set) var accessToken: String?
    
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let urlSession: URLSession

    init(authSessionStorage: AuthSessionStorage = .shared) {
        self.authSessionStorage = authSessionStorage
        self.urlSession = .shared
        self.webSocketClient = WebSocketManager(url: API.webSocketURL)
        self.accessToken = authSessionStorage.loadAccessToken()
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        webSocketClient.onConnectionChanged = { [weak self] connected in
            self?.handleTransportConnectionChanged(connected)
        }

        webSocketClient.onError = { [weak self] error in
            self?.onError?(error)
        }

        webSocketClient.onTextMessage = { [weak self] text in
            self?.handleIncoming(text)
        }
    }

    func connect() {
        guard accessToken != nil else { return }
        webSocketClient.connect()
    }

    func disconnect() {
        webSocketClient.disconnect()
        isWebSocketConnected = false
        isAuthorized = false
        updateConnectionState(false)
    }

    func sendMessage(text: String, sender: SenderDTO) {
        guard isConnectedAndAuthorized else {
            onError?("Socket is not authorized yet")
            return
        }
        let event: ClientEvent = .sendMessage(SendMessagePayload(text: text, sender: sender))
        send(event)
    }

    func getAllMessages(fromID: Int) {
        guard isConnectedAndAuthorized else {
            onError?("Socket is not authorized yet")
            return
        }
        let event: ClientEvent = .getAllMessagesFrom(GetAllMessagesFromPayload(fromId: fromID))
        send(event)
    }

    func updatePushToken(_ token: String) {
        guard !token.isEmpty else { return }
        guard pushToken != token else { return }
        pushToken = token
        registerPushToken(userName: nil)
    }

    func registerPushTokenIfAvailable(userName: String) {
        guard !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        registerPushToken(userName: userName)
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
            case .authorized:
                print("[ServerAPI] received authorized event")
                isAuthorized = true
                updateConnectionState(isWebSocketConnected && isAuthorized)
            case .newMessage(let payload):
                onNewMessage?(payload)
            case .requestedMessages(let payload):
                onRequestedMessages?(payload)
            case .error(let payload):
                print("[ServerAPI] received error event: \(payload.message)")
                onError?(payload.message)
            }
        } catch {
            onError?(error.localizedDescription)
        }
    }

    private func updateConnectionState(_ connected: Bool) {
        guard isConnectedAndAuthorized != connected else { return }
        print("[ServerAPI] onConnectionChanged: \(connected) (ws=\(isWebSocketConnected), authorized=\(isAuthorized))")
        isConnectedAndAuthorized = connected
        onConnectionChanged?(connected)
    }

    func logout() {
        revokeAccessTokenOnServerIfNeeded()
        accessToken = nil
        authSessionStorage.clearAll()
        disconnect()
    }

    private func revokeAccessTokenOnServerIfNeeded() {
        guard let accessToken, !accessToken.isEmpty else { return }
        let body = AuthLogoutRequestDTO(accessToken: accessToken)

        do {
            let data = try encoder.encode(body)
            var request = URLRequest(url: API.authLogoutURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            urlSession.dataTask(with: request) { _, response, error in
                if error != nil {
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else { return }
                if !(200...299).contains(httpResponse.statusCode) { return }
            }.resume()
        } catch {
            return
        }
    }

    private func registerPushToken(userName: String?) {
        guard let pushToken else { return }

        let body = RegisterPushTokenDTO(token: pushToken, userName: userName)

        do {
            let data = try encoder.encode(body)
            var request = URLRequest(url: API.registerPushTokenURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            urlSession.dataTask(with: request) { [weak self] _, response, error in
                if let error {
                    self?.onError?(error.localizedDescription)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.onError?("Push token registration: invalid response")
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    self?.onError?("Push token registration failed with status \(httpResponse.statusCode)")
                    return
                }
            }.resume()
        } catch {
            onError?(error.localizedDescription)
        }
    }

    func extractMessage(from data: Data) -> String? {
        struct ErrorPayload: Decodable {
            let message: String
        }
        return try? decoder.decode(ErrorPayload.self, from: data).message
    }

    private func handleTransportConnectionChanged(_ connected: Bool) {
        print("[ServerAPI] transport connection changed: \(connected)")
        isWebSocketConnected = connected

        if !connected {
            isAuthorized = false
            updateConnectionState(false)
            return
        }

        isAuthorized = false
        guard let accessToken else {
            print("[ServerAPI] transport is up, but access token is missing")
            updateConnectionState(false)
            return
        }
        print("[ServerAPI] sending auth event")
        send(.auth(AuthPayload(accessToken: accessToken)))
    }

    func applyAccessTokenIfNeeded(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        guard accessToken != token else { return }
        accessToken = token
        authSessionStorage.saveAccessToken(token)
        if isWebSocketConnected {
            send(.auth(AuthPayload(accessToken: token)))
        } else {
            connect()
        }
    }
}
