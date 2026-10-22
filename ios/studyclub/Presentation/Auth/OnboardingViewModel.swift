import Combine
import Foundation

@MainActor
final class OnboardingViewModel {
    // Foundation accepts this UTC identifier but omits it from its enumerated catalog.
    static let timeZoneIdentifiers = Array(Set(TimeZone.knownTimeZoneIdentifiers + ["Etc/UTC"])).sorted()
    /// Presentation input only. Task 52 maps this value to the auth Domain contract.
    struct Input: Equatable {
        var nickname: String
        var timeZone: String
        var age14Confirmed = false
        var termsOfServiceAgreed = false
        var privacyPolicyAgreed = false
        var marketingAgreed = false

        var hasNickname: Bool {
            !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var hasRequiredConsents: Bool {
            age14Confirmed && termsOfServiceAgreed && privacyPolicyAgreed
        }
    }

    enum State: Equatable {
        case editing
        case submitting
        case unknownStatus
        case checkingStatus
        case cancelling
        case cleanupFailed
        case closed
    }

    private let stateSubject = CurrentValueSubject<State, Never>(.editing)
    var statePublisher: AnyPublisher<State, Never> { stateSubject.eraseToAnyPublisher() }
    var state: State { stateSubject.value }
    private(set) var input: Input
    private(set) var nicknameError: String?
    private(set) var consentError: String?
    private(set) var errorMessage: String?
    private let originalInput: Input

    var isEditing: Bool { state == .editing }
    var isBusy: Bool { state == .submitting || state == .checkingStatus || state == .cancelling }
    var hasChanges: Bool { input != originalInput }
    var requiresStatusCheck: Bool { state == .unknownStatus || state == .checkingStatus }
    /// Closed unless a caller has an explicit confirmation that the displayed terms are current.
    let allowsConsentAndSubmit: Bool
    var canSubmit: Bool {
        isEditing && allowsConsentAndSubmit && input.hasNickname && input.hasRequiredConsents
    }

    init(
        suggestedNickname: String = "스터디친구",
        deviceTimeZone: String = TimeZone.current.identifier,
        allowsConsentAndSubmit: Bool = AuthDocuments().allowsConsentAndSubmit
    ) {
        self.allowsConsentAndSubmit = allowsConsentAndSubmit
        let zone = Self.timeZoneIdentifiers.contains(deviceTimeZone) ? deviceTimeZone : "Etc/UTC"
        let initial = Input(nickname: suggestedNickname, timeZone: zone)
        input = initial
        originalInput = initial
        if !allowsConsentAndSubmit {
            consentError = "확정된 약관이 없어 동의하거나 가입을 제출할 수 없어요."
        }
    }

    func updateNickname(_ nickname: String) {
        guard isEditing else { return }
        input.nickname = nickname
        nicknameError = nil
        errorMessage = nil
        publish()
    }

    func validateNickname() {
        guard isEditing else { return }
        nicknameError = input.hasNickname ? nil : "닉네임을 입력해 주세요."
        publish()
    }

    func selectTimeZone(_ identifier: String) {
        guard isEditing, Self.timeZoneIdentifiers.contains(identifier) else { return }
        input.timeZone = identifier
        publish()
    }

    func updateConsents(age: Bool, terms: Bool, privacy: Bool, marketing: Bool) {
        guard isEditing, allowsConsentAndSubmit else { return }
        input.age14Confirmed = age
        input.termsOfServiceAgreed = terms
        input.privacyPolicyAgreed = privacy
        input.marketingAgreed = marketing
        consentError = nil
        errorMessage = nil
        publish()
    }

    /// Returns local input once; does not send a request or complete signup.
    func submit() -> Input? {
        guard isEditing, allowsConsentAndSubmit else { return nil }
        nicknameError = input.hasNickname ? nil : "닉네임을 입력해 주세요."
        consentError = input.hasRequiredConsents ? nil : "필수 항목을 모두 확인해 주세요."
        errorMessage = nil
        guard canSubmit else { publish(); return nil }
        let submittedInput = input
        stateSubject.send(.submitting)
        guard state == .submitting else { return nil }
        return submittedInput
    }

    func showUnknownStatus(message: String? = nil) {
        guard state == .submitting || state == .checkingStatus else { return }
        errorMessage = message
        stateSubject.send(.unknownStatus)
    }

    func beginStatusCheck() -> Bool {
        guard state == .unknownStatus else { return false }
        errorMessage = nil
        stateSubject.send(.checkingStatus)
        return true
    }

    /// Use only after a definite failure or confirmed incomplete signup.
    func showEditing(message: String? = nil, nicknameError: String? = nil) {
        guard state == .submitting || state == .checkingStatus else { return }
        self.nicknameError = nicknameError
        consentError = nil
        errorMessage = message
        stateSubject.send(.editing)
    }

    /// Keeps the entered input until discard succeeds.
    func beginClose() {
        guard state != .closed, state != .cancelling else { return }
        errorMessage = nil
        stateSubject.send(.cancelling)
    }

    @discardableResult
    func requestCleanupRetry() -> Bool {
        guard state == .cleanupFailed else { return false }
        errorMessage = nil
        stateSubject.send(.cancelling)
        return true
    }

    func failClose() {
        guard state == .cancelling else { return }
        errorMessage = "가입 정리를 끝내지 못했어요. 다시 시도해 주세요."
        stateSubject.send(.cleanupFailed)
    }

    func finishClose() {
        guard state == .cancelling else { return }
        close()
    }

    func close() {
        guard state != .closed else { return }
        input = Input(nickname: "", timeZone: originalInput.timeZone)
        nicknameError = nil
        consentError = nil
        errorMessage = nil
        stateSubject.send(.closed)
    }

    private func publish() { stateSubject.send(state) }
}
