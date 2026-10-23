import XCTest
@testable import studyclub

final class StudySearchRepositoryTests: XCTestCase {
    func testSearchOFFRejectsBeforeNetworkIndependentlyOfListFlag() async {
        let repository = Repository(isListAPIEnabled: true, isSearchEnabled: false)
        do {
            _ = try await repository.searchStudies(query: StudySearchQuery(keyword: "Swift"), offset: 0)
            XCTFail("Search OFF must reject the operation")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .featureUnavailable)
        }
    }

    func testBlankSearchRejectsBeforeNetworkEvenWhenSearchIsON() async {
        let repository = Repository(isListAPIEnabled: false, isSearchEnabled: true)
        do {
            _ = try await repository.searchStudies(query: StudySearchQuery(keyword: " \n "), offset: 0)
            XCTFail("Blank input must not fetch all studies")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .invalidData)
        }
    }
}
