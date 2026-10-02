import XCTest
@testable import studyclub

final class StudyDetailMapperTests: XCTestCase {
    func testDecodesBackendDetailResponse() throws {
        let json = """
        {
          "id": 42,
          "slug": "backend-study",
          "title": "백엔드 스터디",
          "description": "설명",
          "category": "SOFTWARE",
          "studyKind": "STUDY",
          "thumbnailUrl": "https://example.com/thumbnail.png",
          "deliveryFormat": "ONLINE",
          "status": "OPEN",
          "recruitStatus": "RECRUITING",
          "curriculum": "1주차",
          "capacity": 20,
          "recruitDeadlineAt": "2026-10-01T00:00:00Z",
          "startAt": "2026-10-15T00:00:00.123Z",
          "endAt": "2026-12-15T00:00:00Z"
        }
        """

        let detail = try JSONDecoder().decode(StudyDetailDTO.self, from: Data(json.utf8)).toDomain()

        XCTAssertEqual(detail.id, "42")
        XCTAssertEqual(detail.thumbnailURL?.absoluteString, "https://example.com/thumbnail.png")
        XCTAssertNotNil(detail.startAt)
    }

    func testRejectsUnknownDetailCodeValuesDuringDecoding() throws {
        let values: [String: Any] = [
            "id": 42, "slug": "study", "title": "스터디",
            "category": "SOFTWARE", "studyKind": "STUDY",
            "deliveryFormat": "ONLINE", "status": "OPEN", "recruitStatus": "RECRUITING"
        ]
        for field in ["category", "studyKind", "deliveryFormat", "status", "recruitStatus"] {
            var invalid = values
            invalid[field] = "UNKNOWN"
            let data = try JSONSerialization.data(withJSONObject: invalid)
            XCTAssertThrowsError(try JSONDecoder().decode(StudyDetailDTO.self, from: data)) { error in
                XCTAssertTrue(error is DecodingError)
            }
        }
    }

    func testDecodesDetailWithoutSlug() throws {
        let values: [String: Any] = [
            "id": 42, "title": "스터디", "category": "SOFTWARE", "studyKind": "STUDY",
            "deliveryFormat": "ONLINE", "status": "OPEN", "recruitStatus": "RECRUITING"
        ]
        let data = try JSONSerialization.data(withJSONObject: values)
        let detail = try JSONDecoder().decode(StudyDetailDTO.self, from: data).toDomain()
        XCTAssertEqual(detail.id, "42")
    }

    func testDecodesClosedStudyWithNullRecruitmentStatus() throws {
        let values: [String: Any] = [
            "id": 87, "title": "알고리즘 목 인터뷰", "category": "ALGORITHM",
            "studyKind": "STUDY", "deliveryFormat": "ONLINE", "status": "CLOSED",
            "recruitStatus": NSNull()
        ]
        let data = try JSONSerialization.data(withJSONObject: values)
        let detail = try JSONDecoder().decode(StudyDetailDTO.self, from: data).toDomain()
        XCTAssertEqual(detail.category, .algorithm)
        XCTAssertEqual(detail.status, .closed)
        XCTAssertNil(detail.recruitStatus)
    }

    func testDecodesCurrentBackendLifecycleValues() throws {
        for status in ["DRAFT", "OPEN", "ONGOING", "ENDED", "CLOSED"] {
            let values: [String: Any] = [
                "id": 18, "title": "스터디", "category": "SOFTWARE", "studyKind": "STUDY",
                "deliveryFormat": "HYBRID", "status": status, "recruitStatus": NSNull()
            ]
            let data = try JSONSerialization.data(withJSONObject: values)
            let detail = try JSONDecoder().decode(StudyDetailDTO.self, from: data).toDomain()
            XCTAssertEqual(detail.status.rawValue, status)
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
        curriculum: String? = "1주차",
        capacity: Int? = 20,
        startAt: String? = "2026-10-15T00:00:00Z"
    ) -> StudyDetailDTO {
        StudyDetailDTO(
            id: id,
            title: "백엔드 스터디",
            description: description,
            category: .software,
            studyKind: .study,
            thumbnailURL: nil,
            deliveryFormat: .online,
            status: .open,
            recruitStatus: .recruiting,
            curriculum: curriculum,
            capacity: capacity,
            recruitDeadlineAt: "2026-10-01T00:00:00Z",
            startAt: startAt,
            endAt: "2026-12-15T00:00:00Z"
        )
    }
}
