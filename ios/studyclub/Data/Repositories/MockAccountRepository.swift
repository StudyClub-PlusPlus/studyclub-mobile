#if DEBUG
import Foundation

@MainActor
final class MockAccountRepository: AccountRepository {
    private(set) var hasSession = false
    let supportsDemo = true

    func fetchAccount() async throws -> Account {
        guard hasSession else {
            throw AccountError.unauthorized
        }
        return Account(id: 1, email: "member@example.com", nickname: "스터디 메이트", picture: nil)
    }

    func startDemoSession() {
        hasSession = true
    }

    func clearSession() {
        hasSession = false
    }
}
#endif
