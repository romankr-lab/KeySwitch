import Foundation

final class SettingsManager {

    static let shared = SettingsManager()

    private init() {
        load()
    }

    private enum Keys {
        static let autoPasteEnabled = "autoPasteEnabled"
        static let historyLimit = "historyLimit"
    }

    /// Whether to try automatically performing ⌘+V after click (experimental)
    var autoPasteEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(autoPasteEnabled, forKey: Keys.autoPasteEnabled)
        }
    }

    /// How many history items to show in menu (recent)
    var historyLimit: Int = 10 {
        didSet {
            UserDefaults.standard.set(historyLimit, forKey: Keys.historyLimit)
        }
    }

    private func load() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: Keys.autoPasteEnabled) != nil {
            autoPasteEnabled = defaults.bool(forKey: Keys.autoPasteEnabled)
        }

        if defaults.object(forKey: Keys.historyLimit) != nil {
            let saved = defaults.integer(forKey: Keys.historyLimit)
            if saved > 0 {
                historyLimit = saved
            }
        }
    }
}
