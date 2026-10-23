import XCTest
@testable import studyclub

@MainActor
final class MyStudiesListIntegrationTests: XCTestCase {
    func testOffAndGuestMakeNoRequest() async {
        let repository = ControlledMyStudiesRepository()
        let off = MyStudiesListViewModel(repository: repository, isFeatureEnabled: false, member: Member(nickname: "회원"))
        let guest = MyStudiesListViewModel(repository: repository, isFeatureEnabled: true, member: nil)
        off.refresh()
        guest.refresh()
        XCTAssertEqual(off.state, .unavailable)
        XCTAssertEqual(guest.state, .guest)
        let count = await repository.count
        XCTAssertEqual(count, 0)
    }

    func testMemberLoadsOnceThenEmptyRefreshClearsSelection() async {
        let repository = ControlledMyStudiesRepository()
        let model = makeModel(repository)
        await repository.waitForRequests(1)
        await repository.complete(0, .success([study("12")]))
        await waitUntil { model.state == .content }
        XCTAssertEqual(model.selectedStudyID("12"), "12")
        model.refresh()
        await repository.waitForRequests(2)
        await repository.complete(1, .success([]))
        await waitUntil { model.state == .empty }
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNil(model.selectedStudyID("12"))
    }

    func testLogoutClearsImmediatelyAndLateSuccessCannotRestorePrivateContent() async {
        let repository = ControlledMyStudiesRepository()
        let model = makeModel(repository)
        await repository.waitForRequests(1)
        model.updateSession(nil)
        XCTAssertEqual(model.state, .guest)
        await repository.complete(0, .success([study("12")]))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.state, .guest)
        XCTAssertTrue(model.items.isEmpty)
    }

    func testLateCancelledFailureCannotOverwriteNewSessionResult() async {
        let repository = ControlledMyStudiesRepository()
        let model = makeModel(repository)
        await repository.waitForRequests(1)
        model.updateSession(nil)
        model.updateSession(Member(nickname: "다른 회원"))
        await repository.waitForRequests(2)
        await repository.complete(1, .success([study("24")]))
        await waitUntil { model.state == .content }
        await repository.complete(0, .failure(RepositoryError.unauthorized))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.state, .content)
        XCTAssertEqual(model.items.map(\.id), ["24"])
    }

    func testRefreshFailurePreservesContentAndRetryCanReplaceIt() async {
        let repository = ControlledMyStudiesRepository()
        let model = makeModel(repository)
        await repository.waitForRequests(1)
        await repository.complete(0, .success([study("12")]))
        await waitUntil { model.state == .content }
        model.refresh()
        model.refresh()
        await repository.waitForRequests(2)
        let count = await repository.count
        XCTAssertEqual(count, 2)
        await repository.complete(1, .failure(RepositoryError.unavailable))
        await waitUntil { !model.isRefreshing }
        XCTAssertEqual(model.items.map(\.id), ["12"])
        XCTAssertNotNil(model.message)
        model.refresh()
        await repository.waitForRequests(3)
        await repository.complete(2, .success([study("24")]))
        await waitUntil { !model.isRefreshing }
        XCTAssertEqual(model.items.map(\.id), ["24"])
        XCTAssertNil(model.message)
    }

    func testOnboardingRequiredHasSpecificGuestMessageAndRequestsSessionRecheck() async {
        let repository = ControlledMyStudiesRepository()
        let model = makeModel(repository)
        var rechecks = 0
        model.onAuthenticationRequired = { rechecks += 1 }
        await repository.waitForRequests(1)
        await repository.complete(0, .failure(RepositoryError.onboardingRequired))
        await waitUntil { model.state == .guest }
        XCTAssertEqual(rechecks, 1)
        XCTAssertEqual(model.message, "가입 정보를 확인한 뒤 다시 로그인해 주세요.")
        XCTAssertTrue(model.items.isEmpty)
    }

    private func makeModel(_ repository: ControlledMyStudiesRepository) -> MyStudiesListViewModel {
        MyStudiesListViewModel(repository: repository, isFeatureEnabled: true, member: Member(nickname: "회원"))
    }

    private func study(_ id: String) -> MyStudy {
        MyStudy(id: id, title: "스터디 \(id)", category: .software, studyKind: .study,
                startAt: nil, endAt: nil, relation: .ongoing, participantStatus: .active,
                participantRole: .member, discordChannelUrl: nil, driveUrl: nil,
                attendanceRate: nil, meetings: [])
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<500 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Expected state notification", file: file, line: line)
    }
}

private actor ControlledMyStudiesRepository: RepositoryProtocol {
    func searchStudies(query: StudySearchQuery, offset: Int) async throws -> StudyPage {
        throw RepositoryError.unavailable
    }

    private var requests: [CheckedContinuation<[MyStudy], Error>?] = []
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
    var count: Int { requests.count }

    func fetchMyStudies() async throws -> [MyStudy] {
        try await withCheckedThrowingContinuation { continuation in
            requests.append(continuation)
            let ready = waiters.filter { $0.0 <= requests.count }
            waiters.removeAll { $0.0 <= requests.count }
            ready.forEach { $0.1.resume() }
        }
    }

    func fetchStudies(offset: Int) async throws -> StudyPage { throw RepositoryError.unavailable }
    func fetchStudy(id: Study.ID) async throws -> StudyDetail { throw RepositoryError.unavailable }

    func waitForRequests(_ count: Int) async {
        guard requests.count < count else { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    func complete(_ index: Int, _ result: Result<[MyStudy], Error>) {
        let continuation = requests[index]
        requests[index] = nil
        continuation?.resume(with: result)
    }
}
