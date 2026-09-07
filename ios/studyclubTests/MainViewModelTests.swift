import Combine
import XCTest
@testable import studyclub

@MainActor
final class MainViewModelTests: XCTestCase {
    func testStatePublisherSynchronouslyReplaysCurrentStateWhenSinkBinds() {
        let repository = TestStudyRepository(behaviors: [])
        let viewModel = MainViewModel(repository: repository)
        var receivedStates: [MainViewModel.LoadState] = []

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

        await waitUntil { viewModel.currentState == .content }

        XCTAssertEqual(viewModel.items, [StudyCardCellViewModel(study: expected)])
        XCTAssertEqual(viewModel.study(for: "selected"), expected)
    }

    func testEmptyResultTransitionsToEmpty() async {
        let repository = TestStudyRepository(behaviors: [.success([])])
        let viewModel = MainViewModel(repository: repository)

        await waitUntil { viewModel.currentState == .empty }
    }

    func testFailureEndsLoadingWithoutRetry() async {
        let repository = TestStudyRepository(behaviors: [.failure])
        let viewModel = MainViewModel(repository: repository)
        await waitUntil { viewModel.currentState == .failure }
        XCTAssertTrue(viewModel.items.isEmpty)
        let requests = await repository.requestCount
        XCTAssertEqual(requests, 1)
    }

    func testLateSubscriberReadsItemsAfterContentWasPublished() async {
        let expected = makeStudy(id: "late", title: "이미 받은 응답")
        let repository = TestStudyRepository(behaviors: [.success([expected])])
        let viewModel = MainViewModel(repository: repository)
        await waitUntil { viewModel.currentState == .content }
        var receivedStates: [MainViewModel.LoadState] = []
        let subscription = viewModel.statePublisher.sink { state in
            receivedStates.append(state)
            XCTAssertEqual(viewModel.items, [StudyCardCellViewModel(study: expected)])
        }
        XCTAssertEqual(receivedStates, [.content])
        let requests = await repository.requestCount
        XCTAssertEqual(requests, 1)
        withExtendedLifetime(subscription) {}
    }

    func testDuplicateIdentifiersTransitionToFailureInsteadOfCrashing() async {
        let duplicate = makeStudy(id: "duplicate", title: "중복 스터디")
        let repository = TestStudyRepository(behaviors: [.success([duplicate, duplicate])])
        let viewModel = MainViewModel(repository: repository)

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
    func fetchStudy(id: Study.ID) async throws -> Study {
        throw RepositoryError.unavailable
    }
    enum Behavior: Sendable {
        case success([Study])
        case failure
    }

    private(set) var requestCount = 0
    private var behaviors: [Behavior]

    init(behaviors: [Behavior]) {
        self.behaviors = behaviors
    }

    func fetchStudies() async throws -> [Study] {
        requestCount += 1
        guard !behaviors.isEmpty else { return [] }
        let behavior = behaviors.removeFirst()

        switch behavior {
        case let .success(studies):
            return studies
        case .failure:
            throw RepositoryError.unavailable

        }
    }
}
