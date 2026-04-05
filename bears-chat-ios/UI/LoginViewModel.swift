//
//  LoginViewModel.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 05.04.2026.
//

import SwiftUI
import Combine

class LoginViewModel: ObservableObject {
    
    enum State {
        case enteringPhone
        case waitingTelegramConfirmation
    }
    
    private let serverAPI: ServerAPI
    private let onSuccess: ((String) -> Void)?
    
    @Published var state = State.enteringPhone
    @Published var isLoading = false
    @Published var error: UIError?
    @Published var phoneNumber = ""
    @Published var verificationURLToOpen: URL?
    
    init(serverAPI: ServerAPI,
         onSuccess: ((String) -> Void)? ) {
        self.serverAPI = serverAPI
        self.onSuccess = onSuccess
    }
    
    var isLoginDisabled: Bool {
        phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
    }
    
    func requestLinkForTelegramVerification() {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        isLoading = true

        serverAPI.registerForTelegramVerification(phoneNumber: phoneNumber, deviceId: deviceID) { result in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                isLoading = false
                state = .waitingTelegramConfirmation
                switch result {
                case .success(let payload):
                    if payload.isVerified {
                        onSuccess?(phoneNumber)
                        return
                    }

                    guard let verificationUrl = payload.verificationUrl,
                          let url = URL(string: verificationUrl) else {
                        self.error = .init(message: "Ссылка верификации не получена")
                        return
                    }
                    self.verificationURLToOpen = url
                case .failure(let error):
                    self.error = .init(message: error.localizedDescription)
                }
            }
        }
    }
}
