#if DEBUG
import Combine
import XCTest
@testable import studyclub

@MainActor
final class DevelopmentSettingsViewModelTests: XCTestCase {
    func testSectionsToggleAndResetPublishUpdatedValuesAndPreserveRepository() {
        let suite = "studyclub.unit-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let flags = [
            FeatureFlagDefinition(id: "ready", name: "Ready fixture", stage: .ready),
            FeatureFlagDefinition(id: "progress", name: "Progress fixture", stage: .inProgress)
        ]
        let modeStore = UserDefaultsRepositoryModeStore(defaults: defaults)
        modeStore.setMode(.real)
        let flagStore = UserDefaultsFeatureFlagStore(defaults: defaults)
        let viewModel = DevelopmentSettingsViewModel(modeStore: modeStore, flagStore: flagStore, flags: flags)
        var observedValues: [[Bool]] = []
        let subscription = viewModel.statePublisher.sink {
            XCTAssertEqual(viewModel.sections.map(\.id), [.miscellaneous, .ready, .inProgress])
            XCTAssertEqual(viewModel.repositoryMode, .real)
            observedValues.append(viewModel.sections.flatMap(\.rows).compactMap { row in
                if case .toggle(let value) = row.kind { return value }
                return nil
            })
        }
        viewModel.setFlag(id: "ready", isEnabled: false)
        viewModel.setFlag(id: "progress", isEnabled: true)
        viewModel.setFlag(id: "unknown", isEnabled: true)
        viewModel.resetFlagsToDefaults()
        XCTAssertEqual(observedValues, [[true, false], [false, false], [false, true], [true, false]])
        XCTAssertEqual(modeStore.mode, .real)
        XCTAssertNil(defaults.object(forKey: "development.featureFlags"))
        withExtendedLifetime(subscription) {}
    }
}
#endif
