import Foundation

final class AppPreferences {
    static let shared = AppPreferences()

    private let defaults: UserDefaults
    private let chatBackgroundColorHexKey = "chatBackgroundColorHex"
    private let defaultBackgroundColorHex = "#FFFFFF"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var chatBackgroundColorHex: String {
        get { defaults.string(forKey: chatBackgroundColorHexKey) ?? defaultBackgroundColorHex }
        set { defaults.set(newValue, forKey: chatBackgroundColorHexKey) }
    }
}
