#if DEBUG
import Foundation

/// Trusted Domain samples only. The owning ViewModel still requires an authenticated session.
struct MockMyStudiesRepository: MyStudiesRepository {
    func fetchMyStudies() async throws -> [MyStudy] {
        [
            MyStudy(id: "12", title: "DDIA 함께 읽기", category: .software, studyKind: .study,
                    startAt: nil, endAt: nil, relation: .ongoing, participantStatus: .active,
                    participantRole: .member, discordChannelUrl: nil, driveUrl: nil,
                    attendanceRate: nil, meetings: []),
            MyStudy(id: "24", title: "Swift로 배우는 앱 개발과 함께 나누는 긴 스터디 제목", category: .software, studyKind: .study,
                    startAt: nil, endAt: nil, relation: .upcoming, participantStatus: .active,
                    participantRole: .leader, discordChannelUrl: nil, driveUrl: nil,
                    attendanceRate: nil, meetings: [])
        ]
    }
}
#endif
