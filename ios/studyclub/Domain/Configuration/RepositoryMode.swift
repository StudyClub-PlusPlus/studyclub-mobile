enum RepositoryMode: String, CaseIterable, Sendable {
    case mock
    case real

    // Preserve the current app default until the production API is configured.
    static let defaultMode: RepositoryMode = .mock

    var title: String {
        switch self {
        case .mock: "Mock"
        case .real: "Real"
        }
    }
}

protocol RepositoryModeStoring {
    var mode: RepositoryMode { get }
    #if DEBUG
    func setMode(_ mode: RepositoryMode)
    #endif
}
