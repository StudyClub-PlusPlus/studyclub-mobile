import Foundation

struct StudyListResponseDTO: Decodable, Sendable {
    let items: [StudyDTO]
    let total: Int
    let offset: Int
}

struct StudyDTO: Decodable, Sendable {
    let studyId: Int
    let category: StudyCategory
    let title: String
    let oneLineSummary: String
    let currentApplicants: Int
    let capacity: Int?
    let phase: StudyPhase
    let closingSoon: Bool
}
