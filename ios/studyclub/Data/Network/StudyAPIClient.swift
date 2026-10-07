import Alamofire

final class StudyAPIClient: Sendable {
    func fetchStudies(offset: Int, limit: Int) async throws -> StudyListResponseDTO {
        try await AF.request(StudyRouter.studies(offset: offset, limit: limit))
            .validate()
            .serializingDecodable(StudyListResponseDTO.self)
            .value
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetailDTO {
        try await AF.request(StudyRouter.study(id: id))
            .validate()
            .serializingDecodable(StudyDetailDTO.self)
            .value
    }
}
