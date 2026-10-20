import Foundation

public final class PreferencesManager {
    public static let shared = PreferencesManager()

    private let defaults: UserDefaults
    private let clickConfigKey = "com.autoclix.clickConfiguration"
    private let hotKeyConfigKey = "com.autoclix.hotKeyConfiguration"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadClickConfiguration() -> ClickConfiguration {
        guard let data = defaults.data(forKey: clickConfigKey),
              let config = try? JSONDecoder().decode(ClickConfiguration.self, from: data) else {
            return ClickConfiguration()
        }
        return config
    }

    public func saveClickConfiguration(_ config: ClickConfiguration) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: clickConfigKey)
        }
    }

    public func loadHotKeyConfiguration() -> HotKeyConfiguration {
        guard let data = defaults.data(forKey: hotKeyConfigKey),
              let config = try? JSONDecoder().decode(HotKeyConfiguration.self, from: data) else {
            return HotKeyConfiguration.defaultShortcut
        }
        return config
    }

    public func saveHotKeyConfiguration(_ config: HotKeyConfiguration) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: hotKeyConfigKey)
        }
    }
}
