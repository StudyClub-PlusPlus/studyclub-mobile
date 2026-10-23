import XCTest
@testable import studyclub

/// Small synthetic contracts for the removed field; no live IDs or production-dependent tests.
final class StudyDetailContractTests: XCTestCase {
    func testRetainsSuppliedDeliveryFormat() throws {
        let detail = try decode(extra: #", "deliveryFormat": "ONLINE""#).toDomain()
        XCTAssertEqual(detail.deliveryFormat, .online)
    }

    func testMissingAndNullDeliveryFormatDoNotHideValidStudy() throws {
        for extra in ["", #", "deliveryFormat": null"#] {
            let detail = try decode(extra: extra).toDomain()
            XCTAssertEqual(detail.id, "42")
            XCTAssertEqual(detail.title, "스터디")
            XCTAssertNil(detail.deliveryFormat)
        }
    }

    func testWrongTypeAndUnknownDeliveryFormatStillFail() {
        for extra in [#", "deliveryFormat": 7"#, #", "deliveryFormat": "UNKNOWN""#] {
            XCTAssertThrowsError(try decode(extra: extra))
        }
    }

    func testMissingAndInvalidIdentityStillFail() {
        let missingID = #"{"title":"스터디","category":"SOFTWARE","studyKind":"STUDY","status":"OPEN"}"#
        XCTAssertThrowsError(try JSONDecoder().decode(StudyDetailDTO.self, from: Data(missingID.utf8)))
        XCTAssertThrowsError(try decode(extra: "", id: 0).toDomain())
    }

    private func decode(extra: String, id: Int = 42) throws -> StudyDetailDTO {
        let json = """
        {"id":\(id),"title":"스터디","category":"SOFTWARE","studyKind":"STUDY","status":"OPEN"\(extra)}
        """
        return try JSONDecoder().decode(StudyDetailDTO.self, from: Data(json.utf8))
    }
}
