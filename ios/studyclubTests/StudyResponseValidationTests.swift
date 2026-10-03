import XCTest
@testable import studyclub

final class StudyResponseValidationTests: XCTestCase {
    private let repository = Repository()

    private func study(id: String) -> Study {
        Study(id: id, category: .software, title: "Study", summary: "Summary",
              participantCount: 1, capacity: 4, phase: .recruiting, closingSoon: false)
    }

    private func detail(id: String) -> StudyDetail {
        StudyDetail(id: id, title: "Study", description: "Description", category: .software,
                    studyKind: .study, thumbnailURL: nil, deliveryFormat: .online,
                    status: .open, recruitStatus: .recruiting, curriculum: "", capacity: 4,
                    recruitDeadlineAt: nil, startAt: nil, endAt: nil)
    }

    func testEmptyListIsValid() throws {
        try repository.validateUniqueStudyIDs([])
    }

    func testDifferentIDsAreValid() throws {
        try repository.validateUniqueStudyIDs([study(id: "first"), study(id: "second")])
    }

    func testDuplicateIDsAreRejected() {
        XCTAssertThrowsError(try repository.validateUniqueStudyIDs([study(id: "same"), study(id: "same")])) {
            XCTAssertEqual($0 as? RepositoryError, .invalidData)
        }
    }

    func testPageAcceptsChangingTotalRatherThanRequiringOneSnapshot() throws {
        try repository.validatePage(
            StudyListResponseDTO(items: [dto], total: 0, offset: 20, limit: 20),
            expectedOffset: 20, expectedLimit: 20
        )
    }

    func testPageRejectsWrongOffsetLimitAndNegativeTotal() {
        for page in [
            StudyListResponseDTO(items: [], total: -1, offset: 0, limit: 20),
            StudyListResponseDTO(items: [], total: 1, offset: 20, limit: 20),
            StudyListResponseDTO(items: [], total: 1, offset: 0, limit: 10),
            StudyListResponseDTO(items: Array(repeating: dto, count: 21), total: 21, offset: 0, limit: 20)
        ] {
            XCTAssertThrowsError(try repository.validatePage(page, expectedOffset: 0, expectedLimit: 20))
        }
    }

    private var dto: StudyDTO {
        StudyDTO(studyId: 1, category: .software, title: "Study", oneLineSummary: "Summary",
                 currentApplicants: 1, capacity: nil, phase: .recruiting, closingSoon: false)
    }

    func testRequestedStudyIdentityIsValid() throws {
        try repository.validateStudyID(detail(id: "selected"), expectedID: "selected")
    }

    func testDifferentStudyIdentityIsRejected() {
        XCTAssertThrowsError(try repository.validateStudyID(detail(id: "other"), expectedID: "selected")) {
            XCTAssertEqual($0 as? RepositoryError, .invalidData)
        }
    }
}
