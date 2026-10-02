import Foundation

struct StudyDetail: Identifiable, Equatable, Sendable {
    let id: Study.ID
    let title: String
    let description: String
    let category: StudyCategory
    let studyKind: StudyKind
    let thumbnailURL: URL?
    let deliveryFormat: DeliveryFormat
    let status: StudyStatus
    let recruitStatus: RecruitStatus
    let curriculum: String
    let capacity: Int?
    let recruitDeadlineAt: Date?
    let startAt: Date?
    let endAt: Date?
}
