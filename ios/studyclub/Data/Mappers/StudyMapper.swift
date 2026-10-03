import Foundation

extension StudyDTO {
    func toDomain() throws -> Study {
        guard
            studyId > 0,
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            currentApplicants >= 0,
            capacity.map({ $0 > 0 }) ?? true
        else {
            throw RepositoryError.invalidData
        }

        return Study(
            id: String(studyId),
            category: category,
            title: title,
            summary: oneLineSummary,
            participantCount: currentApplicants,
            capacity: capacity,
            phase: phase,
            closingSoon: closingSoon
        )
    }
}
