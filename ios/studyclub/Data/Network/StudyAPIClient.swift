import Alamofire
import Foundation

final class StudyAPIClient: Sendable {
    private let baseURL = URL(string: "https://api.studyclub-plusplus.com/api/")!

    func fetchStudies() async throws -> [StudyDTO] {
        try await Session.default.request(StudyRouter.studies(baseURL: baseURL))
            .validate()
            .serializingDecodable([StudyDTO].self)
            .value
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetailDTO {
        try await Session.default.request(StudyRouter.study(baseURL: baseURL, id: id))
            .validate()
            .serializingDecodable(StudyDetailDTO.self)
            .value
    }
}
