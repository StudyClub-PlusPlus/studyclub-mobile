#if DEBUG
import Combine

@MainActor
final class DevelopmentSettingsViewModel {
    private let modeStore: any RepositoryModeStoring
    private let stateSubject = CurrentValueSubject<Void, Never>(())
    private(set) var repositoryMode: RepositoryMode

    var statePublisher: AnyPublisher<Void, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var sections: [DevelopmentSettingSection] {
        [.init(id: .miscellaneous, rows: [
            .init(id: .repository, title: "Repository", kind: .button(value: repositoryMode.title))
        ])]
    }

    convenience init() {
        self.init(modeStore: RepositoryFactory.makeRepositoryModeStore())
    }

    init(modeStore: any RepositoryModeStoring) {
        self.modeStore = modeStore
        repositoryMode = modeStore.mode
    }

    @discardableResult
    func changeRepositoryMode(to mode: RepositoryMode) -> Bool {
        guard mode != repositoryMode else { return false }
        modeStore.setMode(mode)
        repositoryMode = mode
        stateSubject.send(())
        return true
    }
}
#endif
