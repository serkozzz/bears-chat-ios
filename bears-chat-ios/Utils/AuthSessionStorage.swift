import Foundation
import Security

struct LastAuthSession: Codable {
    let phoneNumber: String
    let deviceId: String
    let verificationToken: String?
    let updatedAt: Date
}

final class AuthSessionStorage {
    static let shared = AuthSessionStorage()

    private let defaults: UserDefaults
    private let sessionKey = "last_auth_session"
    private let tokenService = "bearcore-chat-ios.auth"
    private let tokenAccount = "access-token"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveSession(_ session: LastAuthSession) {
        guard let data = try? encoder.encode(session) else { return }
        defaults.set(data, forKey: sessionKey)
    }
    
    func saveSession(phoneNumber: String, deviceId: String, verificationToken: String? = nil) {
        saveSession(
            LastAuthSession(
                phoneNumber: phoneNumber,
                deviceId: deviceId,
                verificationToken: verificationToken,
                updatedAt: Date()
            )
        )
    }

    func loadSession() -> LastAuthSession? {
        guard let data = defaults.data(forKey: sessionKey) else { return nil }
        return try? decoder.decode(LastAuthSession.self, from: data)
    }

    func clearSession() {
        defaults.removeObject(forKey: sessionKey)
    }

    func saveAccessToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func loadAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func clearAccessToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    func clearAll() {
        clearSession()
        clearAccessToken()
    }
}
