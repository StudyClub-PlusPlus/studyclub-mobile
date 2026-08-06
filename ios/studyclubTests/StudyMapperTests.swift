import XCTest
@testable import studyclub

final class StudyMapperTests: XCTestCase {
    func testDTOMapsToDomainModel() throws {
        let dto = StudyDTO(
            id: "swift",
            category: "iOS",
            title: "Swift Concurrency",
            summary: "동시성 모델을 함께 학습해요.",
            currentMembers: 3,
            maximumMembers: 8,
            status: "recruiting",
            topics: ["Task", "Actor"]
        )

        let study = try dto.toDomain()

        XCTAssertEqual(study.id, "swift")
        XCTAssertEqual(study.status, .recruiting)
        XCTAssertEqual(study.topics, ["Task", "Actor"])
    }

    func testMissingTopicsMapToEmptyCollection() throws {
        let dto = StudyDTO(
            id: "swift",
            category: "iOS",
            title: "Swift",
            summary: "기초부터 함께 학습해요.",
            currentMembers: 1,
            maximumMembers: 4,
            status: "almost_full",
            topics: nil
        )

        XCTAssertEqual(try dto.toDomain().topics, [])
    }

    func testMalformedDTODoesNotCrossRepositoryBoundary() {
        let dto = StudyDTO(
            id: "",
            category: "iOS",
            title: "",
            summary: "",
            currentMembers: -1,
            maximumMembers: 0,
            status: "unknown",
            topics: nil
        )

        XCTAssertThrowsError(try dto.toDomain()) { error in
            XCTAssertEqual(error as? StudyRepositoryError, .invalidData)
        }
    }

    func testMemberCountCannotExceedCapacity() {
        let dto = StudyDTO(
            id: "over-capacity",
            category: "iOS",
            title: "정원 검증",
            summary: "잘못된 정원 데이터",
            currentMembers: 9,
            maximumMembers: 8,
            status: "almost_full",
            topics: nil
        )

        XCTAssertThrowsError(try dto.toDomain()) { error in
            XCTAssertEqual(error as? StudyRepositoryError, .invalidData)
        }
    }
}
