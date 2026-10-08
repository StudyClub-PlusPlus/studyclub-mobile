import Foundation

@MainActor
protocol AccountRepository: AnyObject {
    var hasSession: Bool { get }
    var supportsDemo: Bool { get }
    func fetchAccount() async throws -> Account
    func startDemoSession()
    func clearSession()
}
