import XCTest
@testable import studyclub

final class StudyResponseValidationTests: XCTestCase {
    private let repository = Repository()

    private func study(id: String) -> Study {
        Study(id: id, category: "iOS", title: "Study", summary: "Summary",
              currentMembers: 1, maximumMembers: 4, status: .recruiting, topics: [])
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

    func testRequestedStudyIdentityIsValid() throws {
        try repository.validateStudyID(detail(id: "selected"), expectedID: "selected")
    }

    func testDifferentStudyIdentityIsRejected() {
        XCTAssertThrowsError(try repository.validateStudyID(detail(id: "other"), expectedID: "selected")) {
            XCTAssertEqual($0 as? RepositoryError, .invalidData)
        }
    }
}
