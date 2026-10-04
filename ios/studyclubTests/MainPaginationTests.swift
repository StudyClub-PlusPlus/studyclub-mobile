import Combine
import XCTest
@testable import studyclub

@MainActor
final class MainPaginationTests: XCTestCase {
    func testAutomaticNextPageUsesRawOffsetAndUpdatesDuplicateCard() async {
        let repository = ControlledListRepository()
        let viewModel = MainViewModel(repository: repository)
        var contentNotifications = 0
        let subscription = viewModel.statePublisher.sink {
            if $0 == .content { contentNotifications += 1 }
        }
        await waitUntil { await repository.count == 1 }
        await repository.complete(0, .success(page([study("1"), study("2"), study("1")], total: 6)))
        await waitUntil { viewModel.currentState == .content }

        viewModel.loadMore()
        viewModel.loadMore()
        await waitUntil { await repository.count == 2 }
        let requested = await repository.offsets
        XCTAssertEqual(requested, [0, 3])
        await repository.complete(1, .success(page([study("2"), study("3"), study("2", title: "최신 값")], total: 6, offset: 3)))
        await waitUntil { viewModel.pageState == .idle }
        XCTAssertEqual(viewModel.items.map(\.id), ["1", "2", "3"])
        XCTAssertEqual(viewModel.study(for: "2")?.title, "최신 값")
        XCTAssertGreaterThan(contentNotifications, 1)
        viewModel.loadMore()
        await Task.yield()
        let count = await repository.count
        XCTAssertEqual(count, 2)
        withExtendedLifetime(subscription) {}
    }

    func testFailedNextPagePreservesContentAndRetriesTheSameOffset() async {
        let repository = ControlledListRepository()
        let viewModel = MainViewModel(repository: repository)
        await initialContent(viewModel, repository)
        viewModel.loadMore()
        await waitUntil { await repository.count == 2 }
        await repository.complete(1, .failure(RepositoryError.unavailable))
        await waitUntil { viewModel.pageState == .failure }
        XCTAssertEqual(viewModel.currentState, .content)
        XCTAssertEqual(viewModel.items.map(\.id), ["1"])
        viewModel.loadMore()
        await Task.yield()
        let beforeRetry = await repository.count
        XCTAssertEqual(beforeRetry, 2)
        viewModel.retryPage()
        await waitUntil { await repository.count == 3 }
        let requested = await repository.offsets
        XCTAssertEqual(requested, [0, 1, 1])
        await repository.complete(2, .success(page([study("2")], total: 2, offset: 1)))
        await waitUntil { viewModel.pageState == .idle }
        XCTAssertEqual(viewModel.items.map(\.id), ["1", "2"])
    }

    func testRefreshDiscardsLateCancelledPageAndKeepsCurrentTaskBusy() async {
        let repository = ControlledListRepository()
        let viewModel = MainViewModel(repository: repository)
        await initialContent(viewModel, repository)
        viewModel.loadMore()
        await waitUntil { await repository.count == 2 }
        viewModel.refresh()
        viewModel.refresh()
        await waitUntil { await repository.count == 3 }
        // The old repository operation deliberately ignores cancellation.
        await repository.complete(1, .failure(RepositoryError.unavailable))
        await Task.yield()
        XCTAssertTrue(viewModel.isRefreshing)
        viewModel.loadMore()
        let count = await repository.count
        XCTAssertEqual(count, 3)
        await repository.complete(2, .success(page([study("9")], total: 1)))
        await waitUntil { !viewModel.isRefreshing }
        XCTAssertEqual(viewModel.items.map(\.id), ["9"])
        XCTAssertEqual(viewModel.pageState, .idle)
        XCTAssertNil(viewModel.refreshError)
    }

    func testLateSuccessCannotAppendAfterRefreshHasReplacedList() async {
        let repository = ControlledListRepository()
        let viewModel = MainViewModel(repository: repository)
        await initialContent(viewModel, repository)
        viewModel.loadMore()
        await waitUntil { await repository.count == 2 }
        viewModel.refresh()
        await waitUntil { await repository.count == 3 }
        await repository.complete(2, .success(page([study("9"), study("8"), study("9", title: "갱신 값")], total: 3)))
        await waitUntil { !viewModel.isRefreshing }
        await repository.complete(1, .success(page([study("2")], total: 2, offset: 1)))
        await Task.yield()
        XCTAssertEqual(viewModel.items.map(\.id), ["9", "8"])
        XCTAssertEqual(viewModel.study(for: "9")?.title, "갱신 값")
        XCTAssertNil(viewModel.study(for: "1"))
        XCTAssertNil(viewModel.study(for: "2"))
    }

    func testRefreshFailurePreservesContentAndCursorThenEmptyRefreshClearsSelection() async {
        let repository = ControlledListRepository()
        let viewModel = MainViewModel(repository: repository)
        await initialContent(viewModel, repository)
        viewModel.refresh()
        await waitUntil { await repository.count == 2 }
        await repository.complete(1, .failure(RepositoryError.unavailable))
        await waitUntil { !viewModel.isRefreshing }
        XCTAssertEqual(viewModel.items.map(\.id), ["1"])
        XCTAssertNotNil(viewModel.refreshError)
        viewModel.loadMore()
        await waitUntil { await repository.count == 3 }
        let requested = await repository.offsets
        XCTAssertEqual(requested, [0, 0, 1])
        await repository.complete(2, .success(page([study("2")], total: 2, offset: 1)))
        await waitUntil { viewModel.pageState == .idle }
        viewModel.refresh()
        await waitUntil { await repository.count == 4 }
        await repository.complete(3, .success(page([], total: 0)))
        await waitUntil { viewModel.currentState == .empty }
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertNil(viewModel.study(for: "1"))
        XCTAssertNil(viewModel.study(for: "2"))
    }

    func testZeroProgressStopsAutomaticRequestsAndCanRefresh() async {
        let repository = ControlledListRepository()
        let viewModel = MainViewModel(repository: repository)
        await initialContent(viewModel, repository)
        viewModel.loadMore()
        await waitUntil { await repository.count == 2 }
        await repository.complete(1, .success(page([], total: 2, offset: 1)))
        await waitUntil { viewModel.pageState == .stalled }
        viewModel.loadMore()
        viewModel.retryPage()
        await Task.yield()
        let count = await repository.count
        XCTAssertEqual(count, 2)
        XCTAssertEqual(viewModel.items.map(\.id), ["1"])
        viewModel.refresh()
        await waitUntil { await repository.count == 3 }
        await repository.complete(2, .success(page([], total: 0)))
        await waitUntil { viewModel.currentState == .empty }
        XCTAssertEqual(viewModel.pageState, .idle)
    }

    private func initialContent(_ vm: MainViewModel, _ repository: ControlledListRepository) async {
        await waitUntil { await repository.count == 1 }
        await repository.complete(0, .success(page([study("1")], total: 2)))
        await waitUntil { vm.currentState == .content }
    }

    private func study(_ id: String, title: String = "Study") -> Study {
        Study(id: id, category: .software, title: title, summary: "Summary",
              participantCount: 1, capacity: nil, phase: .recruiting, closingSoon: false)
    }

    private func page(_ studies: [Study], total: Int, offset: Int = 0) -> StudyPage {
        StudyPage(studies: studies, totalCount: total, offset: offset)
    }

    private func waitUntil(_ condition: () async -> Bool) async {
        for _ in 0..<100 {
            if await condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for list request/state")
    }
}

private actor ControlledListRepository: RepositoryProtocol {
    private var continuations: [Int: CheckedContinuation<StudyPage, any Error>] = [:]
    private(set) var offsets: [Int] = []
    var count: Int { offsets.count }

    func fetchStudies(offset: Int) async throws -> StudyPage {
        let index = offsets.count
        offsets.append(offset)
        return try await withCheckedThrowingContinuation { continuations[index] = $0 }
    }

    func complete(_ index: Int, _ result: Result<StudyPage, any Error>) {
        continuations.removeValue(forKey: index)?.resume(with: result)
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetail { throw RepositoryError.unavailable }
}
