import Combine
import XCTest
@testable import studyclub

@MainActor
final class MainViewModelTests: XCTestCase {
    func testStatePublisherSynchronouslyReplaysCurrentStateWhenSinkBinds() {
        let repository = TestStudyRepository(behaviors: [])
        let viewModel = MainViewModel(repository: repository)
        var receivedStates: [MainViewState] = []

        let cancellable = viewModel.statePublisher.sink { state in
            receivedStates.append(state)
        }

        XCTAssertEqual(receivedStates, [.loading])
        withExtendedLifetime(cancellable) {}
    }

    func testLoadTransitionsToContentAndResolvesStableSelection() async {
        let expected = makeStudy(id: "selected", title: "선택한 스터디")
        let repository = TestStudyRepository(behaviors: [.success([expected])])
        let viewModel = MainViewModel(repository: repository)

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.currentState == .content([StudyListItemViewData(study: expected)]) }

        XCTAssertEqual(viewModel.study(for: "selected"), expected)
    }

    func testEmptyResultTransitionsToEmpty() async {
        let repository = TestStudyRepository(behaviors: [.success([])])
        let viewModel = MainViewModel(repository: repository)

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.currentState == .empty }
    }

    func testFailureThenRetryTransitionsThroughLoadingToContent() async {
        let expected = makeStudy(id: "retry", title: "다시 만난 스터디")
        let repository = TestStudyRepository(behaviors: [
            .failure,
            .delayedSuccess([expected], nanoseconds: 50_000_000, ignoresCancellation: false)
        ])
        let viewModel = MainViewModel(repository: repository)

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.currentState == .failure }

        viewModel.retry()
        XCTAssertEqual(viewModel.currentState, .loading)
        await waitUntil { viewModel.currentState == .content([StudyListItemViewData(study: expected)]) }
    }

    func testCancelledStaleRequestCannotOverwriteRetry() async {
        let stale = makeStudy(id: "stale", title: "오래된 응답")
        let fresh = makeStudy(id: "fresh", title: "최신 응답")
        let repository = TestStudyRepository(behaviors: [
            .delayedSuccess([stale], nanoseconds: 120_000_000, ignoresCancellation: true),
            .success([fresh])
        ])
        let viewModel = MainViewModel(repository: repository)

        viewModel.loadIfNeeded()
        try? await Task.sleep(nanoseconds: 10_000_000)
        viewModel.retry()

        await waitUntil { viewModel.currentState == .content([StudyListItemViewData(study: fresh)]) }
        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(viewModel.currentState, .content([StudyListItemViewData(study: fresh)]))
        XCTAssertNil(viewModel.study(for: "stale"))
    }

    func testDuplicateIdentifiersTransitionToFailureInsteadOfCrashing() async {
        let duplicate = makeStudy(id: "duplicate", title: "중복 스터디")
        let repository = TestStudyRepository(behaviors: [.success([duplicate, duplicate])])
        let viewModel = MainViewModel(repository: repository)

        viewModel.loadIfNeeded()
        await waitUntil { viewModel.currentState == .failure }

        XCTAssertNil(viewModel.study(for: "duplicate"))
    }

    private func makeStudy(id: String, title: String) -> Study {
        Study(
            id: id,
            category: "테스트",
            title: title,
            summary: "테스트 요약",
            currentMembers: 1,
            maximumMembers: 4,
            status: .recruiting,
            topics: ["테스트"]
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let interval: UInt64 = 10_000_000
        var elapsed: UInt64 = 0
        while elapsed < timeoutNanoseconds {
            if condition() { return }
            try? await Task.sleep(nanoseconds: interval)
            elapsed += interval
        }
        XCTFail("Timed out waiting for ViewModel state")
    }
}

private actor TestStudyRepository: RepositoryProtocol {
    enum Behavior: Sendable {
        case success([Study])
        case failure
        case delayedSuccess([Study], nanoseconds: UInt64, ignoresCancellation: Bool)
    }

    private var behaviors: [Behavior]

    init(behaviors: [Behavior]) {
        self.behaviors = behaviors
    }

    func fetchStudies() async throws -> [Study] {
        guard !behaviors.isEmpty else { return [] }
        let behavior = behaviors.removeFirst()

        switch behavior {
        case let .success(studies):
            return studies
        case .failure:
            throw RepositoryError.unavailable
        case let .delayedSuccess(studies, nanoseconds, ignoresCancellation):
            if ignoresCancellation {
                try? await Task.sleep(nanoseconds: nanoseconds)
            } else {
                try await Task.sleep(nanoseconds: nanoseconds)
            }
            return studies
        }
    }
}
