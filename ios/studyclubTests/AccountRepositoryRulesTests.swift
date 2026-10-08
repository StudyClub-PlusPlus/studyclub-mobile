import Alamofire
import XCTest
@testable import studyclub

@MainActor
final class AccountRepositoryRulesTests: XCTestCase {
    func testDisabledFeatureRejectsFetchBeforeSessionValidation() async {
        let repository = LiveAccountRepository(accessToken: nil, isEnabled: false)
        do {
            _ = try await repository.fetchAccount()
            XCTFail("Expected the disabled feature to reject the request")
        } catch {
            XCTAssertEqual(error as? AccountError, .unavailable)
        }
    }

    func testMissingSessionRejectsFetchWithoutTransport() async {
        let repository = LiveAccountRepository(accessToken: nil, isEnabled: true)
        do {
            _ = try await repository.fetchAccount()
            XCTFail("Expected a missing session to reject the request")
        } catch {
            XCTAssertEqual(error as? AccountError, .unauthorized)
        }
        XCTAssertFalse(repository.supportsDemo)
    }

    func testCancellationIsPreserved() {
        let repository = LiveAccountRepository(accessToken: nil, isEnabled: true)
        XCTAssertTrue(repository.mapError(CancellationError()) is CancellationError)
        XCTAssertTrue(repository.mapError(AFError.explicitlyCancelled) is CancellationError)
    }

    func testUnauthorizedAndServerErrorsRemainDistinct() {
        let repository = LiveAccountRepository(accessToken: nil, isEnabled: true)
        let unauthorizedError = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
        let serverError = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 500))
        XCTAssertEqual(repository.mapError(unauthorizedError) as? AccountError, .unauthorized)
        XCTAssertEqual(repository.mapError(serverError) as? AccountError, .unavailable)
        XCTAssertEqual(repository.mapError(AccountError.invalidData) as? AccountError, .invalidData)
    }

    func testDecodingFailureIsInvalidData() {
        let repository = LiveAccountRepository(accessToken: nil, isEnabled: true)
        let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "test"))
        let transportError = AFError.responseSerializationFailed(reason: .decodingFailed(error: decodingError))
        XCTAssertEqual(repository.mapError(decodingError) as? AccountError, .invalidData)
        XCTAssertEqual(repository.mapError(transportError) as? AccountError, .invalidData)
    }

    func testLogoutClearsSessionAndDoesNotStartDemoInRealMode() {
        let repository = LiveAccountRepository(accessToken: "sample-token", refreshToken: "sample-refresh", isEnabled: true)
        XCTAssertTrue(repository.hasSession)
        repository.clearSession()
        repository.startDemoSession()
        XCTAssertFalse(repository.hasSession)
    }

    func testMappingDropsInsecurePictureAndPreservesSecurePicture() throws {
        let secureAccount = try AccountDTO(id: 1, email: "member@example.com", nickname: nil, picture: "https://example.com/avatar.png").toDomain()
        let insecureAccount = try AccountDTO(id: 1, email: "member@example.com", nickname: nil, picture: "http://example.com/avatar.png").toDomain()
        XCTAssertEqual(secureAccount.picture?.absoluteString, "https://example.com/avatar.png")
        XCTAssertNil(insecureAccount.picture)
    }
}
