//
//  LoginViewModel.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 05.04.2026.
//

import SwiftUI
import Combine

class LoginViewModel: ObservableObject {
    private let serverAPI: ServerAPI
    private let onSuccess: ((String) -> Void)?
    
    @Published var isRegistering = false
    @Published var error: UIError?
    @Published var phoneNumber = ""
    @Published var verificationURLToOpen: URL?
    
    init(serverAPI: ServerAPI,
         onSuccess: ((String) -> Void)? ) {
        self.serverAPI = serverAPI
        self.onSuccess = onSuccess
    }
    
    var isLoginDisabled: Bool {
        phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRegistering
    }
    
    func requestTelegramVerification() {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        isRegistering = true

        serverAPI.registerForTelegramVerification(phoneNumber: phoneNumber, deviceId: deviceID) { result in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                isRegistering = false
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
                    onSuccess?(phoneNumber)
                case .failure(let error):
                    self.error = .init(message: error.localizedDescription)
                }
            }
        }
    }
}
