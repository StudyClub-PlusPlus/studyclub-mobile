#if DEBUG
import Observation

@Observable
@MainActor
final class DevelopmentSettingsViewModel {
    private let store = DevelopmentSettingsStore()
    private let flags = FeatureFlag.definitions
    private let onAuthFlagChange: () -> Void
    private(set) var repositoryMode: RepositoryMode
    private(set) var sections: [DevelopmentSettingSection] = []

    private func updateSections() {
        var rows: [DevelopmentSettingRow] = [
            .init(id: .repository, title: "Repository", kind: .button(value: repositoryMode.title))
        ]
        if repositoryMode == .mock {
            rows.append(.init(id: .mockSession, title: "Mock 로그인 테스트", kind: .button(value: store.mockSession.title)))
        }
        rows.append(.init(id: .resetFlags, title: "Reset Flag to Default", kind: .button(value: nil)))
        let miscellaneous = DevelopmentSettingSection(id: .miscellaneous, rows: rows)
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

    init(onAuthFlagChange: @escaping () -> Void = {}) {
        self.onAuthFlagChange = onAuthFlagChange
        repositoryMode = store.repositoryMode
        updateSections()
    }

    func setFlag(id: String, isEnabled: Bool) {
        guard let flag = flags.first(where: { $0.id == id }) else { return }
        store.setEnabled(isEnabled, for: flag, whenAuthFlagChanges: onAuthFlagChange)
        updateSections()
    }

    func resetFlagsToDefaults() {
        store.resetToDefaults(whenAuthFlagChanges: onAuthFlagChange)
        updateSections()
    }

    func changeRepositoryMode(to mode: RepositoryMode) -> Bool {
        guard mode != repositoryMode else { return false }
        store.repositoryMode = mode
        repositoryMode = mode
        updateSections()
        return true
    }

    func selectMockSession(_ session: DevelopmentSettingsStore.MockSession) -> Bool {
        guard repositoryMode == .mock else { return false }
        store.mockSession = session
        updateSections()
        // Selecting the saved choice again deliberately restores that sample after a mock logout.
        return true
    }
}
#endif
