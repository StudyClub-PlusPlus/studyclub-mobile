import Alamofire

final class StudyAPIClient: Sendable {
    func fetchStudies() async throws -> [StudyDTO] {
        try await AF.request(StudyRouter.studies)
            .validate()
            .serializingDecodable([StudyDTO].self)
            .value
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetailDTO {
        try await AF.request(StudyRouter.study(id: id))
            .validate()
            .serializingDecodable(StudyDetailDTO.self)
            .value
    }
}
