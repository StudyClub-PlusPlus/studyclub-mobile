import Foundation

struct AccountDTO: Decodable, Sendable {
    let id: Int64
    let email: String
    let nickname: String?
    let picture: String?
}
