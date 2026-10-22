import Foundation

extension MyStudyListResponseDTO {
    func toDomain() throws -> [MyStudy] {
        try items.map { try $0.toDomain() }
    }
}

extension MyStudyDTO {
    func toDomain() throws -> MyStudy {
        guard studyId > 0 else {
            throw RepositoryError.invalidData
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw RepositoryError.invalidData
        }
        if let rate = attendanceRate {
            guard rate >= 0.0, rate <= 1.0 else {
                throw RepositoryError.invalidData
            }
        }

        let parsedStartAt = try MyStudyDateParser.parse(startAt)
        let parsedEndAt = try MyStudyDateParser.parse(endAt)
        let domainMeetings = try meetings.map { try $0.toDomain() }

        return MyStudy(
            id: String(studyId),
            title: trimmedTitle,
            category: category,
            studyKind: studyKind,
            startAt: parsedStartAt,
            endAt: parsedEndAt,
            relation: relation,
            participantStatus: participantStatus,
            participantRole: participantRole,
            discordChannelUrl: discordChannelUrl,
            driveUrl: driveUrl,
            attendanceRate: attendanceRate,
            meetings: domainMeetings
        )
    }
}

extension MyStudyMeetingDTO {
    func toDomain() throws -> MyStudyMeeting {
        guard meetingId > 0, sequence >= 1 else {
            throw RepositoryError.invalidData
        }
        guard let scheduledDate = try MyStudyDateParser.parse(scheduledAt) else {
            throw RepositoryError.invalidData
        }
        let parsedStartAt = try MyStudyDateParser.parse(startAt)
        let parsedEndAt = try MyStudyDateParser.parse(endAt)

        return MyStudyMeeting(
            id: meetingId,
            sequence: sequence,
            scheduledAt: scheduledDate,
            startAt: parsedStartAt,
            endAt: parsedEndAt,
            attendanceStatus: attendanceStatus,
            countedInRate: countedInRate
        )
    }
}

enum MyStudyDateParser {
    private static let pattern = #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,9})?Z\z"#

    static func parse(_ value: String?) throws -> Date? {
        guard let value else { return nil }
        guard value.range(of: pattern, options: .regularExpression) != nil else {
            throw RepositoryError.invalidData
        }
        let seconds = String(value.prefix(19)) + "Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let baseDate = formatter.date(from: seconds), formatter.string(from: baseDate) == seconds else {
            throw RepositoryError.invalidData
        }
        if let dotIndex = value.firstIndex(of: ".") {
            let zIndex = value.index(before: value.endIndex)
            let fractionString = String(value[value.index(after: dotIndex)..<zIndex])
            if let fractionValue = Double("0." + fractionString) {
                return baseDate.addingTimeInterval(fractionValue)
            }
        }
        return baseDate
    }
}
