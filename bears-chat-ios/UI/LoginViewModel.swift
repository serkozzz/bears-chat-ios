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
    private let authSessionStorage: LastAuthSessionStorage
    
    @Published var state = State.enteringPhone
    @Published var isLoading = false
    @Published var error: UIError?
    @Published var phoneNumber = ""
    @Published var verificationURLToOpen: URL?
    
    init(serverAPI: ServerAPI,
         authSessionStorage: LastAuthSessionStorage = .shared,
         onSuccess: ((String) -> Void)? ) {
        self.serverAPI = serverAPI
        self.authSessionStorage = authSessionStorage
        self.onSuccess = onSuccess
        restoreLastAuthSessionIfNeeded()
    }
    
    var isLoginDisabled: Bool {
        phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
    }
    
    func requestLinkForTelegramVerification() {
        let cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPhone.isEmpty else { return }

        let deviceID = resolveDeviceId()
        authSessionStorage.save(
            LastAuthSession(
                phoneNumber: cleanPhone,
                deviceId: deviceID,
                updatedAt: Date()
            )
        )
        isLoading = true

        serverAPI.registerForTelegramVerification(phoneNumber: cleanPhone, deviceId: deviceID) { result in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                isLoading = false
                switch result {
                case .success(let payload):
                    if payload.isVerified {
                        onSuccess?(cleanPhone)
                        return
                    }

                    guard let verificationUrl = payload.verificationUrl,
                          let url = URL(string: verificationUrl) else {
                        self.error = .init(message: "Ссылка верификации не получена")
                        return
                    }
                    state = .waitingTelegramConfirmation
                    phoneNumber = cleanPhone
                    self.verificationURLToOpen = url
                case .failure(let error):
                    self.error = .init(message: error.localizedDescription)
                }
            }
        }
    }

    func checkVerificationStatus() {
        guard let session = authSessionStorage.load() else { return }
        isLoading = true

        serverAPI.getAuthStatus(phoneNumber: session.phoneNumber, deviceId: session.deviceId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .success(let payload):
                    if payload.isVerified {
                        self.onSuccess?(session.phoneNumber)
                    } else {
                        self.state = .waitingTelegramConfirmation
                        self.phoneNumber = session.phoneNumber
                    }
                case .failure(let error):
                    self.error = .init(message: error.localizedDescription)
                }
            }
        }
    }

    private func restoreLastAuthSessionIfNeeded() {
        guard let session = authSessionStorage.load() else { return }
        phoneNumber = session.phoneNumber
    }

    private func resolveDeviceId() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}
