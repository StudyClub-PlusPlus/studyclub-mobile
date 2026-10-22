import Foundation

struct DevelopmentSettingsStore {
    private let defaults = UserDefaults.standard
    private static let key = "development.featureFlags"

    #if DEBUG
    private static let repositoryModeKey = "development.repositoryMode"
    private static let mockSessionKey = "development.mockSession"

    enum MockSession: String, CaseIterable {
        case guest, member
    }

    var mockSession: MockSession {
        get {
            guard let value = defaults.string(forKey: Self.mockSessionKey),
                  let session = MockSession(rawValue: value) else { return .guest }
            return session
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.mockSessionKey)
        }
    }

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
        if let override = defaults.dictionary(forKey: Self.key)?[definition.id] as? Bool {
            return override
        }
        return definition.defaultValue
    }

    #if DEBUG
    func setEnabled(
        _ enabled: Bool,
        for definition: FeatureFlagDefinition,
        whenAuthFlagChanges notify: () -> Void = {}
    ) {
        let authBefore = isEnabled(FeatureFlag.googleLogin.definition)
        var overrides = defaults.dictionary(forKey: Self.key) ?? [:]
        overrides[definition.id] = enabled
        defaults.set(overrides, forKey: Self.key)
        // Only the account flag reaches its owner. Other flags keep their existing capture policy.
        if definition.id == FeatureFlag.googleLogin.definition.id,
           authBefore != isEnabled(FeatureFlag.googleLogin.definition) {
            notify()
        }
    }

    func resetToDefaults(whenAuthFlagChanges notify: () -> Void = {}) {
        // Remove overrides instead of persisting today's defaults, including retired flag IDs.
        // Repository and other preferences have their own keys and remain untouched.
        let authBefore = isEnabled(FeatureFlag.googleLogin.definition)
        defaults.removeObject(forKey: Self.key)
        if authBefore != isEnabled(FeatureFlag.googleLogin.definition) {
            notify()
        }
    }
    #endif
}
