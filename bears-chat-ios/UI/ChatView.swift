//
//  ChatView.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import SwiftUI

struct ChatView: View {
    
    @StateObject private var model: ChatViewModel
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    
    init(userName: String) {
        _model = StateObject(wrappedValue: .init(userName: userName))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.history, id: \.id) { message in
                            messageRow(message)
                                //.id(message.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: model.history.count) { _ in
                    if let last = model.history.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            
            VStack(spacing: 8) {
                TextEditor(text: $inputText)
                    .frame(minHeight: 40, maxHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .focused($isInputFocused)
                
                Button("Send") {
                    model.send(inputText)
                    inputText = ""
                    
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding([.horizontal, .bottom], 8)
        }
        .background(Color.white.ignoresSafeArea())
    }
    
    private func messageRow(_ message: Message) -> some View {
        HStack {
            let isOwn = model.isOwnMessage(message)
            if isOwn {
                Spacer(minLength: 0)
            }
            Text(message.text)
                .padding(8)
                .background(isOwn ? Color.gray.opacity(0.2) : Color.white)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
            if !isOwn {
                Spacer(minLength: 0)
            }
        }
    }
}
