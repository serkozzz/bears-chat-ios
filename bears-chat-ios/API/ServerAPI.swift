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
            completion(.failure(ServerAPIError.missingRequiredParameters(["phoneNumber", "deviceId"])))
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
                    completion(.failure(ServerAPIError.network(underlying: error)))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(ServerAPIError.invalidResponse))
                    return
                }

                guard let data else {
                    completion(.failure(ServerAPIError.emptyResponse))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = self?.extractMessage(from: data)
                    completion(.failure(ServerAPIError.httpStatus(code: httpResponse.statusCode, message: message)))
                    return
                }

                do {
                    let result = try self?.decoder.decode(AuthRegisterResponseDTO.self, from: data)
                    if let result {
                        completion(.success(result))
                    } else {
                        completion(.failure(ServerAPIError.decodingFailed(type: "AuthRegisterResponseDTO")))
                    }
                } catch {
                    completion(.failure(ServerAPIError.decodingFailed(type: "AuthRegisterResponseDTO")))
                }
            }.resume()
        } catch {
            completion(.failure(ServerAPIError.encodingFailed(underlying: error)))
        }
    }

    func getAuthStatus(
        phoneNumber: String,
        deviceId: String,
        completion: @escaping (Result<AuthStatusResponseDTO, Error>) -> Void
    ) {
        let cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDeviceID = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = AuthStatusRequestDTO(phoneNumber: cleanPhone, deviceId: cleanDeviceID)

        guard !cleanPhone.isEmpty, !cleanDeviceID.isEmpty else {
            completion(.failure(ServerAPIError.missingRequiredParameters(["phoneNumber", "deviceId"])))
            return
        }

        var components = URLComponents(url: API.authStatusURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "phoneNumber", value: query.phoneNumber),
            URLQueryItem(name: "deviceId", value: query.deviceId)
        ]

        guard let url = components?.url else {
            completion(.failure(ServerAPIError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        urlSession.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                completion(.failure(ServerAPIError.network(underlying: error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(ServerAPIError.invalidResponse))
                return
            }

            if httpResponse.statusCode == 404 {
                completion(.success(AuthStatusResponseDTO(isVerified: false)))
                return
            }

            guard let data else {
                completion(.failure(ServerAPIError.emptyResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = self?.extractMessage(from: data)
                completion(
                    .failure(
                        ServerAPIError.httpStatus(code: httpResponse.statusCode, message: message)
                    )
                )
                return
            }

            do {
                let result = try self?.decoder.decode(AuthStatusResponseDTO.self, from: data)
                if let result {
                    completion(.success(result))
                } else {
                    completion(.failure(ServerAPIError.decodingFailed(type: "AuthStatusResponseDTO")))
                }
            } catch {
                completion(.failure(ServerAPIError.decodingFailed(type: "AuthStatusResponseDTO")))
            }
        }.resume()
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
