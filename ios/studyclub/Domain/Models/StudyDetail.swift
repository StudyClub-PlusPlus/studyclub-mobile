import Foundation

struct StudyDetail: Identifiable, Equatable, Sendable {
    let id: Study.ID
    let slug: String
    let title: String
    let description: String
    let category: String
    let studyKind: String
    let thumbnailURL: URL?
    let deliveryFormat: String
    let status: String
    let recruitStatus: String
    let curriculum: String
    let capacity: Int?
    let recruitDeadlineAt: Date?
    let startAt: Date?
    let endAt: Date?
}
