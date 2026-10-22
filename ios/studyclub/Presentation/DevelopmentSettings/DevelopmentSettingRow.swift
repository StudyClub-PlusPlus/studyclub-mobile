#if DEBUG
struct DevelopmentSettingRow {
    enum ID: Hashable {
        case repository
        case mockSession
        case resetFlags
        case featureFlag(String)
    }

    enum Kind {
        case button(value: String?)
        case toggle(isOn: Bool)
    }

    let id: ID
    let title: String
    let kind: Kind
}

extension DevelopmentSettingsStore.MockSession {
    var title: String {
        switch self {
        case .guest: "비회원 · 비로그인"
        case .member: "회원 · 로그인"
        }
    }
}

struct DevelopmentSettingSection {
    enum ID: Hashable {
        case miscellaneous
        case ready
        case inProgress

        var title: String {
            switch self {
            case .miscellaneous: "기타"
            case .ready: "Ready"
            case .inProgress: "InProgress"
            }
        }
    }

    let id: ID
    let rows: [DevelopmentSettingRow]
}
#endif
