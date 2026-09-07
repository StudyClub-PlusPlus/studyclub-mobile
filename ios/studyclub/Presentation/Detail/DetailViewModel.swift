import Foundation

@MainActor
final class DetailViewModel {
    let category: String
    let title: String
    let summary: String
    let memberText: String
    let statusText: String
    let topics: [String]
    init(study: Study) {
        category = study.category
        title = study.title
        summary = study.summary
        memberText = "멤버 \(study.currentMembers)/\(study.maximumMembers)"
        statusText = study.status.displayText
        topics = study.topics
    }
}
