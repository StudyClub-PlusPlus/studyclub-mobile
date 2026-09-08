import XCTest

final class StudyClubFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabsPreserveMainNavigationAndSettingHasAnEmptyList() {
        let app = launchApp(scenario: "content")
        let selectedStudy = app.collectionViews.cells.containing(.staticText, identifier: "알고리즘 문제 풀이").firstMatch
        XCTAssertTrue(selectedStudy.waitForExistence(timeout: 3))
        selectedStudy.tap()
        XCTAssertTrue(app.scrollViews.staticTexts["알고리즘 문제 풀이"].waitForExistence(timeout: 3))

        app.tabBars.buttons["설정"].tap()
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 2))
        XCTAssertEqual(list.cells.count, 0)
        capture(app, name: "setting-empty")

        app.tabBars.buttons["스터디"].tap()
        XCTAssertTrue(app.scrollViews.staticTexts["알고리즘 문제 풀이"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.scrollViews.staticTexts["알고리즘 문제 풀이"].label, "알고리즘 문제 풀이")
    }

    @MainActor
    func testContentOpensTheSelectedStudyDetail() {
        let app = launchApp(scenario: "content")
        let selectedStudy = app.collectionViews.cells.containing(.staticText, identifier: "알고리즘 문제 풀이").firstMatch

        XCTAssertTrue(selectedStudy.waitForExistence(timeout: 3))
        capture(app, name: "main-content")
        selectedStudy.tap()

        let detailTitle = app.scrollViews.staticTexts["알고리즘 문제 풀이"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 2))
        XCTAssertEqual(detailTitle.label, "알고리즘 문제 풀이")
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "detail-content"
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor
    func testEmptyStateIsDistinctFromFailure() {
        let app = launchApp(scenario: "empty")

        XCTAssertTrue(app.staticTexts["아직 열린 스터디가 없어요"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["목록을 불러오지 못했어요"].exists)
        XCTAssertFalse(app.buttons["다시 시도"].exists)
        capture(app, name: "main-empty")
        XCTAssertFalse(app.collectionViews.firstMatch.isHittable)
    }

    @MainActor
    func testFailureHasNoRetryAction() {
        let app = launchApp(scenario: "failure")
        XCTAssertTrue(app.staticTexts["목록을 불러오지 못했어요"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["다시 시도"].exists)
        XCTAssertFalse(app.collectionViews.firstMatch.isHittable)
        capture(app, name: "main-failure")
    }

    @MainActor
    func testLoadingStateIsVisible() {
        let app = launchApp(scenario: "loading")

        XCTAssertTrue(app.staticTexts["스터디를 불러오는 중이에요"].waitForExistence(timeout: 2))
        capture(app, name: "main-loading")
        XCTAssertFalse(app.collectionViews.firstMatch.isHittable)
    }

    @MainActor
    func testDetailFailureAllowsBackNavigationWithoutRetry() {
        let app = launchApp(scenario: "detail-failure")
        let selected = app.collectionViews.cells.containing(.staticText, identifier: "알고리즘 문제 풀이").firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
        selected.tap()
        XCTAssertTrue(app.staticTexts["상세 정보를 불러오지 못했어요"].waitForExistence(timeout: 3))
        capture(app, name: "detail-failure")
        XCTAssertFalse(app.buttons["다시 시도"].exists)
        XCTAssertFalse(app.scrollViews.staticTexts["알고리즘 문제 풀이"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
    }

    @MainActor
    func testDetailLoadingAndBackNavigation() {
        let app = launchApp(scenario: "detail-loading")
        let selected = app.collectionViews.cells.containing(.staticText, identifier: "알고리즘 문제 풀이").firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
        selected.tap()
        XCTAssertTrue(app.staticTexts["스터디 상세를 불러오는 중이에요"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.scrollViews.staticTexts["알고리즘 문제 풀이"].exists)
        capture(app, name: "detail-loading")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func launchApp(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--mock-scenario", scenario]
        app.launch()
        return app
    }
}
