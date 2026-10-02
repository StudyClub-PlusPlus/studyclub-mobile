import XCTest
@testable import studyclub

final class StudyResponseValidationTests: XCTestCase {
    private func study(id: String) -> Study {
        Study(id: id, category: "iOS", title: "Study", summary: "Summary",
              currentMembers: 1, maximumMembers: 4, status: .recruiting, topics: [])
    }

    func testEmptyListIsValid() throws {
        try Repository.validateUniqueStudyIDs([])
    }

    func testDifferentIDsAreValid() throws {
        try Repository.validateUniqueStudyIDs([study(id: "first"), study(id: "second")])
    }

    func testDuplicateIDsAreRejected() {
        XCTAssertThrowsError(try Repository.validateUniqueStudyIDs([study(id: "same"), study(id: "same")])) {
            XCTAssertEqual($0 as? RepositoryError, .invalidData)
        }
    }

    func testRequestedStudyIdentityIsValid() throws {
        try Repository.validateStudyID(study(id: "selected"), expectedID: "selected")
    }

    func testDifferentStudyIdentityIsRejected() {
        XCTAssertThrowsError(try Repository.validateStudyID(study(id: "other"), expectedID: "selected")) {
            XCTAssertEqual($0 as? RepositoryError, .invalidData)
        }
    }
}
