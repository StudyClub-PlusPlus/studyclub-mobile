import XCTest

final class DevelopmentSettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    #if DEBUG
    @MainActor
    func testLandscapeKeepsFlagControlsUsable() {
        let app = XCUIApplication()
        app.launchEnvironment["STUDYCLUB_UI_TEST_SUITE"] = "studyclub.ui-tests.\(UUID().uuidString)"
        app.launchEnvironment["STUDYCLUB_UI_TEST_FLAGS"] = "1"
        app.launchArguments = ["--mock-scenario", "content"]
        app.launch()
        app.tabBars.buttons["스터디"].press(forDuration: 1)
        let list = app.collectionViews.firstMatch
        let ready = app.switches["검증용 Ready Flag"]
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        for _ in 0..<4 where !ready.isHittable { list.swipeUp() }
        XCTAssertTrue(ready.isHittable)
        ready.tap()
        XCTAssertEqual(ready.value as? String, "0")
        capture(app, name: "flags-fixture-portrait")
        app.buttons["닫기"].tap()

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let landscapeLayout = NSPredicate { _, _ in app.frame.width > app.frame.height }
        expectation(for: landscapeLayout, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        let main = app.tabBars.buttons["스터디"]
        XCTAssertTrue(main.waitForExistence(timeout: 3))
        main.press(forDuration: 1)
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        for _ in 0..<4 where !ready.isHittable { list.swipeUp() }
        XCTAssertTrue(ready.isHittable)
        ready.tap()
        XCTAssertEqual(ready.value as? String, "1")
        capture(app, name: "flags-fixture-landscape")
    }

    @MainActor
    func testFlagTogglesPersistThroughRootRebuildAndResetOnlyFlags() {
        let app = XCUIApplication()
        app.launchEnvironment["STUDYCLUB_UI_TEST_SUITE"] = "studyclub.ui-tests.\(UUID().uuidString)"
        app.launchEnvironment["STUDYCLUB_UI_TEST_FLAGS"] = "1"
        app.launch()
        app.tabBars.buttons["스터디"].press(forDuration: 1)
        let ready = app.switches["검증용 Ready Flag"]
        let inProgress = app.switches["검증용 InProgress Flag"]
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
        app.tabBars.buttons["스터디"].press(forDuration: 1)
        XCTAssertTrue(ready.waitForExistence(timeout: 3))
        XCTAssertEqual(ready.value as? String, "0")
        XCTAssertEqual(inProgress.value as? String, "1")
        chooseRepository("Real", in: app)
        XCTAssertTrue(app.staticTexts["목록을 불러오지 못했어요"].waitForExistence(timeout: 15))
        app.tabBars.buttons["스터디"].press(forDuration: 1)
        XCTAssertTrue(ready.waitForExistence(timeout: 3))
        XCTAssertEqual(ready.value as? String, "0")
        XCTAssertEqual(inProgress.value as? String, "1")
        app.buttons["Reset Flag to Default"].tap()
        XCTAssertEqual(ready.value as? String, "1")
        XCTAssertEqual(inProgress.value as? String, "0")
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Repository").firstMatch.staticTexts["Real"].exists)
        capture(app, name: "flags-fixture-reset-preserves-real")

        app.terminate()
        app.launch()
        app.tabBars.buttons["스터디"].press(forDuration: 1)
        XCTAssertTrue(ready.waitForExistence(timeout: 3))
        XCTAssertEqual(ready.value as? String, "1")
        XCTAssertEqual(inProgress.value as? String, "0")
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Repository").firstMatch.staticTexts["Real"].exists)
        chooseRepository("Mock", in: app)
    }

    @MainActor
    func testNormalLaunchShowsEmptyFlagSectionsAndResetButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-scenario", "content"]
        app.launch()
        app.tabBars.buttons["스터디"].press(forDuration: 1)
        XCTAssertTrue(app.buttons["Reset Flag to Default"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Ready"].exists)
        XCTAssertTrue(app.staticTexts["InProgress"].exists)
        XCTAssertEqual(app.switches.count, 0)
        app.buttons["Reset Flag to Default"].tap()
        capture(app, name: "development-empty-flag-catalog")
    }

    @MainActor
    func testRepositoryChangeRebuildsAllTabsAndPersistsAcrossLaunches() {
        let app = XCUIApplication()
        app.launchEnvironment["STUDYCLUB_UI_TEST_SUITE"] = "studyclub.ui-tests.\(UUID().uuidString)"
        app.launch()
        let study = app.collectionViews.cells.containing(.staticText, identifier: "알고리즘 문제 풀이").firstMatch
        XCTAssertTrue(study.waitForExistence(timeout: 3))
        study.tap()
        XCTAssertTrue(app.scrollViews.staticTexts["알고리즘 문제 풀이"].waitForExistence(timeout: 3))
        app.tabBars.buttons["설정"].tap()
        app.tabBars.buttons["스터디"].press(forDuration: 1)
        chooseRepository("Real", in: app)

        XCTAssertTrue(app.staticTexts["목록을 불러오지 못했어요"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.tabBars.buttons["스터디"].isSelected)
        XCTAssertFalse(app.scrollViews.staticTexts["알고리즘 문제 풀이"].exists)
        XCTAssertFalse(app.navigationBars["Development Settings"].exists)
        capture(app, name: "real-main-failure-after-root-rebuild")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["목록을 불러오지 못했어요"].waitForExistence(timeout: 15))
        app.tabBars.buttons["스터디"].press(forDuration: 1)
        let row = app.buttons.containing(.staticText, identifier: "Repository").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        XCTAssertTrue(row.staticTexts["Real"].exists)
        capture(app, name: "repository-persisted-real")

        chooseRepository("Real", in: app)
        XCTAssertTrue(app.navigationBars["Development Settings"].exists)
        chooseRepository("Mock", in: app)
        XCTAssertTrue(study.waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["스터디"].isSelected)
        study.tap()
        XCTAssertTrue(app.scrollViews.staticTexts["알고리즘 문제 풀이"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.scrollViews.staticTexts["알고리즘 문제 풀이"].label, "알고리즘 문제 풀이")

        app.terminate()
        app.launch()
        XCTAssertTrue(study.waitForExistence(timeout: 3))
    }

    @MainActor
    private func chooseRepository(_ mode: String, in app: XCUIApplication) {
        let row = app.buttons.containing(.staticText, identifier: "Repository").firstMatch
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
        let mainTab = app.tabBars.buttons["스터디"]
        let settingTab = app.tabBars.buttons["설정"]
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
        app.buttons["닫기"].tap()
        XCTAssertTrue(mainTab.waitForExistence(timeout: 2))
        mainTab.press(forDuration: 1)
        XCTAssertTrue(app.navigationBars["Development Settings"].waitForExistence(timeout: 2))
        #else
        XCTAssertFalse(app.navigationBars["Development Settings"].exists)
        #endif
    }
}
