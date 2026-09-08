import XCTest
@testable import studyclub

final class FeatureFlagStoreTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private let ready = FeatureFlagDefinition(id: "test.ready", name: "Ready test flag", stage: .ready)
    private let inProgress = FeatureFlagDefinition(id: "test.in-progress", name: "InProgress test flag", stage: .inProgress)

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

    func testStageDefaultsAndMissingOverrides() {
        let store = UserDefaultsFeatureFlagStore(defaults: defaults)
        XCTAssertTrue(store.isEnabled(ready))
        XCTAssertFalse(store.isEnabled(inProgress))
    }

    func testMalformedOverrideUsesDefaultWithoutPoisoningOtherFlags() {
        defaults.set([ready.id: "bad-value", inProgress.id: true], forKey: "development.featureFlags")
        let store = UserDefaultsFeatureFlagStore(defaults: defaults)
        XCTAssertTrue(store.isEnabled(ready))
        #if DEBUG
        XCTAssertTrue(store.isEnabled(inProgress))
        #else
        XCTAssertFalse(store.isEnabled(inProgress))
        #endif
    }

    #if DEBUG
    func testOverridesAreIndependentAndPersistAcrossStoreRecreation() {
        let store = UserDefaultsFeatureFlagStore(defaults: defaults)
        store.setEnabled(false, for: ready)
        store.setEnabled(true, for: inProgress)
        let relaunched = UserDefaultsFeatureFlagStore(defaults: UserDefaults(suiteName: suite)!)
        XCTAssertFalse(relaunched.isEnabled(ready))
        XCTAssertTrue(relaunched.isEnabled(inProgress))
        store.setEnabled(false, for: inProgress)
        XCTAssertFalse(relaunched.isEnabled(inProgress))
        XCTAssertFalse(relaunched.isEnabled(ready))
    }

    func testStagePromotionAndRenameKeepOverrideUntilReset() {
        let store = UserDefaultsFeatureFlagStore(defaults: defaults)
        let promoted = FeatureFlagDefinition(id: inProgress.id, name: "Renamed", stage: .ready)
        store.setEnabled(false, for: inProgress)
        XCTAssertFalse(store.isEnabled(promoted))
        store.resetToDefaults()
        XCTAssertTrue(store.isEnabled(promoted))
    }

    func testResetRemovesAllOverridesButPreservesRepositoryAndUnrelatedSettings() {
        let store = UserDefaultsFeatureFlagStore(defaults: defaults)
        let modeStore = UserDefaultsRepositoryModeStore(defaults: defaults)
        modeStore.setMode(.real)
        defaults.set("keep", forKey: "unrelated")
        defaults.set(["retired.flag": true], forKey: "development.featureFlags")
        store.setEnabled(false, for: ready)
        store.setEnabled(true, for: inProgress)

        store.resetToDefaults()
        store.resetToDefaults()
        XCTAssertNil(defaults.object(forKey: "development.featureFlags"))
        XCTAssertTrue(store.isEnabled(ready))
        XCTAssertFalse(store.isEnabled(inProgress))
        XCTAssertEqual(modeStore.mode, .real)
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "keep")
    }
    #else
    func testReleaseIgnoresEveryPersistedFlagOverride() {
        defaults.set([ready.id: false, inProgress.id: true], forKey: "development.featureFlags")
        let store = UserDefaultsFeatureFlagStore(defaults: defaults)
        XCTAssertTrue(store.isEnabled(ready))
        XCTAssertFalse(store.isEnabled(inProgress))
    }
    #endif
}
