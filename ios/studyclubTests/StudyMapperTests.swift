import XCTest
@testable import studyclub

final class StudyMapperTests: XCTestCase {
    func testMapsNumericIDAndNullableCapacityWithoutInventingFields() {
        let dto = makeDTO(capacity: nil)
        let study = dto.toDomain()
        XCTAssertEqual(study.id, "42")
        XCTAssertEqual(study.category, .software)
        XCTAssertEqual(study.summary, "요약")
        XCTAssertNil(study.capacity)
        XCTAssertEqual(study.participantCount, 3)
        XCTAssertEqual(StudyCardCellViewModel(study: study).memberText, "참여 3명 · 정원 제한 없음")
    }

    func testCountAboveCapacityRemainsValidAndKnownOtherPhaseIsDisplayed() {
        let study = makeDTO(count: 9, capacity: 8, phase: .ongoing).toDomain()
        XCTAssertEqual(study.participantCount, 9)
        XCTAssertEqual(StudyCardCellViewModel(study: study).statusText, "진행 중")
    }

    func testClosingSoonIsNotDisplayedForClosedPhase() {
        let study = makeDTO(phase: .closed, closingSoon: true).toDomain()
        XCTAssertEqual(StudyCardCellViewModel(study: study).statusText, "종료")
    }

    private func makeDTO(
        id: Int = 42, title: String = "Swift", count: Int = 3, capacity: Int? = 8,
        phase: StudyPhase = .recruiting, closingSoon: Bool = false
    ) -> StudyDTO {
        StudyDTO(studyId: id, category: .software, title: title, oneLineSummary: "요약",
                 currentApplicants: count, capacity: capacity, phase: phase, closingSoon: closingSoon)
    }
}
