import Foundation

struct StudyCardCellViewModel: Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let summary: String
    let memberText: String
    let statusText: String

    init(study: Study) {
        id = study.id
        category = study.category.displayText
        title = study.title
        summary = study.summary
        if let capacity = study.capacity {
            memberText = "참여 \(study.participantCount)/\(capacity)명"
        } else {
            memberText = "참여 \(study.participantCount)명 · 정원 제한 없음"
        }
        switch study.phase {
        case .recruiting:
            statusText = study.closingSoon ? "모집 중 · 마감 임박" : "모집 중"
        case .ongoing:
            statusText = "진행 중"
        case .closed:
            statusText = "종료"
        }
    }
}
