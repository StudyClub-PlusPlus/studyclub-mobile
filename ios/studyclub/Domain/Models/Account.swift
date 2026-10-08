import Foundation

struct Account: Equatable, Sendable {
    let id: Int64
    let email: String
    let nickname: String?
    let picture: URL?
}

enum AccountError: Error, Equatable, Sendable {
    case unauthorized
    case unavailable
    case invalidData
}
