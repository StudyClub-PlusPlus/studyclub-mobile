#if DEBUG
import Foundation

struct DevelopmentSettingRow {
    enum ID: Hashable {
        case repository
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
