import Foundation

func validateUniqueStudyIDs(_ studies: [Study]) throws {
    guard Set(studies.map(\.id)).count == studies.count else {
        throw RepositoryError.invalidData
    }
}

func validateStudyID(_ study: Study, expectedID: Study.ID) throws {
    guard study.id == expectedID else {
        throw RepositoryError.invalidData
    }
}
