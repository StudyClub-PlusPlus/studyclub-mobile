import Combine
import Foundation

@MainActor
final class MainViewModel {
    private let stateSubject = CurrentValueSubject<MainViewState, Never>(.loading)

    var statePublisher: AnyPublisher<MainViewState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var currentState: MainViewState {
        stateSubject.value
    }

    private let repository: RepositoryProtocol
    private var studiesByID: [Study.ID: Study] = [:]
    private var loadTask: Task<Void, Never>?
    private var requestGeneration = 0
    private var hasStartedInitialLoad = false

    convenience init() {
        self.init(repository: RepositoryFactory.makeStudyRepository())
    }

    init(repository: RepositoryProtocol) {
        self.repository = repository
    }

    deinit {
        loadTask?.cancel()
    }

    func loadIfNeeded() {
        guard !hasStartedInitialLoad else { return }
        hasStartedInitialLoad = true
        startLoad()
    }

    func retry() {
        startLoad()
    }

    func study(for id: Study.ID) -> Study? {
        studiesByID[id]
    }

    private func startLoad() {
        requestGeneration += 1
        let generation = requestGeneration
        loadTask?.cancel()
        stateSubject.send(.loading)

        let repository = repository
        loadTask = Task { [weak self] in
            do {
                let studies = try await repository.fetchStudies()
                try Task.checkCancellation()
                guard let self, generation == self.requestGeneration else { return }
                self.apply(studies)
            } catch is CancellationError {
                return
            } catch {
                guard let self, generation == self.requestGeneration else { return }
                self.studiesByID = [:]
                self.stateSubject.send(.failure)
            }
        }
    }

    private func apply(_ studies: [Study]) {
        guard Set(studies.map(\.id)).count == studies.count else {
            studiesByID = [:]
            stateSubject.send(.failure)
            return
        }

        studiesByID = Dictionary(uniqueKeysWithValues: studies.map { ($0.id, $0) })
        guard !studies.isEmpty else {
            stateSubject.send(.empty)
            return
        }
        stateSubject.send(.content(studies.map(StudyListItemViewData.init)))
    }
}
