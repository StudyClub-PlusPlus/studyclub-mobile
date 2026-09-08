import XCTest
@testable import studyclub

final class RepositoryModeTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "studyclub.unit-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    func testMissingAndInvalidModesUseAppDefault() {
        let store = UserDefaultsRepositoryModeStore(defaults: defaults)
        XCTAssertEqual(store.mode, .defaultMode)
        defaults.set("retired-environment", forKey: "development.repositoryMode")
        XCTAssertEqual(store.mode, .defaultMode)
    }

    #if DEBUG
    func testModeIsReadFreshAndSurvivesStoreRecreation() {
        let store = UserDefaultsRepositoryModeStore(defaults: defaults)
        let otherStore = UserDefaultsRepositoryModeStore(defaults: UserDefaults(suiteName: suite)!)
        store.setMode(.real)
        XCTAssertEqual(otherStore.mode, .real)
        otherStore.setMode(.mock)
        XCTAssertEqual(store.mode, .mock)
    }

    @MainActor
    func testViewModelPersistsChangesAndDoesNotRebuildForSameMode() {
        let store = UserDefaultsRepositoryModeStore(defaults: defaults)
        let viewModel = DevelopmentSettingsViewModel(
            modeStore: store, flagStore: UserDefaultsFeatureFlagStore(defaults: defaults), flags: []
        )
        XCTAssertFalse(viewModel.changeRepositoryMode(to: .mock))
        XCTAssertEqual(viewModel.repositoryMode, .mock)
        XCTAssertTrue(viewModel.changeRepositoryMode(to: .real))
        XCTAssertEqual(viewModel.repositoryMode, .real)
        XCTAssertEqual(store.mode, .real)
    }
    #else
    func testReleaseIgnoresPersistedDeveloperMode() {
        defaults.set("real", forKey: "development.repositoryMode")
        XCTAssertEqual(UserDefaultsRepositoryModeStore(defaults: defaults).mode, .defaultMode)
    }

    func testReleaseAppFactoryIgnoresDebugScenarioArguments() async throws {
        let repository = RepositoryFactory.makeStudyRepository(arguments: ["--mock-scenario", "failure"])
        let studies = try await repository.fetchStudies()
        XCTAssertFalse(studies.isEmpty)
    }
    #endif

    func testRealFactoryUsesLiveClientWithUnconfiguredDetail() async {
        let repository = RepositoryFactory.makeStudyRepository(mode: .real)
        do {
            _ = try await repository.fetchStudy(id: "algorithm")
            XCTFail("Real must not silently fall back to Mock")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .detailAPIUnconfigured)
        }
    }

    func testExplicitMockScenarioRemainsDeterministic() async throws {
        let repository = RepositoryFactory.makeStudyRepository(mode: .mock, arguments: ["--mock-scenario", "empty"])
        let studies = try await repository.fetchStudies()
        XCTAssertTrue(studies.isEmpty)
    }
}
