//
//  ChatViewModel.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published private(set) var history: [Message] = []
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var lastError: String = ""

    private let sender: Sender
    private let serverAPI: ServerAPI
    private var messagesByID: [Int: Message] = [:]

    init (userName: String) {
        self.sender = Sender(userName: userName)
        self.serverAPI = ServerAPI()

        serverAPI.onConnectionChanged = { [weak self] connected in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isConnected = connected
                if connected {
                    let fromID = self.lastMessageID == 0 ? 0 : self.lastMessageID + 1
                    self.serverAPI.getAllMessages(fromID: fromID)
                }
            }
        }

        serverAPI.onMessages = { [weak self] messages in
            DispatchQueue.main.async {
                self?.merge(messages)
            }
        }

        serverAPI.onNewMessage = { [weak self] message in
            DispatchQueue.main.async {
                guard let self else { return }

                if message.id - self.lastMessageID > 1 {
                    self.serverAPI.getAllMessages(fromID: self.lastMessageID + 1)
                }

                self.merge([message])
            }
        }

        serverAPI.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = error
            }
        }

        serverAPI.connect()
    }

    deinit {
        serverAPI.disconnect()
    }

    private var lastMessageID: Int {
        history.last?.id ?? 0
    }

    private func merge(_ messages: [Message]) {
        for message in messages {
            messagesByID[message.id] = message
        }

        history = messagesByID
            .values
            .sorted(by: { $0.id < $1.id })
    }
    
    func isOwnMessage(_ message: Message) -> Bool {
        message.sender == sender
    }
    
    func send(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        serverAPI.sendMessage(text: cleanText, sender: sender)
    }
}
