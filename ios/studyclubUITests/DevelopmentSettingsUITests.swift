import XCTest

final class DevelopmentSettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

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
