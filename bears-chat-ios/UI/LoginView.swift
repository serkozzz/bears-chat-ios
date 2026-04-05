//
//  LoginView.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 31.03.2026.
//

import SwiftUI
import UIKit

struct LoginView: View {
    
    @StateObject var model: LoginViewModel
    
    @FocusState private var isPhoneInputFocused: Bool
    @Environment(\.openURL) var openURL
    
    
    init(serverAPI: ServerAPI, onSuccess: ((String) -> Void)?) {
        let model = LoginViewModel(serverAPI: serverAPI, onSuccess: onSuccess)
        self._model = StateObject(wrappedValue: model)
    }
    
    var body: some View {
        VStack {
            Image(.launchLogo).resizable().frame(width: 400, height: 400)
            switch model.state {
            case .enteringPhone:
                enteringPhoneView
            case .waitingTelegramConfirmation:
                waitingTelegramConfirmation
            }
            
            if model.isLoading {
                ProgressView()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isPhoneInputFocused = false
        }
        .onChange(of: model.verificationURLToOpen) { _, url in
            guard let url else { return }
            openURL(url)
            model.verificationURLToOpen = nil
        }
        .gradientBackground()
        .alert(item: $model.error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .cancel(Text("OK"))
            )
        }
    }
    
    var enteringPhoneView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Номер телефона:")
                TextField("79ххххххххх", text: $model.phoneNumber)
                    .frame(maxWidth: 200)
                    .focused($isPhoneInputFocused)
            }
            Button("Подтвердить") {
                isPhoneInputFocused = false
                model.requestLinkForTelegramVerification()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isLoginDisabled)
        }
        .padding()
        .background{
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.white))
        }
    }
    
    var waitingTelegramConfirmation: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Ожидаем подтверждения номера в Telegram.")
                TextField("79ххххххххх", text: $model.phoneNumber)
                    .frame(maxWidth: 200)
                    .disabled(true)
                Text("В боте нажмите Start и поделитесь номером")
                Button("Открыть Telegram снова") {
                    model.requestLinkForTelegramVerification()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background{
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.white))
        }
    }
}

#Preview {
    LoginView(serverAPI: ServerAPI(), onSuccess: {_ in })
}
