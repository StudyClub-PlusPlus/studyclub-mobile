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
    case studyListAPI
    case studyDesignSystem
    case googleLogin
    case myPage

    static let definitions = allCases.map(\.definition)

    var definition: FeatureFlagDefinition {
        switch self {
        case .studyListAPI:
            FeatureFlagDefinition(
                id: "study.list-api",
                name: "스터디 목록 API 연동",
                stage: .inProgress
            )
        case .studyDetailAPI:
            FeatureFlagDefinition(
                id: "study.detail-api",
                name: "스터디 상세 API 연동",
                stage: .ready
            )
        case .studyDesignSystem:
            FeatureFlagDefinition(
                id: "study.design-system",
                name: "디자인 시스템 적용 · 앱 재실행",
                stage: .inProgress
            )
        case .myPage:
            FeatureFlagDefinition(id: "account.mypage", name: "MyPage · 앱 재실행", stage: .inProgress)
        case .googleLogin:
            FeatureFlagDefinition(
                id: "auth.google-login",
                name: "Google 로그인",
                stage: .inProgress
            )
        }
    }
}
