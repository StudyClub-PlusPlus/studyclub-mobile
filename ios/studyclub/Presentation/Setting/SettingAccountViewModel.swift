import Combine

/// Display fixtures only. Task 52 supplies confirmed session results later.
@MainActor
final class SettingAccountViewModel {
    enum State: Equatable {
        case hidden, guest, checking, connectionFailure
        case member(nickname: String)
        case logoutFailure(nickname: String)
    }

    enum Action: Equatable { case login, recheck, logout }

    private let stateSubject: CurrentValueSubject<State, Never>
    private(set) var state: State
    private(set) var isFeatureEnabled: Bool
    var statePublisher: AnyPublisher<State, Never> { stateSubject.eraseToAnyPublisher() }

    var nickname: String? {
        switch state {
        case let .member(nickname), let .logoutFailure(nickname): return nickname
        default: return nil
        }
    }

    convenience init() {
        self.init(isFeatureEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition))
    }

    init(isFeatureEnabled: Bool, displayState: State = .guest) {
        self.isFeatureEnabled = isFeatureEnabled
        state = isFeatureEnabled ? displayState : .hidden
        stateSubject = CurrentValueSubject(state)
    }

    func updateFeatureVisibility(isEnabled: Bool) {
        isFeatureEnabled = isEnabled
        if !isEnabled { publish(.hidden) }
        else if state == .hidden { publish(.guest) }
    }

    func updateDisplayState(_ state: State) {
        guard isFeatureEnabled else { return }
        publish(state)
    }

    func allows(_ action: Action) -> Bool {
        guard isFeatureEnabled else { return false }
        switch (state, action) {
        case (.guest, .login), (.connectionFailure, .recheck),
             (.member, .logout), (.logoutFailure, .logout): return true
        default: return false
        }
    }

    private func publish(_ state: State) {
        self.state = state
        stateSubject.send(state)
    }
}
