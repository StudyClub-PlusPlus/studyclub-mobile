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

/// Stable app feature catalog. Test fixtures are not app feature flags.
enum FeatureFlag: CaseIterable {
    case studyList

    var definition: FeatureFlagDefinition {
        switch self {
        case .studyList:
            .init(id: "study-list", name: "스터디 목록", stage: .inProgress)
        }
    }
}

protocol FeatureFlagStoring {
    func isEnabled(_ definition: FeatureFlagDefinition) -> Bool

    #if DEBUG
    func setEnabled(_ isEnabled: Bool, for definition: FeatureFlagDefinition)
    func resetToDefaults()
    #endif
}
