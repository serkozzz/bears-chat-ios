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
    private let sender: Sender
    
    init (userName: String) {
        self.sender = Sender(userName: userName)
        history.append(Message(id: 0, text: "Hello", sender: sender, date: Date()))
        history.append(Message(id: 1, text: "How are you?", sender: Sender(userName: "bot"), date: Date()))
        history.append(Message(id: 2, text: "I am fine", sender: sender, date: Date()))
    }
    
    func isOwnMessage(_ message: Message) -> Bool {
        message.sender == sender
    }
    
    func send(_ text: String) {
        let newMessage = Message(id: history.count, text: text, sender: sender, date: Date())
        history.append(newMessage)
    }
}
