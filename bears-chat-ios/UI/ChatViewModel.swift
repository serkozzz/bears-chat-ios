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
    @Published private var senderIdToDisplayNameMap: [String: String] = [:]

    private let sender: SenderDTO
    private let serverAPI: ServerAPI
    private let senderContactsService: SenderContactsService
    private let onLogout: (() -> Void)?
    private var currentHistoryGeneration: String?
    private var resolvedSenderIDs: Set<String> = []

    init(
        userName: String,
        serverAPI: ServerAPI,
        senderContactsService: SenderContactsService = .shared,
        onLogout: (() -> Void)? = nil
    ) {
        self.sender = SenderDTO(userName: userName)
        self.serverAPI = serverAPI
        self.senderContactsService = senderContactsService
        self.onLogout = onLogout
        serverAPI.registerPushTokenIfAvailable(userName: userName)
        senderContactsService.requestAccessIfNeeded()

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

        syncConnectionState(serverAPI.isConnectedAndAuthorized)

        serverAPI.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = UIError(message: error)
            }
        }
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

    //мерж существующей на данный момент истории с новыми сообщениями
    private func merge(_ messages: [MessageDTO]) {
        var mergedByID = messagesByID
        for message in messages {
            mergedByID[message.id] = message
            resolveSenderDisplayNameIfNeeded(senderID: message.sender.userName)
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

    func displaySenderName(for message: MessageDTO) -> String {
        senderIdToDisplayNameMap[message.sender.userName] ?? message.sender.userName
    }

    private func resolveSenderDisplayNameIfNeeded(senderID: String) {
        let cleanSenderID = senderID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSenderID.isEmpty else { return }
        guard !resolvedSenderIDs.contains(cleanSenderID) else { return }
        resolvedSenderIDs.insert(cleanSenderID)

        senderContactsService.resolveDisplayName(for: cleanSenderID) { [weak self] displayName in
            guard let self, let displayName else { return }
            self.senderIdToDisplayNameMap[cleanSenderID] = displayName
        }
    }
}


extension ChatViewModel {
    func logOut() {
        serverAPI.logout()
        onLogout?()
    }
}
