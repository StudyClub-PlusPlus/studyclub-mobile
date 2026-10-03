import Combine
import Foundation
import UIKit
import XCTest
@testable import studyclub

/// Opt-in read-only verification against the deployed public API.
final class LiveStudyDetailTests: XCTestCase {
    func testPublicDetailReturnsRequestedStudy() async throws {
        try requireLiveProductionOptIn()
        let repository = Repository()
        let detail = try await repository.fetchStudy(id: "18")
        XCTAssertEqual(detail.id, "18")
        XCTAssertEqual(detail.category, .software)
        XCTAssertFalse(detail.title.isEmpty)
    }

    func testClosedPublicDetailAllowsNullRecruitmentStatus() async throws {
        try requireLiveProductionOptIn()
        let repository = Repository()
        let detail = try await repository.fetchStudy(id: "87")
        XCTAssertEqual(detail.id, "87")
        XCTAssertEqual(detail.status, .closed)
        XCTAssertNil(detail.recruitStatus)
    }

    func testMissingPublicDetailReturnsNotFound() async throws {
        try requireLiveProductionOptIn()
        let repository = Repository()
        do {
            _ = try await repository.fetchStudy(id: "999999")
            XCTFail("Expected not found")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .notFound)
        }
    }

    @MainActor
    func testLiveDetailViewModelAndScreenRenderContent() async throws {
        try requireLiveProductionOptIn()
        let repository = Repository()
        let model = DetailViewModel(studyID: "18", repository: repository)
        let loaded = expectation(description: "live detail content")
        let subscription = model.statePublisher.sink { state in
            if state == .content || state == .empty || state == .failure { loaded.fulfill() }
        }
        await fulfillment(of: [loaded], timeout: 20)
        XCTAssertEqual(model.currentState, .content)
        XCTAssertEqual(model.category, "소프트웨어")
        XCTAssertFalse(model.title.isEmpty)
        let controller = DetailViewController(viewModel: model)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { context in
            controller.view.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "live-detail-content"
        attachment.lifetime = .keepAlways
        add(attachment)
        withExtendedLifetime(subscription) {}
    }

    private func requireLiveProductionOptIn() throws {
        guard let value = ProcessInfo.processInfo.environment["STUDYCLUB_LIVE_API_BASE_URL"] else {
            throw XCTSkip("Set STUDYCLUB_LIVE_API_BASE_URL to the Production URL to opt into live API checks")
        }
        guard URL(string: value) == URL(string: "https://api.studyclub-plusplus.com/api/") else {
            throw XCTSkip("The concrete Repository uses Production only; other base URLs are unsupported")
        }
    }
}
