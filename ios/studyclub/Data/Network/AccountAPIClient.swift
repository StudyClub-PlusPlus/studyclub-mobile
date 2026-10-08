import Alamofire
import Foundation

struct AccountAPIClient: Sendable {
    func fetchAccount(accessToken: String) async throws -> AccountDTO {
        try await AF.request(
            "https://api.studyclub-plusplus.com/auth/me",
            headers: [.authorization(bearerToken: accessToken)]
        )
        .validate()
        .serializingDecodable(AccountDTO.self)
        .value
    }
}
