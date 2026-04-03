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
    private let dateFormatter: DateFormatter
   
    
    @AppStorage("chatBackgroundColorHex") private var backgroundColorHex = "#FFFFFF"
    
    private var backgroundColorBinding: Binding<Color> {
        Binding(
            get: {  ColorHex.fromHex(backgroundColorHex) ?? .white },
            set: { newValue in
                backgroundColorHex = ColorHex.toHex(newValue) ?? "#FFFFFF"
            }
        )
    }

    @State private var isSettingsSheetPresented: Bool = false
    
    init(userName: String, serverAPI: ServerAPI) {
        _model = StateObject(wrappedValue: .init(userName: userName, serverAPI: serverAPI))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        self.dateFormatter = formatter
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(model.isConnected ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundColor(model.isConnected ? .green : .red)
                Spacer()
                
                Button() {
                    isSettingsSheetPresented = true
                } label: {
                    Image(systemName: "gear")
                }
            }
            .padding(.horizontal, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.history, id: \.id) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: model.history.count) {
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
                .disabled(
                    !model.isConnected ||
                    inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            .padding([.horizontal, .bottom], 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColorBinding.wrappedValue)
        .sheet(isPresented: $isSettingsSheetPresented) {
            NavigationStack {
                Form {
                    ColorPicker("Background color", selection: backgroundColorBinding, supportsOpacity: false)
                }
                .navigationTitle("Settings")
            }
            .presentationDetents([.medium])
        }
        .alert(item: $model.lastError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .cancel(Text("OK"))
            )
        }
    }
    
    private func messageRow(_ message: MessageDTO) -> some View {
        HStack {
            let isOwn = model.isOwnMessage(message)
            if isOwn {
                Spacer(minLength: 0)
            }
            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                Text("#\(message.id) \(message.sender.userName) \(dateFormatter.string(from: message.date))")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Text(message.text)
                    .foregroundColor(.black)
            }
            .padding(8)
            .background(isOwn ? Color(red: 0.76, green: 0.93, blue: 0.82) : Color.white)
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
