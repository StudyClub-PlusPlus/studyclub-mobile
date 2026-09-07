import XCTest

final class StudyClubFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testContentOpensTheSelectedStudyDetail() {
        let app = launchApp(scenario: "content")
        let selectedStudy = app.descendants(matching: .any)["main.study.algorithm"]

        XCTAssertTrue(selectedStudy.waitForExistence(timeout: 3))
        selectedStudy.tap()

        let detailTitle = app.staticTexts["detail.title"]
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

        XCTAssertTrue(app.otherElements["main.state.empty"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["main.state.failure"].exists)
        XCTAssertFalse(app.collectionViews["main.collection"].isHittable)
    }

    @MainActor
    func testFailureRetryLoadsContent() {
        let app = launchApp(scenario: "failure-once")
        let failureState = app.otherElements["main.state.failure"]
        XCTAssertTrue(failureState.waitForExistence(timeout: 3))

        let retryButton = app.buttons["main.state.action"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 1))
        retryButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["main.study.ios-architecture"].waitForExistence(timeout: 3))
        XCTAssertFalse(failureState.exists)
    }

    @MainActor
    func testLoadingStateIsVisible() {
        let app = launchApp(scenario: "loading")

        XCTAssertTrue(app.otherElements["main.state.loading"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.collectionViews["main.collection"].isHittable)
    }

    @MainActor
    func testDetailFailureAllowsBackNavigationWithoutRetry() {
        let app = launchApp(scenario: "detail-failure")
        let selected = app.descendants(matching: .any)["main.study.algorithm"]
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
        selected.tap()
        XCTAssertTrue(app.otherElements["detail.state.failure"].waitForExistence(timeout: 3))
        capture(app, name: "detail-failure")
        XCTAssertFalse(app.buttons["detail.state.action"].exists)
        XCTAssertFalse(app.staticTexts["detail.title"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
    }

    @MainActor
    func testDetailLoadingAndBackNavigation() {
        let app = launchApp(scenario: "detail-loading")
        let selected = app.descendants(matching: .any)["main.study.algorithm"]
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
        selected.tap()
        XCTAssertTrue(app.otherElements["detail.state.loading"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["detail.title"].exists)
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
