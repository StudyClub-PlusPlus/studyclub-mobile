import Foundation

final class UserDefaultsRepositoryModeStore: RepositoryModeStoring {
    private let defaults: UserDefaults
    private static let key = "development.repositoryMode"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var mode: RepositoryMode {
        #if DEBUG
        guard let rawValue = defaults.string(forKey: Self.key),
              let mode = RepositoryMode(rawValue: rawValue) else { return .defaultMode }
        return mode
        #else
        return .defaultMode
        #endif
    }

    #if DEBUG
    func setMode(_ mode: RepositoryMode) {
        defaults.set(mode.rawValue, forKey: Self.key)
    }
    #endif
}
