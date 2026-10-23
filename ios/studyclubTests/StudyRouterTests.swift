import XCTest
@testable import studyclub

final class StudyRouterTests: XCTestCase {
    func testDetailRequestUsesBackendStudyPath() throws {
        let request = try StudyRouter.study(id: "42").asURLRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://api.studyclub-plusplus.com/api/studies/42")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testMemberListUsesSharedAPIBaseAndBearerAuthorization() throws {
        let request = try StudyRouter.myStudies(accessToken: " test-token \n").asURLRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://api.studyclub-plusplus.com/api/me/studies")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
    }

    func testMemberListRejectsMissingBearerToken() {
        XCTAssertThrowsError(try StudyRouter.myStudies(accessToken: " \n\t ").asURLRequest()) { error in
            XCTAssertEqual(error as? RepositoryError, .unauthorized)
        }
    }
}
