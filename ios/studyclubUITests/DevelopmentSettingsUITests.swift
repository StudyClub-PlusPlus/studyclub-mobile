import XCTest

final class DevelopmentSettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    #if DEBUG
    @MainActor
    func testLargeTextAndLandscapeKeepFlagControlsUsable() {
        let app = XCUIApplication()
        app.launchEnvironment["STUDYCLUB_UI_TEST_SUITE"] = "studyclub.ui-tests.\(UUID().uuidString)"
        app.launchEnvironment["STUDYCLUB_UI_TEST_FLAGS"] = "1"
        app.launchArguments = ["--mock-scenario", "content", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["tab.main"].press(forDuration: 1)
        let list = app.collectionViews["development.list"]
        let row = app.switches["development.flag.fixture.ready"]
        let ready = app.switches["development.flag.fixture.ready"]
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        for _ in 0..<4 where !ready.isHittable { list.swipeUp() }
        XCTAssertTrue(ready.isHittable)
        XCTAssertEqual(ready.label, "검증용 Ready Flag")
        XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        row.tap()
        XCTAssertEqual(ready.value as? String, "0")
        capture(app, name: "flags-fixture-accessibility-text")
        app.buttons["development.close"].tap()

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let landscapeLayout = NSPredicate { _, _ in app.frame.width > app.frame.height }
        expectation(for: landscapeLayout, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        let main = app.tabBars.buttons["tab.main"]
        XCTAssertTrue(main.waitForExistence(timeout: 3))
        main.press(forDuration: 1)
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        for _ in 0..<4 where !ready.isHittable { list.swipeUp() }
        XCTAssertTrue(ready.isHittable)
        ready.tap()
        XCTAssertEqual(ready.value as? String, "1")
        capture(app, name: "flags-fixture-landscape-accessibility-text")
    }

    @MainActor
    func testFlagTogglesPersistThroughRootRebuildAndResetOnlyFlags() {
        let app = XCUIApplication()
        app.launchEnvironment["STUDYCLUB_UI_TEST_SUITE"] = "studyclub.ui-tests.\(UUID().uuidString)"
        app.launchEnvironment["STUDYCLUB_UI_TEST_FLAGS"] = "1"
        app.launch()
        app.tabBars.buttons["tab.main"].press(forDuration: 1)
        let ready = app.switches["development.flag.fixture.ready"]
        let inProgress = app.switches["development.flag.fixture.in-progress"]
        XCTAssertTrue(ready.waitForExistence(timeout: 3))
        XCTAssertEqual(ready.value as? String, "1")
        XCTAssertEqual(inProgress.value as? String, "0")
        capture(app, name: "flags-fixture-defaults")
        ready.tap()
        inProgress.tap()
        XCTAssertEqual(ready.value as? String, "0")
        XCTAssertEqual(inProgress.value as? String, "1")
        // Exercise the native trailing switch as well as tapping the label/row center.
        let switchCenter = ready.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
        switchCenter.tap()
        XCTAssertEqual(ready.value as? String, "1")
        switchCenter.tap()
        XCTAssertEqual(ready.value as? String, "0")
        capture(app, name: "flags-fixture-overrides")

        app.terminate()
        app.launch()
        app.tabBars.buttons["tab.main"].press(forDuration: 1)
        XCTAssertTrue(ready.waitForExistence(timeout: 3))
        XCTAssertEqual(ready.value as? String, "0")
        XCTAssertEqual(inProgress.value as? String, "1")
        chooseRepository("Real", in: app)
        XCTAssertTrue(app.otherElements["main.state.failure"].waitForExistence(timeout: 15))
        app.tabBars.buttons["tab.main"].press(forDuration: 1)
        XCTAssertTrue(ready.waitForExistence(timeout: 3))
        XCTAssertEqual(ready.value as? String, "0")
        XCTAssertEqual(inProgress.value as? String, "1")
        app.buttons["development.resetFlags.row"].tap()
        XCTAssertEqual(ready.value as? String, "1")
        XCTAssertEqual(inProgress.value as? String, "0")
        XCTAssertEqual(app.buttons["development.repository.row"].value as? String, "Real")
        capture(app, name: "flags-fixture-reset-preserves-real")

        app.terminate()
        app.launch()
        app.tabBars.buttons["tab.main"].press(forDuration: 1)
        XCTAssertTrue(ready.waitForExistence(timeout: 3))
        XCTAssertEqual(ready.value as? String, "1")
        XCTAssertEqual(inProgress.value as? String, "0")
        XCTAssertEqual(app.buttons["development.repository.row"].value as? String, "Real")
        chooseRepository("Mock", in: app)
    }

    @MainActor
    func testNormalLaunchShowsEmptyFlagSectionsAndResetButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-scenario", "content"]
        app.launch()
        app.tabBars.buttons["tab.main"].press(forDuration: 1)
        XCTAssertTrue(app.buttons["development.resetFlags.row"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Ready"].exists)
        XCTAssertTrue(app.staticTexts["InProgress"].exists)
        XCTAssertEqual(app.switches.count, 0)
        app.buttons["development.resetFlags.row"].tap()
        capture(app, name: "development-empty-flag-catalog")
    }

    @MainActor
    func testRepositoryChangeRebuildsAllTabsAndPersistsAcrossLaunches() {
        let app = XCUIApplication()
        app.launchEnvironment["STUDYCLUB_UI_TEST_SUITE"] = "studyclub.ui-tests.\(UUID().uuidString)"
        app.launch()
        let study = app.descendants(matching: .any)["main.study.algorithm"]
        XCTAssertTrue(study.waitForExistence(timeout: 3))
        study.tap()
        XCTAssertTrue(app.staticTexts["detail.title"].waitForExistence(timeout: 3))
        app.tabBars.buttons["tab.setting"].tap()
        app.tabBars.buttons["tab.main"].press(forDuration: 1)
        chooseRepository("Real", in: app)

        XCTAssertTrue(app.otherElements["main.state.failure"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.tabBars.buttons["tab.main"].isSelected)
        XCTAssertFalse(app.staticTexts["detail.title"].exists)
        XCTAssertFalse(app.navigationBars["Development Settings"].exists)
        capture(app, name: "real-main-failure-after-root-rebuild")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.otherElements["main.state.failure"].waitForExistence(timeout: 15))
        app.tabBars.buttons["tab.main"].press(forDuration: 1)
        let row = app.buttons["development.repository.row"]
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        XCTAssertEqual(row.value as? String, "Real")
        capture(app, name: "repository-persisted-real")

        chooseRepository("Real", in: app)
        XCTAssertTrue(app.navigationBars["Development Settings"].exists)
        chooseRepository("Mock", in: app)
        XCTAssertTrue(study.waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["tab.main"].isSelected)
        study.tap()
        XCTAssertTrue(app.staticTexts["detail.title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["detail.title"].label, "알고리즘 문제 풀이")

        app.terminate()
        app.launch()
        XCTAssertTrue(study.waitForExistence(timeout: 3))
    }

    @MainActor
    private func chooseRepository(_ mode: String, in app: XCUIApplication) {
        let row = app.buttons["development.repository.row"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        app.alerts["Repository"].buttons[mode].tap()
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    #endif

    @MainActor
    func testOnlyMainTabLongPressOpensDevelopmentSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-scenario", "content"]
        app.launch()
        let mainTab = app.tabBars.buttons["tab.main"]
        let settingTab = app.tabBars.buttons["tab.setting"]
        XCTAssertTrue(mainTab.waitForExistence(timeout: 3))
        settingTab.tap()
        mainTab.tap()
        XCTAssertFalse(app.navigationBars["Development Settings"].exists)
        settingTab.press(forDuration: 1)
        XCTAssertFalse(app.navigationBars["Development Settings"].exists)
        mainTab.press(forDuration: 1)
        #if DEBUG
        XCTAssertTrue(app.navigationBars["Development Settings"].waitForExistence(timeout: 2))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "development-entry"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["development.close"].tap()
        XCTAssertTrue(mainTab.waitForExistence(timeout: 2))
        mainTab.press(forDuration: 1)
        XCTAssertTrue(app.navigationBars["Development Settings"].waitForExistence(timeout: 2))
        #else
        XCTAssertFalse(app.navigationBars["Development Settings"].exists)
        #endif
    }
}
