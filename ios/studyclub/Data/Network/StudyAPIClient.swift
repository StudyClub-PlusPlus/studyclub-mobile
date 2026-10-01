import Alamofire
import Foundation

final class AlamofireStudyAPIClient: StudyAPIClient {
    private let baseURL: URL
    private let session: Session

    init(baseURL: URL = StudyAPIClient.defaultBaseURL, session: Session = .default) {
        self.baseURL = baseURL
        self.session = session
    }

    private static var defaultBaseURL: URL {
        // The public Production API is the verified mobile endpoint.
        // Stage can still be selected explicitly through init(baseURL:).
        URL(string: "https://api.studyclub-plusplus.com/api/")!
    }

    func fetchStudies() async throws -> [StudyDTO] {
        do {
            return try await session
                .request(StudyRouter.studies(baseURL: baseURL))
                .validate()
                .serializingDecodable([StudyDTO].self)
                .value
        } catch let error as AFError where error.responseCode == 404 {
            throw RepositoryError.notFound
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RepositoryError.unavailable
        }
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetailDTO {
        do {
            return try await session
                .request(StudyRouter.study(baseURL: baseURL, id: id))
                .validate()
                .serializingDecodable(StudyDetailDTO.self)
                .value
        } catch let error as AFError where error.responseCode == 404 {
            throw RepositoryError.notFound
        } catch let error as AFError where error.underlyingError is DecodingError {
            throw RepositoryError.invalidData
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RepositoryError.unavailable
        }
    }
}
