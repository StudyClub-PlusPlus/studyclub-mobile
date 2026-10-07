import XCTest
@testable import studyclub

final class StudyResponseValidationTests: XCTestCase {
    private let repository = Repository()

    private func detail(id: String) -> StudyDetail {
        StudyDetail(id: id, title: "Study", description: "Description", category: .software,
                    studyKind: .study, thumbnailURL: nil, deliveryFormat: .online,
                    status: .open, recruitStatus: .recruiting, curriculum: "", capacity: 4,
                    recruitDeadlineAt: nil, startAt: nil, endAt: nil)
    }

    func testPageAcceptsChangingTotalAndServerPageSize() throws {
        try repository.validatePage(
            StudyListResponseDTO(items: Array(repeating: dto, count: 21), total: 0, offset: 20),
            expectedOffset: 20
        )
    }

    func testPageRejectsDifferentRequestedOffset() {
        let page = StudyListResponseDTO(items: [], total: 1, offset: 0)
        XCTAssertThrowsError(try repository.validatePage(page, expectedOffset: 20)) {
            XCTAssertEqual($0 as? RepositoryError, .invalidData)
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
