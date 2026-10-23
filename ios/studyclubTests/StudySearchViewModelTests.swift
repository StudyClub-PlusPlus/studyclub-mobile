import Combine
import XCTest
@testable import studyclub

@MainActor
final class StudySearchViewModelTests: XCTestCase {
    private var subscriptions = Set<AnyCancellable>()

    func testInitialBlankCompositionAndOFFStayIdleWithoutRequests() async {
        let repository = ControlledSearchRepository()
        let vm = StudySearchViewModel(repository: repository)
        vm.updateInput("  ", isComposing: false)
        vm.selectCategory(.software)
        vm.updateInput("ㅎ", isComposing: true)
        XCTAssertEqual(vm.currentState, .idle)
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertFalse(vm.canLoadMore)
        let off = StudySearchViewModel(repository: repository, isSearchEnabled: false)
        off.updateInput("Swift", isComposing: false)
        off.loadMore()
        off.retry()
        XCTAssertEqual(off.currentState, .idle)
        let count = await repository.requests.count
        XCTAssertEqual(count, 0)
    }

    func testDebounceReplacesPendingInputAndSearchesAutomatically() async {
        let repository = ControlledSearchRepository()
        let vm = StudySearchViewModel(repository: repository)
        vm.updateInput("S", isComposing: false)
        vm.updateInput("Sw", isComposing: false)
        vm.updateInput("Swift", isComposing: false)
        await request(0, repository)
        let requests = await repository.requests
        XCTAssertEqual(requests.map(\.query.keyword), ["Swift"])
        let content = state(vm, .content)
        await repository.complete(0, .success(page([study("9001", phase: .closed)], total: 1)))
        await fulfillment(of: [content], timeout: 2)
        XCTAssertEqual(vm.items.map(\.id), ["9001"])
    }

    func testCompositionInvalidatesInFlightErrorAndCommitsLatestInput() async {
        let repository = ControlledSearchRepository()
        let vm = StudySearchViewModel(repository: repository)
        vm.updateInput("한", isComposing: false)
        await request(0, repository)
        vm.updateInput("한국", isComposing: true)
        XCTAssertEqual(vm.currentState, .idle)
        vm.updateInput("한국", isComposing: false)
        await request(1, repository)
        let content = state(vm, .content)
        // This repository deliberately returns after cancellation.
        await repository.complete(0, .failure(RepositoryError.unavailable))
        await repository.complete(1, .success(page([study("2")], total: 1)))
        await fulfillment(of: [content], timeout: 2)
        XCTAssertEqual(vm.currentState, .content)
        XCTAssertEqual(vm.items.map(\.id), ["2"])
    }

    func testDeletingInputInvalidatesLateSuccessAndClearsSelection() async {
        let repository = ControlledSearchRepository()
        let vm = StudySearchViewModel(repository: repository)
        vm.updateInput("old", isComposing: false)
        await request(0, repository)
        vm.updateInput("", isComposing: false)
        XCTAssertEqual(vm.currentState, .idle)
        XCTAssertTrue(vm.items.isEmpty)
        vm.updateInput("new", isComposing: false)
        await request(1, repository)
        let content = state(vm, .content)
        await repository.complete(0, .success(page([study("old")], total: 99)))
        await repository.complete(1, .success(page([study("new")], total: 1)))
        await fulfillment(of: [content], timeout: 2)
        XCTAssertEqual(vm.items.map(\.id), ["new"])
        XCTAssertFalse(vm.canLoadMore)
        vm.updateInput("", isComposing: false)
        XCTAssertEqual(vm.currentState, .idle)
        XCTAssertTrue(vm.items.isEmpty)
    }

    func testFiltersInvalidateOldPaginationAndUseIndependentConditions() async {
        let repository = ControlledSearchRepository()
        let vm = StudySearchViewModel(repository: repository)
        await initialContent(vm, repository)
        vm.loadMore()
        await request(1, repository)
        vm.selectPhase(.closed)
        vm.selectCategory(.software)
        await request(2, repository)
        let query = await repository.requests[2].query
        XCTAssertEqual(query, StudySearchQuery(keyword: "앱", phase: .closed, category: .software))
        let content = state(vm, .content)
        await repository.complete(1, .success(page([study("old-page")], total: 2, offset: 1)))
        await repository.complete(2, .success(page([study("closed", phase: .closed)], total: 1)))
        await fulfillment(of: [content], timeout: 2)
        XCTAssertEqual(vm.items.map(\.id), ["closed"])
        XCTAssertEqual(vm.pageState, .idle)
    }

    func testCancelInvalidatesPageAndKeepsFiltersForControllerLifetime() async {
        let repository = ControlledSearchRepository()
        let vm = StudySearchViewModel(repository: repository)
        vm.selectCategory(.software)
        await initialContent(vm, repository)
        vm.loadMore()
        await request(1, repository)
        vm.endSearch()
        XCTAssertEqual(vm.currentState, .idle)
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertEqual(vm.query.category, .software)
        XCTAssertEqual(vm.query.keyword, "")
        vm.updateInput("다시", isComposing: false)
        await request(2, repository)
        let content = state(vm, .content)
        await repository.complete(1, .failure(RepositoryError.unavailable))
        await repository.complete(2, .success(page([study("new")], total: 1)))
        await fulfillment(of: [content], timeout: 2)
        XCTAssertEqual(vm.items.map(\.id), ["new"])
        XCTAssertEqual(vm.pageState, .idle)
    }

    func testZeroResultsAreEmptyAndFailureCanRetry() async {
        let repository = ControlledSearchRepository()
        let vm = StudySearchViewModel(repository: repository)
        vm.updateInput("앱", isComposing: false)
        await request(0, repository)
        let failed = state(vm, .failure)
        await repository.complete(0, .failure(RepositoryError.unavailable))
        await fulfillment(of: [failed], timeout: 2)
        vm.retry()
        await request(1, repository)
        let empty = state(vm, .empty)
        await repository.complete(1, .success(page([], total: 0)))
        await fulfillment(of: [empty], timeout: 2)
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertFalse(vm.canLoadMore)
    }

    func testPaginationUsesRawCountMergesIDsAndRetriesSameOffset() async {
        let repository = ControlledSearchRepository()
        let vm = StudySearchViewModel(repository: repository)
        vm.updateInput("앱", isComposing: false)
        await request(0, repository)
        let first = state(vm, .content)
        await repository.complete(0, .success(page([study("1"), study("1", title: "최신")], total: 4)))
        await fulfillment(of: [first], timeout: 2)
        XCTAssertEqual(vm.items.count, 1)
        vm.loadMore()
        vm.loadMore()
        await request(1, repository)
        let failed = expectation(description: "page failure")
        vm.statePublisher.filter { _ in vm.pageState == .failure }.prefix(1)
            .sink { _ in failed.fulfill() }.store(in: &subscriptions)
        await repository.complete(1, .failure(RepositoryError.unavailable))
        await fulfillment(of: [failed], timeout: 2)
        XCTAssertEqual(vm.items.map(\.id), ["1"])
        vm.retry()
        await request(2, repository)
        let requests = await repository.requests
        XCTAssertEqual(requests.map(\.offset), [0, 2, 2])
        let content = state(vm, .content, pageState: .idle)
        await repository.complete(2, .success(page([study("1", title: "갱신 값"), study("2")], total: 4, offset: 2)))
        await fulfillment(of: [content], timeout: 2)
        XCTAssertEqual(vm.items.map(\.id), ["1", "2"])
        XCTAssertEqual(vm.items.first?.title, "갱신 값")
        XCTAssertFalse(vm.canLoadMore)
    }

    func testZeroProgressStopsPaginationUntilExplicitRetry() async {
        let repository = ControlledSearchRepository()
        let vm = StudySearchViewModel(repository: repository)
        await initialContent(vm, repository)
        vm.loadMore()
        await request(1, repository)
        let stalled = state(vm, .content, pageState: .stalled)
        await repository.complete(1, .success(page([], total: 2, offset: 1)))
        await fulfillment(of: [stalled], timeout: 2)
        XCTAssertEqual(vm.items.map(\.id), ["1"])
        vm.retry()
        await request(2, repository)
        let offset = await repository.requests[2].offset
        XCTAssertEqual(offset, 0)
        let empty = state(vm, .empty)
        await repository.complete(2, .success(page([], total: 0)))
        await fulfillment(of: [empty], timeout: 2)
        XCTAssertTrue(vm.items.isEmpty)
    }

    private func request(_ index: Int, _ repository: ControlledSearchRepository) async {
        let expectation = await repository.expectRequest(index)
        await fulfillment(of: [expectation], timeout: 2)
    }

    private func state(_ vm: StudySearchViewModel, _ state: StudySearchViewModel.LoadState,
                       pageState: StudySearchViewModel.PageState? = nil) -> XCTestExpectation {
        let expectation = expectation(description: "\(state)")
        vm.statePublisher.filter { value in value == state && (pageState == nil || vm.pageState == pageState) }
            .prefix(1).sink { _ in expectation.fulfill() }.store(in: &subscriptions)
        return expectation
    }

    private func initialContent(_ vm: StudySearchViewModel, _ repository: ControlledSearchRepository) async {
        vm.updateInput("앱", isComposing: false)
        await request(0, repository)
        let content = state(vm, .content)
        await repository.complete(0, .success(page([study("1")], total: 2)))
        await fulfillment(of: [content], timeout: 2)
    }

    private func study(_ id: String, title: String = "Study", phase: StudyPhase = .recruiting) -> Study {
        Study(id: id, category: .software, title: title, summary: "Summary", participantCount: 1,
              capacity: nil, phase: phase, closingSoon: false)
    }

    private func page(_ studies: [Study], total: Int, offset: Int = 0) -> StudyPage {
        StudyPage(studies: studies, totalCount: total, offset: offset)
    }
}

private actor ControlledSearchRepository: RepositoryProtocol {
    struct Request: Sendable {
        let query: StudySearchQuery
        let offset: Int
    }
    private(set) var requests: [Request] = []
    private var continuations: [Int: CheckedContinuation<StudyPage, any Error>] = [:]
    private var expectations: [Int: XCTestExpectation] = [:]

    func expectRequest(_ index: Int) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "search request \(index)")
        if requests.count > index { expectation.fulfill() } else { expectations[index] = expectation }
        return expectation
    }

    func searchStudies(query: StudySearchQuery, offset: Int) async throws -> StudyPage {
        let index = requests.count
        requests.append(Request(query: query, offset: offset))
        return try await withCheckedThrowingContinuation { continuation in
            continuations[index] = continuation
            expectations.removeValue(forKey: index)?.fulfill()
        }
    }

    func complete(_ index: Int, _ result: Result<StudyPage, any Error>) {
        continuations.removeValue(forKey: index)?.resume(with: result)
    }

    func fetchStudies(offset: Int) async throws -> StudyPage { throw RepositoryError.unavailable }
    func fetchStudy(id: Study.ID) async throws -> StudyDetail { throw RepositoryError.notFound }
    func fetchMyStudies() async throws -> [MyStudy] { throw RepositoryError.unavailable }
}
