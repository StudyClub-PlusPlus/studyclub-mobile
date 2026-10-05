import Alamofire
import Foundation
import XCTest
@testable import studyclub

final class RepositoryErrorMappingTests: XCTestCase {
    private let repository = Repository()

    func testListOFFReturnsFeatureUnavailableRegardlessOfDetailFlag() async {
        for detailEnabled in [false, true] {
            let repository = Repository(isListAPIEnabled: false, isDetailAPIEnabled: detailEnabled)
            // An invalid offset would be invalidData on the enabled request path.
            for offset in [0, -1] {
                do {
                    _ = try await repository.fetchStudies(offset: offset)
                    XCTFail("Disabled list must not return API data")
                } catch {
                    XCTAssertEqual(error as? RepositoryError, .featureUnavailable)
                }
            }
        }
    }

    func testDetailOFFPreservesUnavailableRegardlessOfListFlag() async {
        for listEnabled in [false, true] {
            let repository = Repository(isListAPIEnabled: listEnabled, isDetailAPIEnabled: false)
            do {
                _ = try await repository.fetchStudy(id: "18")
                XCTFail("Disabled detail must not return API data")
            } catch {
                XCTAssertEqual(error as? RepositoryError, .unavailable)
            }
        }
    }

    func testSwiftCancellationIsPreserved() {
        XCTAssertTrue(repository.mapError(CancellationError()) is CancellationError)
    }

    func testAlamofireCancellationBecomesSwiftCancellation() {
        XCTAssertTrue(repository.mapError(AFError.explicitlyCancelled) is CancellationError)
    }

    func testRepositoryErrorMeaningIsPreserved() {
        for error in [RepositoryError.invalidData, .unavailable, .notFound, .featureUnavailable] {
            XCTAssertEqual(repository.mapError(error) as? RepositoryError, error)
        }
    }

    func testHTTPNotFoundBecomesNotFound() {
        let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404))
        XCTAssertEqual(repository.mapError(error) as? RepositoryError, .notFound)
    }

    func testInvalidDetailDecodingBecomesInvalidData() {
        let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid detail"))
        let error = AFError.responseSerializationFailed(reason: .decodingFailed(error: decodingError))
        XCTAssertEqual(repository.mapError(error) as? RepositoryError, .invalidData)
        XCTAssertEqual(repository.mapError(decodingError) as? RepositoryError, .invalidData)
    }

    func testServerFailureBecomesUnavailable() {
        let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 500))
        XCTAssertEqual(repository.mapError(error) as? RepositoryError, .unavailable)
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
