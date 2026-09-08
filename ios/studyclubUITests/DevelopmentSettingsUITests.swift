import XCTest

final class DevelopmentSettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    #if DEBUG
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
        app.cells["development.resetFlags.row"].tap()
        XCTAssertEqual(ready.value as? String, "1")
        XCTAssertEqual(inProgress.value as? String, "0")
        XCTAssertEqual(app.cells["development.repository.row"].value as? String, "Real")
        capture(app, name: "flags-fixture-reset-preserves-real")

        app.terminate()
        app.launch()
        app.tabBars.buttons["tab.main"].press(forDuration: 1)
        XCTAssertTrue(ready.waitForExistence(timeout: 3))
        XCTAssertEqual(ready.value as? String, "1")
        XCTAssertEqual(inProgress.value as? String, "0")
        XCTAssertEqual(app.cells["development.repository.row"].value as? String, "Real")
        chooseRepository("Mock", in: app)
    }

    @MainActor
    func testNormalLaunchShowsEmptyFlagSectionsAndResetButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-scenario", "content"]
        app.launch()
        app.tabBars.buttons["tab.main"].press(forDuration: 1)
        XCTAssertTrue(app.cells["development.resetFlags.row"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Ready"].exists)
        XCTAssertTrue(app.staticTexts["InProgress"].exists)
        XCTAssertEqual(app.switches.count, 0)
        app.cells["development.resetFlags.row"].tap()
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
        let row = app.cells["development.repository.row"]
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
        let row = app.cells["development.repository.row"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        app.alerts["Repository"].buttons[mode].tap()
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
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
