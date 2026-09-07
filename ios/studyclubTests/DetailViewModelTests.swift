import Combine
import XCTest
@testable import studyclub

@MainActor
final class DetailViewModelTests: XCTestCase {
    func testDisplayValuesAreReadyWhenContentIsPublishedAndInitialLoadRunsOnce() async {
        let repository = DetailRepositoryDouble()
        let model = DetailViewModel(studyID: "selected", repository: repository)
        let content = expectation(description: "content")
        var states: [DetailViewModel.LoadState] = []
        let subscription = model.statePublisher.sink { state in
            states.append(state)
            if state == .content {
                XCTAssertEqual(model.title, "상세 응답")
                XCTAssertEqual(model.category, "iOS")
                XCTAssertEqual(model.summary, "전체 설명")
                XCTAssertEqual(model.memberText, "멤버 2/8")
                XCTAssertEqual(model.statusText, "모집 중")
                XCTAssertEqual(model.topics, [])
                content.fulfill()
            }
        }
        model.loadIfNeeded()
        model.loadIfNeeded()
        await fulfillment(of: [content], timeout: 2)
        let ids = await repository.requestedIDs
        XCTAssertEqual(ids, ["selected"])
        XCTAssertEqual(states, [.loading, .loading, .content])
        withExtendedLifetime(subscription) {}
    }

    func testFailureRetryAndStaleResponseProtection() async {
        let repository = DetailRepositoryDouble(failsFirst: true)
        let model = DetailViewModel(studyID: "selected", repository: repository)
        let failed = expectation(description: "failure")
        let content = expectation(description: "content")
        let subscription = model.statePublisher.sink { state in
            if state == .failure { failed.fulfill() }
            if state == .content { content.fulfill() }
        }
        model.loadIfNeeded()
        await fulfillment(of: [failed], timeout: 2)
        model.retry()
        XCTAssertEqual(model.currentState, .loading)
        await fulfillment(of: [content], timeout: 2)
        XCTAssertEqual(model.title, "상세 응답")
        withExtendedLifetime(subscription) {}
    }

    func testCancelledRequestIgnoringCancellationCannotOverwriteRetry() async {
        let repository = DetailRepositoryDouble(delaysFirst: true)
        let model = DetailViewModel(studyID: "selected", repository: repository)
        let fresh = expectation(description: "fresh content")
        let subscription = model.statePublisher.sink { state in
            if state == .content { fresh.fulfill() }
        }
        model.loadIfNeeded()
        while await repository.requestedIDs.isEmpty { await Task.yield() }
        model.retry()
        await fulfillment(of: [fresh], timeout: 2)
        await repository.releaseFirstRequest()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.title, "상세 응답")
        withExtendedLifetime(subscription) {}
    }
}

private actor DetailRepositoryDouble: RepositoryProtocol {
    private(set) var requestedIDs: [Study.ID] = []
    let failsFirst: Bool
    let delaysFirst: Bool
    private var continuation: CheckedContinuation<Void, Never>?

    init(failsFirst: Bool = false, delaysFirst: Bool = false) {
        self.failsFirst = failsFirst
        self.delaysFirst = delaysFirst
    }

    func fetchStudies() async throws -> [Study] {
        XCTFail("Detail must not fetch the list")
        return []
    }

    func fetchStudy(id: Study.ID) async throws -> Study {
        requestedIDs.append(id)
        let first = requestedIDs.count == 1
        if first && failsFirst { throw RepositoryError.unavailable }
        if first && delaysFirst {
            await withCheckedContinuation { continuation = $0 }
        }
        return Study(id: id, category: "iOS",
                     title: first && delaysFirst ? "오래된 응답" : "상세 응답",
                     summary: "전체 설명", currentMembers: 2, maximumMembers: 8,
                     status: .recruiting, topics: [])
    }

    func releaseFirstRequest() {
        continuation?.resume()
        continuation = nil
    }
}
