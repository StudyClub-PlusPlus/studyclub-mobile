import Foundation

enum MyStudyRelation: String, Decodable, CaseIterable, Sendable {
    case upcoming = "UPCOMING"
    case ongoing = "ONGOING"
    case completed = "COMPLETED"
    case withdrawn = "WITHDRAWN"
}

enum ParticipantStatus: String, Decodable, CaseIterable, Sendable {
    case active = "ACTIVE"
    case paused = "PAUSED"
    case withdrawn = "WITHDRAWN"
    case completed = "COMPLETED"
}

enum ParticipantRole: String, Decodable, CaseIterable, Sendable {
    case member = "MEMBER"
    case leader = "LEADER"
    case coLeader = "CO_LEADER"
}

enum AttendanceStatus: String, Decodable, CaseIterable, Sendable {
    case present = "PRESENT"
    case late = "LATE"
    case absent = "ABSENT"
    case excused = "EXCUSED"
}

struct MyStudyMeeting: Identifiable, Hashable, Sendable {
    let id: Int
    let sequence: Int
    let scheduledAt: Date
    let startAt: Date?
    let endAt: Date?
    let attendanceStatus: AttendanceStatus?
    let countedInRate: Bool
}

struct MyStudy: Identifiable, Hashable, Sendable {
    let id: Study.ID
    let title: String
    let category: StudyCategory
    let studyKind: StudyKind
    let startAt: Date?
    let endAt: Date?
    let relation: MyStudyRelation
    let participantStatus: ParticipantStatus
    let participantRole: ParticipantRole
    let discordChannelUrl: String?
    let driveUrl: String?
    let attendanceRate: Double?
    let meetings: [MyStudyMeeting]
}
