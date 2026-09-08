import Foundation

final class UserDefaultsFeatureFlagStore: FeatureFlagStoring {
    private let defaults: UserDefaults
    private static let key = "development.featureFlags"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

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
