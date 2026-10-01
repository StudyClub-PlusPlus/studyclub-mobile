import XCTest
@testable import studyclub

final class StudyResponseValidationTests: XCTestCase {
    private func study(id: String) -> Study {
        Study(id: id, category: "iOS", title: "Study", summary: "Summary",
              currentMembers: 1, maximumMembers: 4, status: .recruiting, topics: [])
    }

    func testEmptyListIsValid() throws {
        try validateUniqueStudyIDs([])
    }

    func testDifferentIDsAreValid() throws {
        try validateUniqueStudyIDs([study(id: "first"), study(id: "second")])
    }

    func testDuplicateIDsAreRejected() {
        XCTAssertThrowsError(try validateUniqueStudyIDs([study(id: "same"), study(id: "same")])) {
            XCTAssertEqual($0 as? RepositoryError, .invalidData)
        }
    }

    func testRequestedStudyIdentityIsValid() throws {
        try validateStudyID(study(id: "selected"), expectedID: "selected")
    }

    func testDifferentStudyIdentityIsRejected() {
        XCTAssertThrowsError(try validateStudyID(study(id: "other"), expectedID: "selected")) {
            XCTAssertEqual($0 as? RepositoryError, .invalidData)
        }
    }
}
