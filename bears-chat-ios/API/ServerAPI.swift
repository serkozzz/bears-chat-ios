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
    private let urlSession: URLSession
    private var pushToken: String?

    init() {
        self.urlSession = .shared
        self.webSocketClient = WebSocketManager(url: API.webSocketURL)
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

    func sendMessage(text: String, sender: SenderDTO) {
        let event: ClientEvent = .sendMessage(SendMessagePayload(text: text, sender: sender))
        send(event)
    }

    func getAllMessages(fromID: Int) {
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

    func registerForTelegramVerification(
        phoneNumber: String,
        deviceId: String,
        completion: @escaping (Result<AuthRegisterResponseDTO, Error>) -> Void
    ) {
        let cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDeviceID = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanPhone.isEmpty, !cleanDeviceID.isEmpty else {
            completion(.failure(NSError(domain: "ServerAPI", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Phone number and device ID are required"
            ])))
            return
        }

        let body = AuthRegisterRequestDTO(phoneNumber: cleanPhone, deviceId: cleanDeviceID)

        do {
            let data = try encoder.encode(body)
            var request = URLRequest(url: API.authRegisterURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            urlSession.dataTask(with: request) { [weak self] data, response, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "ServerAPI", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid server response"
                    ])))
                    return
                }

                guard let data else {
                    completion(.failure(NSError(domain: "ServerAPI", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "Empty server response"
                    ])))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let fallbackMessage = "Auth register failed with status \(httpResponse.statusCode)"
                    if let message = self?.extractMessage(from: data) {
                        completion(.failure(NSError(domain: "ServerAPI", code: 4, userInfo: [
                            NSLocalizedDescriptionKey: message
                        ])))
                    } else {
                        completion(.failure(NSError(domain: "ServerAPI", code: 4, userInfo: [
                            NSLocalizedDescriptionKey: fallbackMessage
                        ])))
                    }
                    return
                }

                do {
                    let result = try self?.decoder.decode(AuthRegisterResponseDTO.self, from: data)
                    if let result {
                        completion(.success(result))
                    } else {
                        completion(.failure(NSError(domain: "ServerAPI", code: 5, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode auth response"
                        ])))
                    }
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
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

    private func extractMessage(from data: Data) -> String? {
        struct ErrorPayload: Decodable {
            let message: String
        }
        return try? decoder.decode(ErrorPayload.self, from: data).message
    }
}
