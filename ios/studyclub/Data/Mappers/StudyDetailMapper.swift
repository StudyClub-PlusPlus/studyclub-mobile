import Foundation

extension StudyDetailDTO {
    func toDomain() throws -> StudyDetail {
        let validCategories = [
            "AI_ML", "CS", "DATA", "BACKEND", "FRONTEND", "MOBILE", "PLANNING",
            "PM", "DESIGN", "CAREER", "LANGUAGE", "LIFESTYLE", "BUSINESS", "OTHER"
        ]
        guard
            id > 0,
            !slug.isEmpty,
            !title.isEmpty,
            capacity.map({ $0 > 0 }) ?? true,
            validCategories.contains(category),
            ["STUDY", "CLUB"].contains(studyKind),
            ["ONLINE", "OFFLINE", "HYBRID"].contains(deliveryFormat),
            ["DRAFT", "OPEN", "CLOSED"].contains(status),
            ["RECRUITING", "RECRUIT_CLOSED"].contains(recruitStatus)
        else {
            throw RepositoryError.invalidData
        }

        return StudyDetail(
            id: String(id),
            slug: slug,
            title: title,
            description: description ?? "",
            category: categoryDisplayText,
            studyKind: studyKindDisplayText,
            thumbnailURL: thumbnailURL,
            deliveryFormat: deliveryFormatDisplayText,
            status: status,
            recruitStatus: recruitStatusDisplayText,
            curriculum: curriculum ?? "",
            capacity: capacity,
            recruitDeadlineAt: try parseDate(recruitDeadlineAt),
            startAt: try parseDate(startAt),
            endAt: try parseDate(endAt)
        )
    }

    private var categoryDisplayText: String {
        switch category {
        case "AI_ML": "AI/ML"
        case "CS": "CS"
        case "DATA": "데이터"
        case "BACKEND": "백엔드"
        case "FRONTEND": "프론트엔드"
        case "MOBILE": "모바일"
        case "PLANNING": "기획"
        case "PM": "PM"
        case "DESIGN": "디자인"
        case "CAREER": "커리어"
        case "LANGUAGE": "외국어"
        case "LIFESTYLE": "라이프스타일"
        case "BUSINESS": "비즈니스"
        case "OTHER": "기타"
        default: category
        }
    }

    private var studyKindDisplayText: String {
        switch studyKind {
        case "STUDY": "스터디"
        case "CLUB": "모임"
        default: studyKind
        }
    }

    private var deliveryFormatDisplayText: String {
        switch deliveryFormat {
        case "ONLINE": "온라인"
        case "OFFLINE": "오프라인"
        case "HYBRID": "온·오프라인"
        default: deliveryFormat
        }
    }

    private var recruitStatusDisplayText: String {
        switch recruitStatus {
        case "RECRUITING": "모집 중"
        case "RECRUIT_CLOSED": "모집 마감"
        default: recruitStatus
        }
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
