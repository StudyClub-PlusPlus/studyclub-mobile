import Alamofire
import Foundation

final class AlamofireStudyAPIClient: StudyAPIClient, @unchecked Sendable {
    private let baseURL: URL
    private let session: Session

    // Temporary placeholder: the real API base URL has not been supplied.
    // Replace before live integration. The reserved .invalid domain cannot reach a real service.
    init(baseURL: URL = URL(string: "https://api.example.invalid")!, session: Session = .default) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchStudies() async throws -> [StudyDTO] {
        do {
            return try await session
                .request(StudyRouter.studies(baseURL: baseURL))
                .validate()
                .serializingDecodable([StudyDTO].self)
                .value
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RepositoryError.unavailable
        }
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDTO {
        // The production detail endpoint and response schema are not supplied yet.
        throw RepositoryError.detailAPIUnconfigured
    }
}
