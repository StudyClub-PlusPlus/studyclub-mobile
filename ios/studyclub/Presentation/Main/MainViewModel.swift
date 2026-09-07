import Combine
import Foundation

@MainActor
final class MainViewModel {
    enum LoadState: Equatable {
        case loading
        case content
        case empty
        case failure
    }

    private let stateSubject = CurrentValueSubject<LoadState, Never>(.loading)

    var statePublisher: AnyPublisher<LoadState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var currentState: LoadState {
        stateSubject.value
    }

    private let repository: RepositoryProtocol
    private var studiesByID: [Study.ID: Study] = [:]
    private(set) var items: [StudyCardCellViewModel] = []

    convenience init() {
        self.init(repository: RepositoryFactory.makeStudyRepository())
    }

    init(repository: RepositoryProtocol) {
        self.repository = repository
        fetchStudies()
    }

    func study(for id: Study.ID) -> Study? {
        studiesByID[id]
    }

    private func fetchStudies() {
        let repository = repository
        Task { [weak self] in
            do {
                let studies = try await repository.fetchStudies()
                guard let self else { return }
                self.apply(studies)
            } catch {
                guard let self else { return }
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
        items = studies.map(StudyCardCellViewModel.init)
        stateSubject.send(.content)
    }
}
