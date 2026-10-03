import Foundation

struct Study: Identifiable, Hashable, Sendable {
    let id: String
    let category: StudyCategory
    let title: String
    let summary: String
    let participantCount: Int
    let capacity: Int?
    let phase: StudyPhase
    let closingSoon: Bool
}

struct StudyPage: Sendable {
    let studies: [Study]
    let totalCount: Int
    let offset: Int
}
