import XCTest
@testable import studyclub

final class MyStudyMapperTests: XCTestCase {
    func testMapsFullDTOToDomain() throws {
        let meetingDTO = MyStudyMeetingDTO(
            meetingId: 301,
            sequence: 1,
            scheduledAt: "2026-09-02T11:00:00Z",
            startAt: "2026-09-02T11:02:00Z",
            endAt: "2026-09-02T12:30:00Z",
            attendanceStatus: .present,
            countedInRate: true
        )
        let studyDTO = MyStudyDTO(
            studyId: 12,
            title: "DDIA 2판 수요일반",
            category: .software,
            studyKind: .study,
            startAt: "2026-09-01T00:00:00Z",
            endAt: "2026-11-10T00:00:00Z",
            relation: .ongoing,
            participantStatus: .active,
            participantRole: .leader,
            discordChannelUrl: "https://discord.com/channels/123",
            driveUrl: "https://drive.google.com/drive/folders/123",
            attendanceRate: 0.83,
            meetings: [meetingDTO]
        )

        let domain = try studyDTO.toDomain()

        XCTAssertEqual(domain.id, "12")
        XCTAssertEqual(domain.title, "DDIA 2판 수요일반")
        XCTAssertEqual(domain.category, .software)
        XCTAssertEqual(domain.studyKind, .study)
        XCTAssertEqual(domain.relation, .ongoing)
        XCTAssertEqual(domain.participantStatus, .active)
        XCTAssertEqual(domain.participantRole, .leader)
        XCTAssertEqual(domain.discordChannelUrl, "https://discord.com/channels/123")
        XCTAssertEqual(domain.driveUrl, "https://drive.google.com/drive/folders/123")
        XCTAssertEqual(domain.attendanceRate, 0.83)
        XCTAssertEqual(domain.meetings.count, 1)
        XCTAssertEqual(domain.meetings[0].id, 301)
        XCTAssertEqual(domain.meetings[0].sequence, 1)
        XCTAssertEqual(domain.meetings[0].attendanceStatus, .present)
        XCTAssertTrue(domain.meetings[0].countedInRate)
        XCTAssertNotNil(domain.startAt)
        XCTAssertNotNil(domain.endAt)
    }

    func testMapsFractionalSecondsDate() throws {
        let dto = makeDTO(startAt: "2026-10-15T09:30:00.123Z")
        let domain = try dto.toDomain()
        let startAt = try XCTUnwrap(domain.startAt)
        XCTAssertEqual(startAt.timeIntervalSince1970, 1_792_056_600.123, accuracy: 0.001)
    }

    func testOptionalFieldsUseNilWhenAbsent() throws {
        let dto = makeDTO(
            startAt: nil,
            endAt: nil,
            discordChannelUrl: nil,
            driveUrl: nil,
            attendanceRate: nil,
            meetings: []
        )
        let domain = try dto.toDomain()

        XCTAssertNil(domain.startAt)
        XCTAssertNil(domain.endAt)
        XCTAssertNil(domain.discordChannelUrl)
        XCTAssertNil(domain.driveUrl)
        XCTAssertNil(domain.attendanceRate)
        XCTAssertTrue(domain.meetings.isEmpty)
    }

    func testPreservesAllRelationCases() throws {
        for relation in MyStudyRelation.allCases {
            let dto = makeDTO(relation: relation)
            let domain = try dto.toDomain()
            XCTAssertEqual(domain.relation, relation)
        }
    }

    func testPreservesAllParticipantRoleAndStatusCases() throws {
        for role in ParticipantRole.allCases {
            let dto = makeDTO(participantRole: role)
            let domain = try dto.toDomain()
            XCTAssertEqual(domain.participantRole, role)
        }
        for status in ParticipantStatus.allCases {
            let dto = makeDTO(participantStatus: status)
            let domain = try dto.toDomain()
            XCTAssertEqual(domain.participantStatus, status)
        }
    }

    func testRejectsInvalidStudyId() {
        XCTAssertThrowsError(try makeDTO(studyId: 0).toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
        XCTAssertThrowsError(try makeDTO(studyId: -1).toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
    }

    func testRejectsEmptyOrWhitespaceTitle() {
        XCTAssertThrowsError(try makeDTO(title: "").toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
        XCTAssertThrowsError(try makeDTO(title: "   \n\t  ").toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
    }

    func testRejectsInvalidAttendanceRate() {
        XCTAssertThrowsError(try makeDTO(attendanceRate: -0.01).toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
        XCTAssertThrowsError(try makeDTO(attendanceRate: 1.01).toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
    }

    func testRejectsInvalidDateFormat() {
        XCTAssertThrowsError(try makeDTO(startAt: "not-a-valid-date").toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
        XCTAssertThrowsError(try makeDTO(endAt: "invalid-end-date").toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
    }

    func testRejectsMalformedCalendarDatesThatFormatterMightNormalize() {
        // February 30th does not exist; calendar round trip must reject it
        XCTAssertThrowsError(try makeDTO(startAt: "2026-02-30T00:00:00Z").toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
        // November 31st does not exist
        XCTAssertThrowsError(try makeDTO(endAt: "2026-11-31T00:00:00Z").toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
    }

    func testRejectsInvalidMeetingIdentityOrSequence() {
        let invalidIdMeeting = MyStudyMeetingDTO(
            meetingId: 0,
            sequence: 1,
            scheduledAt: "2026-09-02T11:00:00Z",
            startAt: nil,
            endAt: nil,
            attendanceStatus: nil,
            countedInRate: false
        )
        XCTAssertThrowsError(try makeDTO(meetings: [invalidIdMeeting]).toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }

        let invalidSeqMeeting = MyStudyMeetingDTO(
            meetingId: 100,
            sequence: 0,
            scheduledAt: "2026-09-02T11:00:00Z",
            startAt: nil,
            endAt: nil,
            attendanceStatus: nil,
            countedInRate: false
        )
        XCTAssertThrowsError(try makeDTO(meetings: [invalidSeqMeeting]).toDomain()) { error in
            XCTAssertEqual(error as? MyStudiesError, .invalidData)
        }
    }

    func testMapsResponseDTOList() throws {
        let emptyResponse = MyStudyListResponseDTO(items: [])
        XCTAssertTrue(try emptyResponse.toDomain().isEmpty)

        let populatedResponse = MyStudyListResponseDTO(items: [
            makeDTO(studyId: 1, title: "첫 번째 스터디"),
            makeDTO(studyId: 2, title: "두 번째 스터디")
        ])
        let mapped = try populatedResponse.toDomain()
        XCTAssertEqual(mapped.count, 2)
        XCTAssertEqual(mapped[0].id, "1")
        XCTAssertEqual(mapped[1].id, "2")
    }

    private func makeDTO(
        studyId: Int = 42,
        title: String = "테스트 스터디",
        category: StudyCategory = .software,
        studyKind: StudyKind = .study,
        startAt: String? = "2026-10-15T00:00:00Z",
        endAt: String? = "2026-12-15T00:00:00Z",
        relation: MyStudyRelation = .ongoing,
        participantStatus: ParticipantStatus = .active,
        participantRole: ParticipantRole = .member,
        discordChannelUrl: String? = "https://discord.gg/example",
        driveUrl: String? = "https://drive.google.com/example",
        attendanceRate: Double? = 0.95,
        meetings: [MyStudyMeetingDTO] = []
    ) -> MyStudyDTO {
        MyStudyDTO(
            studyId: studyId,
            title: title,
            category: category,
            studyKind: studyKind,
            startAt: startAt,
            endAt: endAt,
            relation: relation,
            participantStatus: participantStatus,
            participantRole: participantRole,
            discordChannelUrl: discordChannelUrl,
            driveUrl: driveUrl,
            attendanceRate: attendanceRate,
            meetings: meetings
        )
    }
}
