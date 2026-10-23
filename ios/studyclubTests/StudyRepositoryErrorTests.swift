import Alamofire
import Foundation
import XCTest
@testable import studyclub

final class StudyRepositoryErrorTests: XCTestCase {
    private let repository = Repository()

    func testCancellationIsPreserved() {
        XCTAssertTrue(repository.mapError(CancellationError()) is CancellationError)
        XCTAssertTrue(repository.mapError(AFError.explicitlyCancelled) is CancellationError)
        XCTAssertTrue(repository.mapError(AFError.sessionTaskFailed(error: URLError(.cancelled))) is CancellationError)
    }

    func testPrivateListAuthorizationStatusesHaveDomainErrors() {
        XCTAssertEqual(repository.mapError(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))) as? RepositoryError, .unauthorized)
        XCTAssertEqual(repository.mapError(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 403))) as? RepositoryError, .onboardingRequired)
    }

    func testHTTP404AndDecodingErrorsKeepSharedRepositoryMapping() {
        XCTAssertEqual(repository.mapError(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404))) as? RepositoryError, .notFound)
        let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid JSON structure"))
        XCTAssertEqual(repository.mapError(decodingError) as? RepositoryError, .invalidData)
    }

    func testServerAndTransportFailuresMapToUnavailable() {
        XCTAssertEqual(repository.mapError(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 500))) as? RepositoryError, .unavailable)
        XCTAssertEqual(repository.mapError(AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet))) as? RepositoryError, .unavailable)
    }
}
