import Foundation
import XCTest
@testable import studyclub

/// One-shot suspension point. The code under test suspends in `suspend()`; the test learns it is
/// suspended through `waitUntilEntered()` and releases it with `open()`. No sleeps are involved.
actor Suspension {
    private var entered = false
    private var isOpen = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeWaiters: [CheckedContinuation<Void, Never>] = []

    func suspend() async {
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll()
        guard !isOpen else { return }
        await withCheckedContinuation { resumeWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func open() {
        isOpen = true
        resumeWaiters.forEach { $0.resume() }
        resumeWaiters.removeAll()
    }
}

/// Lock-protected mutable box shared with `@Sendable` closures.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func read<T>(_ body: (Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(value)
    }

    func mutate<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

final class FakeAuthAPI: AuthRemoteAPI, @unchecked Sendable {
    var onSocialLogin: @Sendable (String) async throws -> AuthSessionDTO = { _ in throw AuthRemoteError.server }
    var onRefresh: @Sendable (String) async throws -> String = { _ in throw AuthRemoteError.server }
    var onFetchAccount: @Sendable (String) async throws -> AccountDTO = { _ in throw AuthRemoteError.server }
    var onOnboarding: @Sendable (String, MemberRegistration) async throws -> AccountDTO = { _, _ in
        throw AuthRemoteError.server
    }

    private let calls = Locked<[String]>([])
    var recordedCalls: [String] { calls.read { $0 } }
    func count(of name: String) -> Int { calls.read { $0.filter { $0 == name }.count } }

    func socialLogin(_ authorization: SocialAuthorization) async throws -> AuthSessionDTO {
        calls.mutate { $0.append("socialLogin") }
        return try await onSocialLogin(authorization.code)
    }

    func refresh(refreshToken: String) async throws -> String {
        calls.mutate { $0.append("refresh") }
        return try await onRefresh(refreshToken)
    }

    func fetchAccount(accessToken: String) async throws -> AccountDTO {
        calls.mutate { $0.append("fetchAccount") }
        return try await onFetchAccount(accessToken)
    }

    func completeOnboarding(accessToken: String, registration: MemberRegistration) async throws -> AccountDTO {
        calls.mutate { $0.append("onboarding") }
        return try await onOnboarding(accessToken, registration)
    }
}

final class FakeGoogle: GoogleAuthorizationProviding, @unchecked Sendable {
    var onAuthorize: @Sendable () async throws -> String = { "google-code" }
    private let started = Locked(0)
    var callCount: Int { started.read { $0 } }

    func authorizationCode() async throws -> String {
        started.mutate { $0 += 1 }
        return try await onAuthorize()
    }
}

final class FakeCredentialStore: CredentialStore, @unchecked Sendable {
    private struct State {
        var tokens: AuthTokens?
        var loadError: CredentialStoreError?
        var saveError: CredentialStoreError?
        var deleteError: CredentialStoreError?
        var commitError: CredentialStoreError?
        var discardError: CredentialStoreError?
        var rollbackError: CredentialStoreError?
        var activeWrite: PendingCredentialWrite?
        var previous: AuthTokens?
        var pending: (write: PendingCredentialWrite, tokens: AuthTokens)?
        var saveCount = 0
    }

    private let state: Locked<State>
    var beforeSave: (@Sendable () -> Void)?
    var afterSave: (@Sendable () -> Void)?
    var beforeCommit: (@Sendable () -> Void)?

    init(tokens: AuthTokens? = nil) { state = Locked(State(tokens: tokens)) }

    var tokens: AuthTokens? { state.read { $0.tokens } }
    var saveCount: Int { state.read { $0.saveCount } }
    var hasPendingWrite: Bool { state.read { $0.pending != nil } }
    func failLoad(with error: CredentialStoreError?) { state.mutate { $0.loadError = error } }
    func failSave(with error: CredentialStoreError?) { state.mutate { $0.saveError = error } }
    func failDelete(with error: CredentialStoreError?) { state.mutate { $0.deleteError = error } }
    func failCommit(with error: CredentialStoreError?) { state.mutate { $0.commitError = error } }
    func failDiscard(with error: CredentialStoreError?) { state.mutate { $0.discardError = error } }
    func failRollback(with error: CredentialStoreError?) { state.mutate { $0.rollbackError = error } }

    func load() throws -> AuthTokens? {
        try state.mutate { state in
            if let error = state.loadError { throw error }
            return state.tokens
        }
    }

    @discardableResult
    func save(_ tokens: AuthTokens) throws -> PendingCredentialWrite {
        beforeSave?()
        let write = try state.mutate { state in
            if let error = state.saveError { throw error }
            let write = PendingCredentialWrite(id: UUID())
            state.previous = state.tokens
            state.pending = (write, tokens)
            state.saveCount += 1
            return write
        }
        afterSave?()
        return write
    }

    func commit(_ write: PendingCredentialWrite) throws {
        beforeCommit?()
        try state.mutate { state in
            if let error = state.commitError { throw error }
            guard let pending = state.pending, pending.write == write else { throw CredentialStoreError.corrupted }
            state.tokens = pending.tokens
            state.activeWrite = write
        }
    }

    func rollback(_ write: PendingCredentialWrite) throws {
        try state.mutate { state in
            if state.activeWrite == write {
                if let error = state.rollbackError { throw error }
                state.tokens = state.previous
                state.activeWrite = nil
            }
            if state.discardError == nil, state.pending?.write == write { state.pending = nil }
        }
    }

    func discard(_ write: PendingCredentialWrite) throws {
        try state.mutate { state in
            if let error = state.discardError { throw error }
            if state.pending?.write == write { state.pending = nil }
        }
    }

    func delete() throws {
        try state.mutate { state in
            if let error = state.deleteError { throw error }
            state.tokens = nil
            state.pending = nil
            state.activeWrite = nil
        }
    }
}

enum AuthFixtures {
    static let storedTokens = AuthTokens(accessToken: "stored-access", refreshToken: "stored-refresh")
    static let sessionTokens = AuthTokens(accessToken: "session-access", refreshToken: "session-refresh")
    static let completedAccount = AccountDTO(id: 1, nickname: "수연", onboardingCompletedAt: "2026-10-01T00:00:00Z")
    static let incompleteAccount = AccountDTO(id: 1, nickname: "account_fixture", onboardingCompletedAt: nil)

    static func session(account: AccountDTO, suggested: String? = "구글이름") -> AuthSessionDTO {
        AuthSessionDTO(
            accessToken: sessionTokens.accessToken,
            refreshToken: sessionTokens.refreshToken,
            account: account,
            suggestedNickname: suggested
        )
    }

    static func registration(
        nickname: String = "새닉네임",
        age: Bool = true,
        terms: Bool = true,
        privacy: Bool = true,
        marketing: Bool = false
    ) -> MemberRegistration {
        MemberRegistration(
            nickname: nickname,
            timeZone: "Asia/Seoul",
            age14Confirmed: age,
            termsOfServiceAgreed: terms,
            privacyPolicyAgreed: privacy,
            marketingAgreed: marketing
        )
    }
}

/// Blocks only the first synchronous save, after repository validation and before persistence.
final class CredentialSaveGate: @unchecked Sendable {
    let entered = XCTestExpectation(description: "CredentialStore.save entered")
    private let release = DispatchSemaphore(value: 0)
    private let first = Locked(true)

    func blockFirstSave() {
        guard first.mutate({ value in let wasFirst = value; value = false; return wasFirst }) else { return }
        entered.fulfill()
        if release.wait(timeout: .now() + 10) != .success { XCTFail("Save gate timed out") }
    }

    func open() { release.signal() }
}

/// Faults physical byte operations while running the actual KeychainCredentialStore policy.
final class InMemoryCredentialPersistence: CredentialPersistence, @unchecked Sendable {
    private struct State {
        var data: [String: Data] = [:]
        var failedWrites: Set<String> = []
        var failedDeletes: Set<String> = []
    }
    private let state = Locked(State())
    var beforeWrite: (@Sendable (String) -> Void)?

    func failWrites(to accounts: Set<String>) { state.mutate { $0.failedWrites = accounts } }
    func failDeletes(to accounts: Set<String>) { state.mutate { $0.failedDeletes = accounts } }

    func read(account: String) throws -> Data? { state.read { $0.data[account] } }
    func write(_ data: Data, account: String) throws {
        // Capture failure before the gate so the entered write can finish while later writes fail.
        if state.read({ $0.failedWrites.contains(account) }) { throw CredentialStoreError.failure(status: -1) }
        beforeWrite?(account)
        state.mutate { $0.data[account] = data }
    }
    func delete(account: String) throws {
        try state.mutate { state in
            if state.failedDeletes.contains(account) { throw CredentialStoreError.failure(status: -1) }
            state.data[account] = nil
        }
    }
}

final class ObservedAuthInvalidationClock: AuthInvalidationClock, @unchecked Sendable {
    let onAdvance = Locked<(@Sendable () -> Void)?>(nil)
    let beforeComplete = Locked<(@Sendable () -> Void)?>(nil)
    override func complete(_ epoch: Int, _ publish: () throws -> Void) throws {
        beforeComplete.read { $0 }?()
        try super.complete(epoch, publish)
    }
    override func advance() -> Int {
        let epoch = super.advance()
        onAdvance.read { $0 }?()
        return epoch
    }
}
