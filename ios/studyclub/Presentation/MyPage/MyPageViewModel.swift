import Combine
import Foundation

@MainActor
final class MyPageViewModel {
    enum State: Equatable {
        case guest
        case loading
        case content
        case failure
        case expired
    }

    private let stateSubject = CurrentValueSubject<State, Never>(.guest)
    var statePublisher: AnyPublisher<State, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var currentState: State {
        stateSubject.value
    }

    let isEnabled: Bool
    var supportsDemo: Bool {
        isEnabled && repository.supportsDemo
    }

    private let repository: any AccountRepository
    private(set) var nickname = ""
    private(set) var email = ""
    private var requestTask: Task<Void, Never>?

    convenience init() {
        self.init(
            repository: RepositoryFactory.makeAccountRepository(),
            isEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.myPage.definition)
        )
    }

    init(repository: any AccountRepository, isEnabled: Bool) {
        self.repository = repository
        self.isEnabled = isEnabled
        if isEnabled && repository.hasSession {
            fetchAccount()
        }
    }

    func startDemoSession() {
        guard supportsDemo, currentState == .guest || currentState == .expired else {
            return
        }
        repository.startDemoSession()
        fetchAccount()
    }

    func logout() {
        guard isEnabled else {
            return
        }
        requestTask?.cancel()
        requestTask = nil
        repository.clearSession()
        nickname = ""
        email = ""
        stateSubject.send(.guest)
    }

    private func fetchAccount() {
        requestTask?.cancel()
        stateSubject.send(.loading)
        let repository = repository
        requestTask = Task { [weak self] in
            do {
                let account = try await repository.fetchAccount()
                guard !Task.isCancelled, let self else {
                    return
                }
                self.requestTask = nil
                if let nickname = account.nickname, !nickname.isEmpty {
                    self.nickname = nickname
                } else {
                    self.nickname = "스터디 회원"
                }
                self.email = account.email
                self.stateSubject.send(.content)
            } catch {
                guard !Task.isCancelled, let self else {
                    return
                }
                self.requestTask = nil
                self.nickname = ""
                self.email = ""
                if error as? AccountError == .unauthorized {
                    repository.clearSession()
                    self.stateSubject.send(.expired)
                } else {
                    self.stateSubject.send(.failure)
                }
            }
        }
    }
}
