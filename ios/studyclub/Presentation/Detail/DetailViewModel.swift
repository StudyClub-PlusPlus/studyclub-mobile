import Combine
import Foundation

@MainActor
final class DetailViewModel {
    enum LoadState: Equatable {
        case loading
        case content
        case failure
    }

    private(set) var category = ""
    private(set) var title = ""
    private(set) var summary = ""
    private(set) var memberText = ""
    private(set) var statusText = ""
    private(set) var topics: [String] = []

    private let stateSubject = CurrentValueSubject<LoadState, Never>(.loading)
    var statePublisher: AnyPublisher<LoadState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    var currentState: LoadState { stateSubject.value }

    private let studyID: Study.ID
    private let repository: any RepositoryProtocol
    private var loadTask: Task<Void, Never>?
    private var requestGeneration = 0
    private var hasStartedInitialLoad = false

    convenience init(studyID: Study.ID) {
        self.init(studyID: studyID, repository: RepositoryFactory.makeStudyRepository())
    }

    init(studyID: Study.ID, repository: any RepositoryProtocol) {
        self.studyID = studyID
        self.repository = repository
    }

    deinit { loadTask?.cancel() }

    func loadIfNeeded() {
        guard !hasStartedInitialLoad else { return }
        hasStartedInitialLoad = true
        startLoad()
    }

    func retry() { startLoad() }

    private func startLoad() {
        requestGeneration += 1
        let generation = requestGeneration
        loadTask?.cancel()
        category = ""
        title = ""
        summary = ""
        memberText = ""
        statusText = ""
        topics = []
        stateSubject.send(.loading)
        let repository = repository
        let studyID = studyID
        loadTask = Task { [weak self] in
            do {
                let study = try await repository.fetchStudy(id: studyID)
                try Task.checkCancellation()
                guard let self, generation == self.requestGeneration else { return }
                guard study.id == studyID else { throw RepositoryError.invalidData }
                self.category = study.category
                self.title = study.title
                self.summary = study.summary
                self.memberText = "멤버 \(study.currentMembers)/\(study.maximumMembers)"
                self.statusText = study.status.displayText
                self.topics = study.topics
                self.stateSubject.send(.content)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      let self, generation == self.requestGeneration else { return }
                self.stateSubject.send(.failure)
            }
        }
    }
}
