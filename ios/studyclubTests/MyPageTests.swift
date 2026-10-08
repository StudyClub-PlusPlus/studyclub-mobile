import Combine
import XCTest
@testable import studyclub

@MainActor
final class MyPageTests: XCTestCase {
    func testAccountMappingPreservesNullableFields() throws {
        let account = try AccountDTO(id: 42, email: "member@example.com", nickname: nil, picture: nil).toDomain()
        XCTAssertEqual(account.id, 42)
        XCTAssertNil(account.nickname)
        XCTAssertNil(account.picture)
        XCTAssertThrowsError(try AccountDTO(id: 0, email: "", nickname: nil, picture: nil).toDomain())
    }

    func testFlagOffDoesNotFetchOrStartDemo() async {
        let repository = ControlledAccountRepository()
        let model = MyPageViewModel(repository: repository, isEnabled: false)
        model.startDemoSession()
        await Task.yield()
        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(repository.requests, 0)
        XCTAssertEqual(model.currentState, .guest)
    }

    func testGuestDemoAndLogoutClearDisplayAndSession() async {
        let repository = TestAccountRepository()
        let model = MyPageViewModel(repository: repository, isEnabled: true)
        XCTAssertEqual(model.currentState, .guest)
        model.startDemoSession()
        await waitUntil { model.currentState == .content }
        var states: [MyPageViewModel.State] = []
        let binding = model.statePublisher.sink { state in
            states.append(state)
            if state == .content {
                XCTAssertEqual(model.email, "member@example.com")
            }
        }
        model.logout()
        XCTAssertEqual(states, [.content, .guest])
        XCTAssertTrue(model.email.isEmpty)
        XCTAssertTrue(model.nickname.isEmpty)
        XCTAssertFalse(repository.hasSession)
        withExtendedLifetime(binding) {}
    }

    func testExpiredSessionClearsRepositoryAndShowsLoginPrompt() async {
        let repository = TestAccountRepository(error: .unauthorized)
        let model = MyPageViewModel(repository: repository, isEnabled: true)
        await waitUntil { model.currentState == .expired }
        XCTAssertFalse(repository.hasSession)
        XCTAssertTrue(model.email.isEmpty)
    }

    func testFailureDoesNotPretendToBeLoggedOut() async {
        let repository = TestAccountRepository(error: .unavailable)
        let model = MyPageViewModel(repository: repository, isEnabled: true)
        await waitUntil { model.currentState == .failure }
        XCTAssertTrue(repository.hasSession)
    }

    func testLogoutWhileLoadingRejectsLateAccountResponse() async {
        let repository = ControlledAccountRepository()
        let model = MyPageViewModel(repository: repository, isEnabled: true)
        await waitUntil { repository.continuation != nil }
        model.logout()
        repository.continuation?.resume(returning: Account(id: 1, email: "late@example.com", nickname: "Late", picture: nil))
        let unexpectedContent = expectation(description: "A cancelled response must not publish content")
        unexpectedContent.isInverted = true
        let subscription = model.statePublisher.sink { state in
            if state == .content {
                unexpectedContent.fulfill()
            }
        }
        await fulfillment(of: [unexpectedContent], timeout: 0.1)
        withExtendedLifetime(subscription) {}
        XCTAssertEqual(model.currentState, .guest)
        XCTAssertTrue(model.email.isEmpty)
        XCTAssertEqual(repository.requests, 1)
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<100 {
            if condition() {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out")
    }
}

@MainActor
private final class TestAccountRepository: AccountRepository {
    var hasSession: Bool
    let supportsDemo = true
    let error: AccountError?
    init(error: AccountError? = nil) {
        self.error = error
        hasSession = error != nil
    }
    func fetchAccount() async throws -> Account {
        if let error {
            throw error
        }
        return Account(id: 1, email: "member@example.com", nickname: "스터디 메이트", picture: nil)
    }
    func startDemoSession() {
        hasSession = true
    }
    func clearSession() {
        hasSession = false
    }
}

@MainActor
private final class ControlledAccountRepository: AccountRepository {
    var hasSession = true
    let supportsDemo = true
    var requests = 0
    var continuation: CheckedContinuation<Account, Error>?
    func fetchAccount() async throws -> Account {
        requests += 1
        return try await withCheckedThrowingContinuation { requestContinuation in
            continuation = requestContinuation
        }
    }
    func startDemoSession() {
        hasSession = true
    }
    func clearSession() {
        hasSession = false
    }
}
