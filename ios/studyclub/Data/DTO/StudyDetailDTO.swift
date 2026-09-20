import Foundation

struct StudyDetailDTO: Decodable, Sendable {
    let id: Int
    let slug: String
    let title: String
    let description: String?
    let category: String
    let studyKind: String
    let thumbnailURL: URL?
    let deliveryFormat: String
    let status: String
    let recruitStatus: String
    let curriculum: String?
    let capacity: Int?
    let recruitDeadlineAt: String?
    let startAt: String?
    let endAt: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, title, description, category, studyKind, deliveryFormat
        case status, recruitStatus, curriculum, capacity, recruitDeadlineAt, startAt, endAt
        case thumbnailURL = "thumbnailUrl"
    }
}
