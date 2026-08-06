import Foundation

extension StudyDTO {
    func toDomain() throws -> Study {
        guard
            !id.isEmpty,
            !title.isEmpty,
            currentMembers >= 0,
            maximumMembers > 0,
            currentMembers <= maximumMembers
        else {
            throw StudyRepositoryError.invalidData
        }

        let domainStatus: Study.Status
        switch status {
        case "recruiting":
            domainStatus = .recruiting
        case "almost_full":
            domainStatus = .almostFull
        default:
            throw StudyRepositoryError.invalidData
        }

        return Study(
            id: id,
            category: category,
            title: title,
            summary: summary,
            currentMembers: currentMembers,
            maximumMembers: maximumMembers,
            status: domainStatus,
            topics: topics ?? []
        )
    }
}
