import Alamofire
import Foundation
import XCTest
@testable import studyclub

final class MyStudiesErrorTests: XCTestCase {
    private let client = MyStudiesAPIClient()

    func testCancellationIsPreserved() {
        XCTAssertTrue(client.mapError(CancellationError()) is CancellationError)
    }

    func testAlamofireCancellationBecomesSwiftCancellation() {
        XCTAssertTrue(client.mapError(AFError.explicitlyCancelled) is CancellationError)
    }

    func testUnderlyingURLSessionCancellationBecomesSwiftCancellation() {
        let error = AFError.sessionTaskFailed(error: URLError(.cancelled))
        XCTAssertTrue(client.mapError(error) is CancellationError)
    }

    func testDirectURLSessionCancellationBecomesSwiftCancellation() {
        let error = URLError(.cancelled)
        XCTAssertTrue(client.mapError(error) is CancellationError)
    }

    func testHTTP401BecomesUnauthorized() {
        let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
        XCTAssertEqual(client.mapError(error) as? MyStudiesError, .unauthorized)
    }

    func testHTTP403BecomesOnboardingRequired() {
        let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 403))
        XCTAssertEqual(client.mapError(error) as? MyStudiesError, .onboardingRequired)
    }

    func testHTTP404BecomesUnavailableWithoutSeparateNotFound() {
        let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404))
        XCTAssertEqual(client.mapError(error) as? MyStudiesError, .unavailable)
    }

    func testDecodingErrorBecomesInvalidData() {
        let decodingError = DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "Invalid JSON structure")
        )
        let error = AFError.responseSerializationFailed(reason: .decodingFailed(error: decodingError))
        XCTAssertEqual(client.mapError(error) as? MyStudiesError, .invalidData)
        XCTAssertEqual(client.mapError(decodingError) as? MyStudiesError, .invalidData)
    }

    func testServerFailureBecomesUnavailable() {
        let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 500))
        XCTAssertEqual(client.mapError(error) as? MyStudiesError, .unavailable)
    }

    func testTransportFailureBecomesUnavailable() {
        let error = AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet))
        XCTAssertEqual(client.mapError(error) as? MyStudiesError, .unavailable)
    }

    func testUnexpectedErrorBecomesUnavailable() {
        struct UnknownCustomError: Error {}
        XCTAssertEqual(client.mapError(UnknownCustomError()) as? MyStudiesError, .unavailable)
    }

    func testMyStudiesErrorIsPreserved() {
        for error in [
            MyStudiesError.unauthorized,
            .onboardingRequired,
            .featureUnavailable,
            .unavailable,
            .invalidData
        ] {
            XCTAssertEqual(client.mapError(error) as? MyStudiesError, error)
        }
    }

    func testRouterConstructsCorrectURLWithoutQueryParameters() throws {
        let token = "test-jwt-access-token"
        let request = try MyStudiesRouter.myStudies(accessToken: token).asURLRequest()
        XCTAssertEqual(request.url?.absoluteString, "https://api.studyclub-plusplus.com/api/me/studies")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.headers.value(for: "Accept"), "application/json")
        XCTAssertEqual(request.headers.value(for: "Authorization"), "Bearer test-jwt-access-token")
    }

    func testRouterRejectsEmptyOrWhitespaceAccessToken() {
        XCTAssertThrowsError(try MyStudiesRouter.myStudies(accessToken: "").asURLRequest()) { error in
            XCTAssertEqual(error as? MyStudiesError, .unauthorized)
        }
        XCTAssertThrowsError(try MyStudiesRouter.myStudies(accessToken: "   \t\n  ").asURLRequest()) { error in
            XCTAssertEqual(error as? MyStudiesError, .unauthorized)
        }
    }

    func testClientRejectsEmptyOrWhitespaceAccessTokenBeforeRequest() async {
        do {
            _ = try await client.fetchMyStudies(accessToken: "")
            XCTFail("Empty access token must fail immediately")
        } catch {
            XCTAssertEqual(error as? MyStudiesError, .unauthorized)
        }

        do {
            _ = try await client.fetchMyStudies(accessToken: "   \n\t  ")
            XCTFail("Whitespace access token must fail immediately")
        } catch {
            XCTAssertEqual(error as? MyStudiesError, .unauthorized)
        }
    }
}
