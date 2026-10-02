import Foundation

struct DevelopmentSettingsStore {
    private let defaults: UserDefaults
    private static let key = "development.featureFlags"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    #if DEBUG
    private static let repositoryModeKey = "development.repositoryMode"

    var repositoryMode: RepositoryMode {
        get {
            guard let value = defaults.string(forKey: Self.repositoryModeKey),
                  let mode = RepositoryMode(rawValue: value) else { return .mock }
            return mode
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.repositoryModeKey)
        }
    }
    #endif

    func isEnabled(_ definition: FeatureFlagDefinition) -> Bool {
        #if DEBUG
        if let override = defaults.dictionary(forKey: Self.key)?[definition.id] as? Bool {
            return override
        }
        #endif
        return definition.defaultValue
    }

    #if DEBUG
    func setEnabled(_ isEnabled: Bool, for definition: FeatureFlagDefinition) {
        var overrides = defaults.dictionary(forKey: Self.key) ?? [:]
        overrides[definition.id] = isEnabled
        defaults.set(overrides, forKey: Self.key)
    }

    func resetToDefaults() {
        // Remove overrides instead of persisting today's defaults, including retired flag IDs.
        // Repository and other preferences have their own keys and remain untouched.
        defaults.removeObject(forKey: Self.key)
    }
    #endif
}
