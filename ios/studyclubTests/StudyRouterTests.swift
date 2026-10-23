import XCTest
@testable import studyclub

final class StudyRouterTests: XCTestCase {
    func testSearchDefaultsToAllPublicStudiesWithoutAuthentication() throws {
        let request = try StudyRouter.searchStudies(
            query: StudySearchQuery(keyword: "한글 & Swift"), offset: 20, limit: 20
        ).asURLRequest()
        let components = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(components.path, "/api/studies")
        XCTAssertEqual(items["keyword"], "한글 & Swift")
        XCTAssertEqual(items["offset"], "20")
        XCTAssertEqual(items["limit"], "20")
        XCTAssertNil(items["status"])
        XCTAssertNil(items["category"])
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testSearchUsesCurrentPhaseAndCategoryContract() throws {
        let request = try StudyRouter.searchStudies(
            query: StudySearchQuery(keyword: "앱", phase: .closed, category: .software), offset: 0, limit: 20
        ).asURLRequest()
        let components = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(items["status"], "CLOSED")
        XCTAssertEqual(items["category"], "SOFTWARE")
    }

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
