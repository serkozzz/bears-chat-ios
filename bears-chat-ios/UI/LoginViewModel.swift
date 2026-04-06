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
    private let authSessionStorage: AuthSessionStorage
    
    @Published var state = State.enteringPhone
    @Published var isLoading = false
    @Published var error: UIError?
    @Published var phoneNumber = ""
    @Published var verificationURLToOpen: URL?
    
    init(serverAPI: ServerAPI,
         authSessionStorage: AuthSessionStorage = .shared,
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
        authSessionStorage.saveSession(phoneNumber: cleanPhone, deviceId: deviceID)
        isLoading = true

        serverAPI.requestLinkForTelegramVerification(phoneNumber: cleanPhone, deviceId: deviceID) { result in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                isLoading = false
                switch result {
                case .success(let payload):
                    guard let verificationUrl = payload.verificationUrl,
                          let url = URL(string: verificationUrl),
                          let verificationToken = extractVerificationToken(from: url) else {
                        self.error = .init(message: "Ссылка верификации не получена")
                        return
                    }
                    authSessionStorage.saveSession(
                        phoneNumber: cleanPhone,
                        deviceId: deviceID,
                        verificationToken: verificationToken)
                    
                    state = .waitingTelegramConfirmation
                    phoneNumber = cleanPhone
                    self.verificationURLToOpen = url
                case .failure(let error):
                    self.error = .init(message: error.localizedDescription)
                }
            }
        }
    }

    func tryToLogin() {
        guard let session = authSessionStorage.loadSession() else { return }
        print("[LoginViewModel] tryToLogin phone=\(session.phoneNumber), hasVerificationToken=\(session.verificationToken != nil), hasAccessToken=\(serverAPI.hasAccessToken)")
        isLoading = true

        serverAPI.getAuthStatus(phoneNumber: session.phoneNumber, deviceId: session.deviceId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .success(let payload):
                    print("[LoginViewModel] authStatus isVerified=\(payload.isVerified)")
                    if payload.isVerified {
                        if self.serverAPI.hasAccessToken {
                            print("[LoginViewModel] proceed with existing access token")
                            self.onSuccess?(session.phoneNumber)
                            return
                        }
                        print("[LoginViewModel] no access token, trying exchange")
                        self.tryExchangeAccessTokenAndCompleteLogin(
                            verificationToken: session.verificationToken,
                            phoneNumber: session.phoneNumber
                        )
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
        guard let session = authSessionStorage.loadSession() else { return }
        phoneNumber = session.phoneNumber
    }

    private func resolveDeviceId() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    private func extractVerificationToken(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == "start" })?.value
    }

    private func tryExchangeAccessTokenAndCompleteLogin(verificationToken: String?, phoneNumber: String) {
        guard let verificationToken else {
            self.state = .enteringPhone
            self.phoneNumber = phoneNumber
            self.error = .init(message: "Токен подтверждения не найден. Нажмите 'Подтвердить' для новой верификации.")
            return
        }

        print("[LoginViewModel] exchanging access token")
        isLoading = true
        serverAPI.exchangeAccessToken(verificationToken: verificationToken) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .success:
                    print("[LoginViewModel] exchange success")
                    self.onSuccess?(phoneNumber)
                case .failure(let error):
                    print("[LoginViewModel] exchange failed: \(error.localizedDescription)")
                    let message = error.localizedDescription
                    if message.localizedCaseInsensitiveContains("already exchanged") {
                        self.state = .enteringPhone
                        self.phoneNumber = phoneNumber
                        self.error = .init(message: "Токен подтверждения уже использован. Нажмите 'Подтвердить' и пройдите верификацию заново.")
                        return
                    }
                    self.error = .init(message: error.localizedDescription)
                }
            }
        }
    }
}
