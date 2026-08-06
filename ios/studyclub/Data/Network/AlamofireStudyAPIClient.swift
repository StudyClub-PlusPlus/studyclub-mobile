import Alamofire
import Foundation

final class AlamofireStudyAPIClient: StudyAPIClient, @unchecked Sendable {
    private let baseURL: URL
    private let session: Session

    init(baseURL: URL, session: Session = .default) {
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
            throw StudyRepositoryError.unavailable
        }
    }
}
