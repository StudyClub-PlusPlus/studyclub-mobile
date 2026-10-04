import Foundation

extension StudyDTO {
    func toDomain() -> Study {
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
