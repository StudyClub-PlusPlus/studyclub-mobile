import Foundation

struct StudyCardCellViewModel: Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let summary: String
    let memberText: String
    let statusText: String

    init(id: Study.ID, category: String, title: String, summary: String, memberText: String, statusText: String) {
        self.id = id
        self.category = category
        self.title = title
        self.summary = summary
        self.memberText = memberText
        self.statusText = statusText
    }

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
