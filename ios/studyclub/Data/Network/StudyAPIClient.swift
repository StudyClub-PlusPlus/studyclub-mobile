import Alamofire

final class StudyAPIClient: Sendable {
    func searchStudies(query: StudySearchQuery, offset: Int, limit: Int) async throws -> StudyListResponseDTO {
        try Task.checkCancellation()
        return try await AF.request(StudyRouter.searchStudies(query: query, offset: offset, limit: limit))
            .validate()
            .serializingDecodable(StudyListResponseDTO.self)
            .value
    }

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

    func fetchMyStudies(accessToken: String) async throws -> MyStudyListResponseDTO {
        try Task.checkCancellation()
        return try await AF.request(StudyRouter.myStudies(accessToken: accessToken))
            .validate()
            .serializingDecodable(MyStudyListResponseDTO.self)
            .value
    }
}
