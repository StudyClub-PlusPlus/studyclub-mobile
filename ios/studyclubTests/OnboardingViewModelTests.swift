import XCTest
@testable import studyclub

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testSuggestedNicknameWithWhitespaceShowsErrorImmediately() {
        let model = OnboardingViewModel(suggestedNickname: "스터디 친구", allowsConsentAndSubmit: true)
        XCTAssertEqual(model.nicknameError, "띄어쓰기는 사용할 수 없어요.")
    }

    func testWhitespaceShowsSpecificErrorAndBlocksSubmission() {
        for name in ["스터디 친구", " 친구", "친구 ", "친구\t이름", "친구\n이름", "친구\u{00A0}이름", "친구\u{3000}이름", "친구 !"] {
            let model = OnboardingViewModel(allowsConsentAndSubmit: true)
            model.updateConsents(age: true, terms: true, privacy: true, marketing: false)
            model.updateNickname(name)
            XCTAssertEqual(model.nicknameError, "띄어쓰기는 사용할 수 없어요.", name)
            XCTAssertFalse(model.canSubmit, name)
            XCTAssertNil(model.submit(), name)
            XCTAssertEqual(model.state, .editing)
            XCTAssertEqual(model.input.nickname, name)
        }
    }

    func testSpecialCharactersShowSpecificErrorAndCorrectionClearsIt() {
        let model = OnboardingViewModel(allowsConsentAndSubmit: true)
        XCTAssertNil(model.nicknameError)
        model.updateConsents(age: true, terms: true, privacy: true, marketing: false)
        for name in ["친구!", "친구-이름", "친구😀", "친구.이름"] {
            model.updateNickname(name)
            XCTAssertEqual(model.nicknameError, "특수문자는 _만 사용할 수 있어요.", name)
            XCTAssertNil(model.submit())
        }
        model.updateNickname("친구_abc123")
        XCTAssertNil(model.nicknameError)
        XCTAssertTrue(model.canSubmit)
        XCTAssertEqual(model.submit()?.nickname, "친구_abc123")
    }

    func testEmptyInputWaitsForValidationAndLettersNumbersUnderscoreAreAllowed() {
        let model = OnboardingViewModel(allowsConsentAndSubmit: true)
        model.updateNickname("")
        XCTAssertNil(model.nicknameError)
        XCTAssertFalse(model.canSubmit)
        model.validateNickname()
        XCTAssertEqual(model.nicknameError, "닉네임을 입력해 주세요.")
        for name in ["스터디친구", "abc_123", "친구１２３", "스터디"] {
            model.updateNickname(name)
            model.validateNickname()
            XCTAssertNil(model.nicknameError, name)
        }
    }
}
