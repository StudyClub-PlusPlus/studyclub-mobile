import Foundation

protocol MyStudiesRepository: Sendable {
    func fetchMyStudies() async throws -> [MyStudy]
}

enum MyStudiesError: Error, Equatable, Sendable {
    case unauthorized
    case onboardingRequired
    case featureUnavailable
    case unavailable
    case invalidData
}
