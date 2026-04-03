//
//  ChatViewModel.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published private(set) var history: [MessageDTO] = []
    @Published private var messagesByID: [Int: MessageDTO] = [:]
    @Published private(set) var isConnected: Bool = false
    @Published var lastError: UIError?

    private let sender: SenderDTO
    private let serverAPI: ServerAPI
    private var currentHistoryGeneration: String?

    init(userName: String, serverAPI: ServerAPI) {
        self.sender = SenderDTO(userName: userName)
        self.serverAPI = serverAPI
        serverAPI.registerPushTokenIfAvailable(userName: userName)

        serverAPI.onConnectionChanged = { [weak self] connected in
            DispatchQueue.main.async {
                guard let self else { return }
                self.syncConnectionState(connected)
            }
        }

        serverAPI.onRequestedMessages = { [weak self] payload in
            DispatchQueue.main.async {
                self?.handleRequestedMessages(payload)
            }
        }

        serverAPI.onNewMessage = { [weak self] payload in
            DispatchQueue.main.async {
                guard let self else { return }
                let message = payload.message

                if self.currentHistoryGeneration != nil && self.currentHistoryGeneration != payload.historyGeneration {
                    self.currentHistoryGeneration = payload.historyGeneration
                    self.clearHistory()
                    self.serverAPI.getAllMessages(fromID: 0)
                }

                if self.currentHistoryGeneration == nil {
                    self.currentHistoryGeneration = payload.historyGeneration
                }

                if message.id - self.lastMessageID > 1 {
                    self.serverAPI.getAllMessages(fromID: self.lastMessageID + 1)
                }

                self.merge([message])
            }
        }

        syncConnectionState(serverAPI.isConnected)

        serverAPI.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = UIError(message: error)
            }
        }
    }

    deinit {
        serverAPI.onConnectionChanged = nil
        serverAPI.onRequestedMessages = nil
        serverAPI.onNewMessage = nil
        serverAPI.onError = nil
    }

    private var lastMessageID: Int {
        messagesByID.keys.max() ?? 0
    }

    private func syncConnectionState(_ connected: Bool) {
        isConnected = connected
        if connected {
            requestMissedMessages()
        }
    }

    private func requestMissedMessages() {
        let fromID = lastMessageID == 0 ? 0 : lastMessageID + 1
        serverAPI.getAllMessages(fromID: fromID)
    }

    private func handleRequestedMessages(_ payload: RequestedMessagesServerPayload) {
        if currentHistoryGeneration != nil && currentHistoryGeneration != payload.historyGeneration {
            currentHistoryGeneration = payload.historyGeneration
            clearHistory()
            serverAPI.getAllMessages(fromID: 0)
        }

        if currentHistoryGeneration == nil {
            currentHistoryGeneration = payload.historyGeneration
        }

        merge(payload.messages)
    }

    private func clearHistory() {
        messagesByID.removeAll()
        history = []
    }

    private func merge(_ messages: [MessageDTO]) {
        var mergedByID = messagesByID
        for message in messages {
            mergedByID[message.id] = message
        }

        messagesByID = mergedByID
        history = mergedByID.values.sorted(by: { $0.id < $1.id })
    }
    
    func isOwnMessage(_ message: MessageDTO) -> Bool {
        message.sender == sender
    }
    
    func send(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        serverAPI.sendMessage(text: cleanText, sender: sender)
    }
}
