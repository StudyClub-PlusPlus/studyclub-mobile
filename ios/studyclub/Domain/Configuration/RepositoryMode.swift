#if DEBUG
enum RepositoryMode: String, CaseIterable, Sendable {
    case mock
    case real

    var title: String {
        switch self {
        case .mock: "Mock"
        case .real: "Real"
        }
    }
}
#endif
