import Combine
import Foundation
import UIKit
import XCTest
@testable import studyclub

/// Opt-in read-only verification against the deployed public API.
final class LiveStudyDetailTests: XCTestCase {
    func testPublicDetailReturnsRequestedStudy() async throws {
        let baseURL = try liveBaseURL()
        let repository = RepositoryFactory.makeLiveStudyRepository(baseURL: baseURL)
        let detail = try await repository.fetchStudy(id: "18")
        XCTAssertEqual(detail.id, "18")
        XCTAssertEqual(detail.category, .software)
        XCTAssertFalse(detail.title.isEmpty)
    }

    func testClosedPublicDetailAllowsNullRecruitmentStatus() async throws {
        let baseURL = try liveBaseURL()
        let repository = RepositoryFactory.makeLiveStudyRepository(baseURL: baseURL)
        let detail = try await repository.fetchStudy(id: "87")
        XCTAssertEqual(detail.id, "87")
        XCTAssertEqual(detail.status, .closed)
        XCTAssertNil(detail.recruitStatus)
    }

    func testMissingPublicDetailReturnsNotFound() async throws {
        let baseURL = try liveBaseURL()
        let repository = RepositoryFactory.makeLiveStudyRepository(baseURL: baseURL)
        do {
            _ = try await repository.fetchStudy(id: "999999")
            XCTFail("Expected not found")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .notFound)
        }
    }

    @MainActor
    func testLiveDetailViewModelAndScreenRenderContent() async throws {
        let repository = RepositoryFactory.makeLiveStudyRepository(baseURL: try liveBaseURL())
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

    private func liveBaseURL() throws -> URL {
        guard let value = ProcessInfo.processInfo.environment["STUDYCLUB_LIVE_API_BASE_URL"],
              let url = URL(string: value) else {
            throw XCTSkip("Set STUDYCLUB_LIVE_API_BASE_URL to opt into live API checks")
        }
        return url
    }
}
