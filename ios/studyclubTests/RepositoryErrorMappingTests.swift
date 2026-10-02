import Alamofire
import Foundation
import XCTest
@testable import studyclub

final class RepositoryErrorMappingTests: XCTestCase {
    func testSwiftCancellationIsPreserved() {
        XCTAssertTrue(Repository.mapError(CancellationError()) is CancellationError)
    }

    func testAlamofireCancellationBecomesSwiftCancellation() {
        XCTAssertTrue(Repository.mapError(AFError.explicitlyCancelled) is CancellationError)
    }

    func testRepositoryErrorMeaningIsPreserved() {
        for error in [RepositoryError.invalidData, .unavailable, .detailAPIUnconfigured] {
            XCTAssertEqual(Repository.mapError(error) as? RepositoryError, error)
        }
    }

    func testTransportFailureBecomesUnavailable() {
        let error = AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet))
        XCTAssertEqual(Repository.mapError(error) as? RepositoryError, .unavailable)
    }

    func testUnexpectedErrorBecomesUnavailable() {
        struct UnexpectedError: Error {}
        XCTAssertEqual(Repository.mapError(UnexpectedError()) as? RepositoryError, .unavailable)
    }
}
