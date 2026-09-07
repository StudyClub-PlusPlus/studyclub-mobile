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
        await fulfillment(of: [content], timeout: 2)
        let ids = await repository.requestedIDs
        XCTAssertEqual(ids, ["selected"])
        XCTAssertEqual(states, [.loading, .content])
        withExtendedLifetime(subscription) {}
    }

    func testFailureEndsLoadingWithoutAnotherRequest() async {
        let repository = DetailRepositoryDouble(shouldFail: true)
        let model = DetailViewModel(studyID: "selected", repository: repository)
        let failed = expectation(description: "failure")
        let subscription = model.statePublisher.sink { state in
            if state == .failure { failed.fulfill() }
        }
        await fulfillment(of: [failed], timeout: 2)
        XCTAssertEqual(model.currentState, .failure)
        XCTAssertEqual(model.title, "")
        let ids = await repository.requestedIDs
        XCTAssertEqual(ids, ["selected"])
        withExtendedLifetime(subscription) {}
    }

    func testSubscriberReceivesContentAfterRequestHasAlreadyFinished() async {
        let repository = DetailRepositoryDouble()
        let model = DetailViewModel(studyID: "selected", repository: repository)
        let loaded = expectation(description: "loaded before binding")
        let initialSubscription = model.statePublisher.sink { state in
            if state == .content { loaded.fulfill() }
        }
        await fulfillment(of: [loaded], timeout: 2)
        initialSubscription.cancel()

        var receivedStates: [DetailViewModel.LoadState] = []
        let lateSubscription = model.statePublisher.sink { state in
            receivedStates.append(state)
            XCTAssertEqual(model.title, "상세 응답")
        }
        XCTAssertEqual(receivedStates, [.content])
        let ids = await repository.requestedIDs
        XCTAssertEqual(ids, ["selected"])
        withExtendedLifetime(lateSubscription) {}
    }
}

private actor DetailRepositoryDouble: RepositoryProtocol {
    private(set) var requestedIDs: [Study.ID] = []
    let shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func fetchStudies() async throws -> [Study] {
        XCTFail("Detail must not fetch the list")
        return []
    }

    func fetchStudy(id: Study.ID) async throws -> Study {
        requestedIDs.append(id)
        if shouldFail { throw RepositoryError.unavailable }
        return Study(id: id, category: "iOS", title: "상세 응답",
                     summary: "전체 설명", currentMembers: 2, maximumMembers: 8,
                     status: .recruiting, topics: [])
    }
}
