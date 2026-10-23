import Combine
import Foundation

/// Presentation-only states. Authentication and result ownership belong to the caller.
@MainActor
final class LoginViewModel {
    enum State: Equatable {
        case idle
        case signingIn
        case cancelling
        case cancelled
        case cleanupFailed
        case failure
        case unavailable
    }

    private let stateSubject: CurrentValueSubject<State, Never>
    let isMock: Bool
    var introduction: String {
        isMock ? "Mock 로그인 테스트예요. 실제 Google 계정이나 서버를 사용하지 않아요." : "Google 계정으로 스터디클럽에 로그인하세요."
    }

    var state: State { stateSubject.value }
    var statePublisher: AnyPublisher<State, Never> { stateSubject.eraseToAnyPublisher() }
    var canSignIn: Bool {
        switch state {
        case .idle, .cancelled, .failure: true
        case .signingIn, .cancelling, .cleanupFailed, .unavailable: false
        }
    }
    var statusMessage: String? {
        switch state {
        case .idle: nil
        case .signingIn: "로그인 중이에요…"
        case .cancelling: "로그인을 정리하는 중이에요."
        case .cancelled: "로그인을 취소했어요. 다시 시작할 수 있어요."
        case .cleanupFailed: "로그인 정리를 끝내지 못했어요. 다시 시도해 주세요."
        case .failure: "로그인하지 못했어요. 다시 시도해 주세요."
        case .unavailable: "지금은 Google 로그인을 이용할 수 없어요. 잠시 후 다시 시도해 주세요."
        }
    }

    init(state: State = .idle, isMock: Bool = false) {
        self.isMock = isMock
        stateSubject = CurrentValueSubject(state)
    }

    /// Task 52 maps authentication results into these display states.
    func update(state: State) {
        stateSubject.send(state)
    }

    @discardableResult
    func requestSignIn() -> Bool {
        guard canSignIn else { return false }
        update(state: .signingIn)
        return true
    }

    @discardableResult
    func requestCancellation() -> Bool {
        guard state == .signingIn else { return false }
        update(state: .cancelling)
        return true
    }

    /// Repeats credential cleanup. It does not start Google sign-in.
    @discardableResult
    func requestCleanupRetry() -> Bool {
        guard state == .cleanupFailed else { return false }
        update(state: .cancelling)
        return true
    }
}
