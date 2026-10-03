import XCTest
@testable import studyclub

final class StudyDetailMapperTests: XCTestCase {
    func testMapsThumbnailAndFractionalDate() throws {
        let detail = try makeDTO(
            thumbnailURL: URL(string: "https://example.com/thumbnail.png"),
            startAt: "2026-10-15T00:00:00.123Z"
        ).toDomain()

        XCTAssertEqual(detail.id, "42")
        XCTAssertEqual(detail.thumbnailURL?.absoluteString, "https://example.com/thumbnail.png")
        XCTAssertEqual(try XCTUnwrap(detail.startAt).timeIntervalSince1970, 1_792_022_400.123, accuracy: 0.001)
    }

    func testMapsClosedStudyWithNullRecruitmentStatus() throws {
        let detail = try makeDTO(category: .algorithm, status: .closed, recruitStatus: nil).toDomain()
        XCTAssertEqual(detail.category, .algorithm)
        XCTAssertEqual(detail.status, .closed)
        XCTAssertNil(detail.recruitStatus)
    }

    func testPreservesBackendLifecycleValues() throws {
        for status in [StudyStatus.draft, .open, .ongoing, .ended, .closed] {
            let detail = try makeDTO(status: status).toDomain()
            XCTAssertEqual(detail.status, status)
        }
    }

    func testMapsBackendDetailContractToDomain() throws {
        let detail = try makeDTO().toDomain()

        XCTAssertEqual(detail.id, "42")
        XCTAssertEqual(detail.category, .software)
        XCTAssertEqual(detail.studyKind, .study)
        XCTAssertEqual(detail.deliveryFormat, .online)
        XCTAssertEqual(detail.recruitStatus, .recruiting)
        XCTAssertEqual(detail.capacity, 20)
        XCTAssertNotNil(detail.startAt)
    }

    func testOptionalContentUsesEmptyDisplayValues() throws {
        let detail = try makeDTO(description: nil, curriculum: nil, capacity: nil).toDomain()

        XCTAssertEqual(detail.description, "")
        XCTAssertEqual(detail.curriculum, "")
        XCTAssertNil(detail.capacity)
    }

    func testRejectsInvalidDate() {
        XCTAssertThrowsError(try makeDTO(startAt: "not-a-date").toDomain()) { error in
            XCTAssertEqual(error as? RepositoryError, .invalidData)
        }
    }

    func testRejectsInvalidIdentityAndCapacity() {
        XCTAssertThrowsError(try makeDTO(id: 0).toDomain())
        XCTAssertThrowsError(try makeDTO(capacity: 0).toDomain())
    }

    private func makeDTO(
        id: Int = 42,
        description: String? = "설명",
        category: StudyCategory = .software,
        thumbnailURL: URL? = nil,
        status: StudyStatus = .open,
        recruitStatus: RecruitStatus? = .recruiting,
        curriculum: String? = "1주차",
        capacity: Int? = 20,
        startAt: String? = "2026-10-15T00:00:00Z"
    ) -> StudyDetailDTO {
        StudyDetailDTO(
            id: id,
            title: "백엔드 스터디",
            description: description,
            category: category,
            studyKind: .study,
            thumbnailURL: thumbnailURL,
            deliveryFormat: .online,
            status: status,
            recruitStatus: recruitStatus,
            curriculum: curriculum,
            capacity: capacity,
            recruitDeadlineAt: "2026-10-01T00:00:00Z",
            startAt: startAt,
            endAt: "2026-12-15T00:00:00Z"
        )
    }
}
