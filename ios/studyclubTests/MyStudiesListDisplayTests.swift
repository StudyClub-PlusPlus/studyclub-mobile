import XCTest
@testable import studyclub

@MainActor
final class MyStudiesListDisplayTests: XCTestCase {
    func testDuplicateIdentifiersKeepFirstPositionAndLastDisplayValue() {
        let first = card("12", "이전 제목")
        let second = card("24", "다른 스터디")
        let revised = card("12", "변경된 제목")
        let model = MyStudiesListViewModel(state: .content, items: [first, second, revised])
        XCTAssertEqual(model.items.map(\.id), ["12", "24"])
        XCTAssertEqual(model.items.first?.title, "변경된 제목")
    }

    func testSelectionRejectsRemovedIdentityAndGuestClearsPrivateDisplay() {
        let model = MyStudiesListViewModel(state: .content, items: [card("12", "이전 스터디")])
        XCTAssertEqual(model.selectedStudyID("12"), "12")
        model.update(state: .content, items: [card("24", "새 스터디")])
        XCTAssertNil(model.selectedStudyID("12"))
        XCTAssertEqual(model.selectedStudyID("24"), "24")
        model.update(state: .guest)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNil(model.selectedStudyID("24"))
    }

    private func card(_ id: String, _ title: String) -> StudyCardCellViewModel {
        .init(id: id, category: "백엔드", title: title, summary: "", memberText: "멤버", statusText: "참여 중")
    }
}
