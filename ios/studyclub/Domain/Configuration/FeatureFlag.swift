enum FeatureFlagStage: String, CaseIterable, Sendable {
    case ready
    case inProgress

    var defaultValue: Bool { self == .ready }
}

struct FeatureFlagDefinition: Hashable, Sendable {
    let id: String
    let name: String
    let stage: FeatureFlagStage

    var defaultValue: Bool { stage.defaultValue }
}

/// Register actual features here once specified. Test fixtures are not app feature flags.
enum FeatureFlag: CaseIterable {
    static let allCases: [FeatureFlag] = []

    var definition: FeatureFlagDefinition {
        switch self {}
    }
}

protocol FeatureFlagStoring {
    func isEnabled(_ definition: FeatureFlagDefinition) -> Bool

    #if DEBUG
    func setEnabled(_ isEnabled: Bool, for definition: FeatureFlagDefinition)
    func resetToDefaults()
    #endif
}
