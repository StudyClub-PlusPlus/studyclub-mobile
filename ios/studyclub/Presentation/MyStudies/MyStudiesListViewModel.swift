import Combine
import Foundation

@MainActor
final class MyStudiesListViewModel {
    enum State: Equatable { case loading, content, empty, failure, guest, unavailable }

    private let stateSubject: CurrentValueSubject<State, Never>
    private(set) var state: State
    private(set) var items: [StudyCardCellViewModel]
    private let repository: (any RepositoryProtocol)?
    private let isFeatureEnabled: Bool
    private var member: Member?
    private var requestTask: Task<Void, Never>?
    private(set) var isRefreshing = false
    private(set) var message: String?
    var statePublisher: AnyPublisher<State, Never> { stateSubject.eraseToAnyPublisher() }
    var onRefresh: (() -> Void)?
    var onAuthenticationRequired: (() -> Void)?
    var onSessionRecheck: (() -> Void)?

    convenience init() {
        self.init(
            repository: RepositoryFactory.makeMemberRepositories().studies,
            isFeatureEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.myStudies.definition),
            member: nil
        )
    }

    /// Scoped Domain injection: a test/member owner supplies confirmed membership, never tokens.
    init(repository: any RepositoryProtocol, isFeatureEnabled: Bool, member: Member?) {
        self.repository = repository
        self.isFeatureEnabled = isFeatureEnabled
        self.member = member
        state = isFeatureEnabled ? (member == nil ? .guest : .loading) : .unavailable
        items = []
        stateSubject = CurrentValueSubject(state)
        if isFeatureEnabled, member != nil { load(keepingContent: false) }
    }

    /// Display-only constructor retained for the independent SC66 View and controlled renders.
    init(state: State, items: [StudyCardCellViewModel] = []) {
        repository = nil
        isFeatureEnabled = state != .unavailable
        member = nil
        self.state = state
        self.items = []
        stateSubject = CurrentValueSubject(state)
        update(state: state, items: items)
    }

    deinit { requestTask?.cancel() }

    func updateSession(_ member: Member?) {
        guard self.member != member || member == nil else { return }
        self.member = member
        requestTask?.cancel()
        requestTask = nil
        isRefreshing = false
        guard isFeatureEnabled else { update(state: .unavailable); return }
        guard member != nil else { update(state: .guest); return }
        message = nil
        load(keepingContent: false)
    }

    /// While membership is unconfirmed, keep no private list or in-flight result.
    func suspend(state: State) {
        requestTask?.cancel()
        requestTask = nil
        member = nil
        isRefreshing = false
        update(state: isFeatureEnabled ? state : .unavailable)
    }

    func update(state: State, items: [StudyCardCellViewModel] = []) {
        self.state = state
        // Repeated IDs keep their first position and latest display value.
        var orderedIDs: [Study.ID] = []
        var values: [Study.ID: StudyCardCellViewModel] = [:]
        if state == .content {
            for item in items {
                if values[item.id] == nil { orderedIDs.append(item.id) }
                values[item.id] = item
            }
        }
        self.items = orderedIDs.compactMap { values[$0] }
        stateSubject.send(state)
    }

    func selectedStudyID(_ id: Study.ID) -> Study.ID? {
        guard state == .content, items.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    func refresh() {
        guard isFeatureEnabled else { return }
        if let onRefresh { onRefresh(); return }
        guard member != nil else { onSessionRecheck?(); return }
        guard !isRefreshing else { return }
        load(keepingContent: true)
    }

    private func load(keepingContent: Bool) {
        guard let repository, isFeatureEnabled, member != nil else { return }
        requestTask?.cancel()
        isRefreshing = keepingContent
        message = nil
        if !keepingContent || items.isEmpty { update(state: .loading) }
        requestTask = Task { [weak self] in
            do {
                let studies = try await repository.fetchMyStudies()
                guard !Task.isCancelled, let self else { return }
                self.requestTask = nil
                self.isRefreshing = false
                self.update(state: studies.isEmpty ? .empty : .content, items: studies.map(Self.card))
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.requestTask = nil
                self.isRefreshing = false
                switch error as? RepositoryError {
                case .unauthorized:
                    self.member = nil
                    self.update(state: .guest)
                    self.onAuthenticationRequired?()
                case .onboardingRequired:
                    self.member = nil
                    self.message = "가입 정보를 확인한 뒤 다시 로그인해 주세요."
                    self.update(state: .guest)
                    self.onAuthenticationRequired?()
                case .featureUnavailable:
                    self.update(state: .unavailable)
                default:
                    if keepingContent, !self.items.isEmpty {
                        self.message = "목록을 새로 불러오지 못했어요. 아래로 당겨 다시 시도해 주세요."
                        self.update(state: .content, items: self.items)
                    } else { self.update(state: .failure) }
                }
            }
        }
    }

    private static func card(_ study: MyStudy) -> StudyCardCellViewModel {
        let relation: String
        switch study.relation {
        case .upcoming: relation = "시작 전"
        case .ongoing: relation = "참여 중"
        case .completed: relation = "완주"
        case .withdrawn: relation = "참여 종료"
        }
        let role: String
        switch study.participantRole {
        case .member: role = "멤버"
        case .leader: role = "리더"
        case .coLeader: role = "공동 리더"
        }
        return .init(id: study.id, category: study.category.displayText, title: study.title,
                     summary: "", memberText: role, statusText: relation)
    }
}
