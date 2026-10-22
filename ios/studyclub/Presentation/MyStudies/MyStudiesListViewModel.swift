import Combine
import Foundation

/// SC66 owns display data only. SC68 connects authenticated repository operations.
@MainActor
final class MyStudiesListViewModel {
    enum State: Equatable { case loading, content, empty, failure, guest, unavailable }

    private let stateSubject: CurrentValueSubject<State, Never>
    private(set) var state: State
    private(set) var items: [StudyCardCellViewModel]
    var statePublisher: AnyPublisher<State, Never> { stateSubject.eraseToAnyPublisher() }
    var onRefresh: (() -> Void)?

    convenience init() {
        self.init(
            state: DevelopmentSettingsStore().isEnabled(FeatureFlag.myStudies.definition) ? .content : .unavailable,
            items: [
                .init(id: "12", category: "백엔드", title: "DDIA 함께 읽기", summary: "", memberText: "멤버", statusText: "참여 중"),
                .init(id: "24", category: "iOS", title: "Swift로 배우는 앱 개발과 함께 나누는 긴 스터디 제목", summary: "", memberText: "리더", statusText: "시작 전")
            ]
        )
    }

    init(state: State, items: [StudyCardCellViewModel] = []) {
        self.state = state
        self.items = []
        stateSubject = CurrentValueSubject(state)
        update(state: state, items: items)
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

    func refresh() { onRefresh?() }
}
