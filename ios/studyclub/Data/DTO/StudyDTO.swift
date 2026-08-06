import Foundation

struct StudyDTO: Decodable, Sendable {
    let id: String
    let category: String
    let title: String
    let summary: String
    let currentMembers: Int
    let maximumMembers: Int
    let status: String
    let topics: [String]?
}
