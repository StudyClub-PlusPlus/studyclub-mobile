import Alamofire
import Foundation
import XCTest
@testable import studyclub

final class RepositoryErrorMappingTests: XCTestCase {
    func testSwiftCancellationIsPreserved() {
        XCTAssertTrue(mapRepositoryError(CancellationError()) is CancellationError)
    }

    func testAlamofireCancellationBecomesSwiftCancellation() {
        XCTAssertTrue(mapRepositoryError(AFError.explicitlyCancelled) is CancellationError)
    }

    func testRepositoryErrorMeaningIsPreserved() {
        for error in [RepositoryError.invalidData, .unavailable, .detailAPIUnconfigured] {
            XCTAssertEqual(mapRepositoryError(error) as? RepositoryError, error)
        }
    }

    func testTransportFailureBecomesUnavailable() {
        let error = AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet))
        XCTAssertEqual(mapRepositoryError(error) as? RepositoryError, .unavailable)
    }

    func testUnexpectedErrorBecomesUnavailable() {
        struct UnexpectedError: Error {}
        XCTAssertEqual(mapRepositoryError(UnexpectedError()) as? RepositoryError, .unavailable)
    }
}
