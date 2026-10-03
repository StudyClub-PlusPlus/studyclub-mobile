import XCTest
@testable import studyclub

final class StudyRouterTests: XCTestCase {
    func testDetailRequestUsesBackendStudyPath() throws {
        let request = try StudyRouter.study(
            baseURL: URL(string: "https://api.stage.studyclub-plusplus.com/api/")!,
            id: "42"
        ).asURLRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://api.stage.studyclub-plusplus.com/api/studies/42")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }
}
