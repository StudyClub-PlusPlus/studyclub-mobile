#if DEBUG
import Observation

@Observable
@MainActor
final class DevelopmentSettingsViewModel {
    private let store = DevelopmentSettingsStore()
    private let flags = FeatureFlag.definitions
    private(set) var repositoryMode: RepositoryMode
    private(set) var sections: [DevelopmentSettingSection] = []

    private func updateSections() {
        let miscellaneous = DevelopmentSettingSection(id: .miscellaneous, rows: [
            .init(id: .repository, title: "Repository", kind: .button(value: repositoryMode.title)),
            .init(id: .resetFlags, title: "Reset Flag to Default", kind: .button(value: nil))
        ])
        let flagSections = FeatureFlagStage.allCases.map { stage in
            DevelopmentSettingSection(
                id: stage == .ready ? .ready : .inProgress,
                rows: flags.filter { $0.stage == stage }.map { flag in
                    .init(id: .featureFlag(flag.id), title: flag.name, kind: .toggle(isOn: store.isEnabled(flag)))
                }
            )
        }
        sections = [miscellaneous] + flagSections
    }

    init() {
        repositoryMode = store.repositoryMode
        updateSections()
    }

    func setFlag(id: String, isEnabled: Bool) {
        guard let flag = flags.first(where: { $0.id == id }) else { return }
        store.setEnabled(isEnabled, for: flag)
        updateSections()
    }

    func resetFlagsToDefaults() {
        store.resetToDefaults()
        updateSections()
    }

    func changeRepositoryMode(to mode: RepositoryMode) -> Bool {
        guard mode != repositoryMode else { return false }
        store.repositoryMode = mode
        repositoryMode = mode
        updateSections()
        return true
    }
}
#endif
