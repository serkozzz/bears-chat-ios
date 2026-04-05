import Foundation

struct LastAuthSession: Codable {
    let phoneNumber: String
    let deviceId: String
    let updatedAt: Date
}

final class LastAuthSessionStorage {
    static let shared = LastAuthSessionStorage()

    private let key = "last_auth_session"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ session: LastAuthSession) {
        guard let data = try? encoder.encode(session) else { return }
        defaults.set(data, forKey: key)
    }

    func load() -> LastAuthSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(LastAuthSession.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
