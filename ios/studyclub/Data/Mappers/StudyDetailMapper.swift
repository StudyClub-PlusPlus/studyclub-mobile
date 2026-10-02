import Foundation

extension StudyDetailDTO {
    func toDomain() throws -> StudyDetail {
        guard
            id > 0,
            !slug.isEmpty,
            !title.isEmpty,
            capacity.map({ $0 > 0 }) ?? true
        else {
            throw RepositoryError.invalidData
        }

        return StudyDetail(
            id: String(id),
            slug: slug,
            title: title,
            description: description ?? "",
            category: category,
            studyKind: studyKind,
            thumbnailURL: thumbnailURL,
            deliveryFormat: deliveryFormat,
            status: status,
            recruitStatus: recruitStatus,
            curriculum: curriculum ?? "",
            capacity: capacity,
            recruitDeadlineAt: try parseDate(recruitDeadlineAt),
            startAt: try parseDate(startAt),
            endAt: try parseDate(endAt)
        )
    }

    private func parseDate(_ value: String?) throws -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions.insert(.withFractionalSeconds)
        guard let date = formatter.date(from: value) else {
            throw RepositoryError.invalidData
        }
        return date
    }
}
