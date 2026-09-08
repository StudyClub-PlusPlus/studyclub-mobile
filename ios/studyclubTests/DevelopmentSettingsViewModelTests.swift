#if DEBUG
import XCTest
@testable import studyclub

@MainActor
final class DevelopmentSettingsViewModelTests: XCTestCase {
    func testSectionsToggleAndResetExposeUpdatedValuesAndPreserveRepository() {
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
        func values() -> [Bool] {
            XCTAssertEqual(viewModel.sections.map(\.id), [.miscellaneous, .ready, .inProgress])
            XCTAssertEqual(viewModel.repositoryMode, .real)
            return viewModel.sections.flatMap(\.rows).compactMap { row in
                if case .toggle(let value) = row.kind { return value }
                return nil
            }
        }
        XCTAssertEqual(values(), [true, false])
        viewModel.setFlag(id: "ready", isEnabled: false)
        XCTAssertEqual(values(), [false, false])
        viewModel.setFlag(id: "progress", isEnabled: true)
        XCTAssertEqual(values(), [false, true])
        viewModel.setFlag(id: "unknown", isEnabled: true)
        XCTAssertEqual(values(), [false, true])
        viewModel.resetFlagsToDefaults()
        XCTAssertEqual(values(), [true, false])
        XCTAssertEqual(modeStore.mode, .real)
        XCTAssertNil(defaults.object(forKey: "development.featureFlags"))
    }
}
#endif
