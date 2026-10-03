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
                XCTAssertEqual(model.category, "소프트웨어")
                XCTAssertEqual(model.descriptionText, "전체 설명")
                XCTAssertEqual(model.metadataText, "스터디  ·  온라인  ·  정원 8명")
                XCTAssertEqual(model.recruitStatusText, "모집 중")
                XCTAssertEqual(model.curriculum, "")
                XCTAssertEqual(model.scheduleText, "2026. 10. 15. - 2026. 12. 15.")
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

    func testNotFoundShowsEmptyState() async {
        let repository = DetailRepositoryDouble(error: .notFound)
        let model = DetailViewModel(studyID: "missing", repository: repository)
        let empty = expectation(description: "empty")
        let subscription = model.statePublisher.sink { state in
            if state == .empty { empty.fulfill() }
        }
        await fulfillment(of: [empty], timeout: 2)
        XCTAssertEqual(model.currentState, .empty)
        withExtendedLifetime(subscription) {}
    }

    func testInvalidDataShowsEmptyState() async {
        let repository = DetailRepositoryDouble(error: .invalidData)
        let model = DetailViewModel(studyID: "selected", repository: repository)
        let empty = expectation(description: "invalid detail is empty")
        let subscription = model.statePublisher.sink { state in
            if state == .empty { empty.fulfill() }
        }
        await fulfillment(of: [empty], timeout: 2)
        XCTAssertEqual(model.currentState, .empty)
        XCTAssertEqual(model.title, "")
        withExtendedLifetime(subscription) {}
    }

    func testMismatchedIdentityShowsEmptyInsteadOfContent() async {
        let repository = DetailRepositoryDouble(returnedID: "other")
        let model = DetailViewModel(studyID: "selected", repository: repository)
        let empty = expectation(description: "mismatched detail is empty")
        let subscription = model.statePublisher.sink { state in
            if state == .empty { empty.fulfill() }
        }
        await fulfillment(of: [empty], timeout: 2)
        XCTAssertEqual(model.currentState, .empty)
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
    let error: RepositoryError?
    let returnedID: Study.ID?

    init(shouldFail: Bool = false, error: RepositoryError? = nil, returnedID: Study.ID? = nil) {
        self.error = error ?? (shouldFail ? .unavailable : nil)
        self.returnedID = returnedID
    }

    func fetchStudies() async throws -> [Study] {
        XCTFail("Detail must not fetch the list")
        return []
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetail {
        requestedIDs.append(id)
        if let error { throw error }
        return StudyDetail(
            id: returnedID ?? id,
            title: "상세 응답",
            description: "전체 설명",
            category: .software,
            studyKind: .study,
            thumbnailURL: nil,
            deliveryFormat: .online,
            status: .open,
            recruitStatus: .recruiting,
            curriculum: "",
            capacity: 8,
            recruitDeadlineAt: nil,
            startAt: try! Date("2026-10-15T00:00:00Z", strategy: .iso8601),
            endAt: try! Date("2026-12-15T00:00:00Z", strategy: .iso8601)
        )
    }
}
