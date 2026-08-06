import Foundation

struct Study: Identifiable, Hashable, Sendable {
    enum Status: String, Hashable, Sendable {
        case recruiting
        case almostFull

        var displayText: String {
            switch self {
            case .recruiting:
                "모집 중"
            case .almostFull:
                "마감 임박"
            }
        }
    }

    let id: String
    let category: String
    let title: String
    let summary: String
    let currentMembers: Int
    let maximumMembers: Int
    let status: Status
    let topics: [String]
}
