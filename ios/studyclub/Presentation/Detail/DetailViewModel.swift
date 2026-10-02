import Combine
import Foundation

@MainActor
final class DetailViewModel {
    enum LoadState: Equatable {
        case loading
        case content
        case empty
        case failure
    }

    private(set) var category = ""
    private(set) var title = ""
    private(set) var descriptionText = ""
    private(set) var metadataText = ""
    private(set) var recruitStatusText = ""
    private(set) var curriculum = ""
    private(set) var scheduleText = ""

    private let stateSubject = CurrentValueSubject<LoadState, Never>(.loading)
    var statePublisher: AnyPublisher<LoadState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    var currentState: LoadState { stateSubject.value }

    private let studyID: Study.ID
    private let repository: any RepositoryProtocol

    convenience init(studyID: Study.ID) {
        self.init(studyID: studyID, repository: RepositoryFactory.makeDetailRepository())
    }

    init(studyID: Study.ID, repository: any RepositoryProtocol) {
        self.studyID = studyID
        self.repository = repository
        fetchDetail()
    }

    private func fetchDetail() {
        let repository = repository
        let studyID = studyID
        Task { [weak self] in
            do {
                let study = try await repository.fetchStudy(id: studyID)
                guard let self else { return }
                guard study.id == studyID || study.slug == studyID else {
                    self.stateSubject.send(.empty)
                    return
                }
                self.category = study.category.displayText
                self.title = study.title
                self.descriptionText = study.description
                self.metadataText = Self.metadataText(for: study)
                self.recruitStatusText = study.recruitStatus.displayText
                self.curriculum = study.curriculum
                self.scheduleText = Self.scheduleText(for: study)
                self.stateSubject.send(.content)
            } catch is CancellationError {
                return
            } catch let error as RepositoryError where error == .notFound || error == .invalidData {
                self?.stateSubject.send(.empty)
            } catch {
                self?.stateSubject.send(.failure)
            }
        }
    }

    private static func metadataText(for study: StudyDetail) -> String {
        var values = [study.studyKind.displayText, study.deliveryFormat.displayText]
        if let capacity = study.capacity {
            values.append("정원 \(capacity)명")
        }
        return values.joined(separator: "  ·  ")
    }

    private static func scheduleText(for study: StudyDetail) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy. M. d."

        switch (study.startAt, study.endAt) {
        case let (start?, end?):
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case let (start?, nil):
            return formatter.string(from: start)
        default:
            return ""
        }
    }
}
