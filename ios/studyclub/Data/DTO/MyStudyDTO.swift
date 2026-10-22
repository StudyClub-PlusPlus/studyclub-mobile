import Foundation

struct MyStudyListResponseDTO: Decodable, Sendable {
    let items: [MyStudyDTO]
}

struct MyStudyDTO: Decodable, Sendable {
    let studyId: Int
    let title: String
    let category: StudyCategory
    let studyKind: StudyKind
    let startAt: String?
    let endAt: String?
    let relation: MyStudyRelation
    let participantStatus: ParticipantStatus
    let participantRole: ParticipantRole
    let discordChannelUrl: String?
    let driveUrl: String?
    let attendanceRate: Double?
    let meetings: [MyStudyMeetingDTO]
}

struct MyStudyMeetingDTO: Decodable, Sendable {
    let meetingId: Int
    let sequence: Int
    let scheduledAt: String
    let startAt: String?
    let endAt: String?
    let attendanceStatus: AttendanceStatus?
    let countedInRate: Bool
}
