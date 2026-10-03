import XCTest
@testable import studyclub

final class LiveStudyListTests: XCTestCase {
    func testPublicListPageDecodesAndSelectedIDOpensIndependentDetail() async throws {
        guard ProcessInfo.processInfo.environment["STUDYCLUB_LIVE_API_BASE_URL"]
            == "https://api.studyclub-plusplus.com/api/" else {
            throw XCTSkip("Read-only Production integration is opt-in")
        }
        let repository = Repository()
        let page = try await repository.fetchStudies(offset: 0)
        XCTAssertEqual(page.offset, 0)
        XCTAssertLessThanOrEqual(page.studies.count, 20)
        XCTAssertEqual(Set(page.studies.map(\.id)).count, page.studies.count)
        guard let selected = page.studies.dropFirst().first ?? page.studies.first else {
            throw XCTSkip("No recruiting studies available for list-to-detail integration")
        }
        let detail = try await repository.fetchStudy(id: selected.id)
        XCTAssertEqual(detail.id, selected.id)
        XCTAssertEqual(detail.title, selected.title)
    }
}
