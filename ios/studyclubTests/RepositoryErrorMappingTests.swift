import Alamofire
import Foundation
import XCTest
@testable import studyclub

final class RepositoryErrorMappingTests: XCTestCase {
    private let repository = Repository()

    func testSwiftCancellationIsPreserved() {
        XCTAssertTrue(repository.mapError(CancellationError()) is CancellationError)
    }

    func testAlamofireCancellationBecomesSwiftCancellation() {
        XCTAssertTrue(repository.mapError(AFError.explicitlyCancelled) is CancellationError)
    }

    func testRepositoryErrorMeaningIsPreserved() {
        for error in [RepositoryError.invalidData, .unavailable, .detailAPIUnconfigured] {
            XCTAssertEqual(repository.mapError(error) as? RepositoryError, error)
        }
    }

    func testTransportFailureBecomesUnavailable() {
        let error = AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet))
        XCTAssertEqual(repository.mapError(error) as? RepositoryError, .unavailable)
    }

    func testUnexpectedErrorBecomesUnavailable() {
        struct UnexpectedError: Error {}
        XCTAssertEqual(repository.mapError(UnexpectedError()) as? RepositoryError, .unavailable)
    }
}
