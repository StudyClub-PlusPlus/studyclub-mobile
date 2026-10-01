#if DEBUG
import Foundation
import Observation

@Observable
@MainActor
final class DevelopmentSettingsViewModel {
    private let modeStore: any RepositoryModeStoring
    private let flagStore: any FeatureFlagStoring
    private let flags: [FeatureFlagDefinition]
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
                    .init(id: .featureFlag(flag.id), title: flag.name, kind: .toggle(isOn: flagStore.isEnabled(flag)))
                }
            )
        }
        sections = [miscellaneous] + flagSections
    }

    convenience init() {
        self.init(
            modeStore: RepositoryFactory.makeRepositoryModeStore(),
            flagStore: RepositoryFactory.makeFeatureFlagStore(),
            flags: FeatureFlag.allCases.map(\.definition)
        )
    }

    init(modeStore: any RepositoryModeStoring, flagStore: any FeatureFlagStoring, flags: [FeatureFlagDefinition]) {
        self.modeStore = modeStore
        self.flagStore = flagStore
        self.flags = flags
        repositoryMode = modeStore.mode
        updateSections()
    }

    func setFlag(id: String, isEnabled: Bool) {
        guard let flag = flags.first(where: { $0.id == id }) else { return }
        flagStore.setEnabled(isEnabled, for: flag)
        updateSections()
    }

    func resetFlagsToDefaults() {
        flagStore.resetToDefaults()
        updateSections()
    }

    @discardableResult
    func changeRepositoryMode(to mode: RepositoryMode) -> Bool {
        guard mode != repositoryMode else { return false }
        modeStore.setMode(mode)
        repositoryMode = mode
        updateSections()
        return true
    }
}
#endif
