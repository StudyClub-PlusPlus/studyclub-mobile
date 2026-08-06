import Foundation

enum MainViewState: Equatable {
    case loading
    case content([StudyListItemViewData])
    case empty
    case failure
}

struct StudyListItemViewData: Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let summary: String
    let memberText: String
    let statusText: String

    init(study: Study) {
        id = study.id
        category = study.category
        title = study.title
        summary = study.summary
        memberText = "멤버 \(study.currentMembers)/\(study.maximumMembers)"
        statusText = study.status.displayText
    }
}
