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
    case studyDetailAPI

    var definition: FeatureFlagDefinition {
        switch self {
        case .studyDetailAPI:
            FeatureFlagDefinition(
                id: "study.detail-api",
                name: "스터디 상세 API 연동",
                stage: .inProgress
            )
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
