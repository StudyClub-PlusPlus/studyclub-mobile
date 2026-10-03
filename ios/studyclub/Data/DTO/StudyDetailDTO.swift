import Foundation

struct StudyDetailDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let description: String?
    let category: StudyCategory
    let studyKind: StudyKind
    let thumbnailURL: URL?
    let deliveryFormat: DeliveryFormat
    let status: StudyStatus
    let recruitStatus: RecruitStatus?
    let curriculum: String?
    let capacity: Int?
    let recruitDeadlineAt: String?
    let startAt: String?
    let endAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, studyKind, deliveryFormat
        case status, recruitStatus, curriculum, capacity, recruitDeadlineAt, startAt, endAt
        case thumbnailURL = "thumbnailUrl"
    }
}
