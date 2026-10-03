#if DEBUG
import Foundation

struct MockRepository: RepositoryProtocol {
    func fetchStudies() async throws -> [Study] {
        return Self.studies
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetail {
        Self.details[id] ?? Self.defaultDetail
    }

    private static let defaultStudy = Study(
        id: "1", category: "iOS", title: "UIKit 아키텍처 같이 읽기",
        summary: "작은 예제를 만들며 MVVM과 Repository의 책임을 함께 정리해요.",
        currentMembers: 5, maximumMembers: 8, status: .recruiting,
        topics: ["의존성 역전", "Swift Concurrency", "테스트 가능한 ViewModel"]
    )

    private static let studies: [Study] = [
        defaultStudy,
        Study(
            id: "2", category: "알고리즘", title: "알고리즘 문제 풀이",
            summary: "매주 두 문제를 풀고 풀이의 시간·공간 복잡도를 차분히 비교해요.",
            currentMembers: 7, maximumMembers: 8, status: .almostFull,
            topics: ["그래프 탐색", "동적 계획법", "코드 리뷰"]
        ),
        Study(
            id: "3", category: "Backend", title: "확장 가능한 API 설계",
            summary: "실제 서비스 사례를 바탕으로 API 경계와 오류 계약을 설계해요.",
            currentMembers: 4, maximumMembers: 10, status: .recruiting,
            topics: ["REST 계약", "관찰 가능성", "장애 대응"]
        ),
        Study(
            id: "4", category: "Design", title: "모바일 디자인 시스템 실습",
            summary: "토큰부터 접근성까지 작은 컴포넌트 라이브러리를 함께 다듬어요.",
            currentMembers: 6, maximumMembers: 9, status: .recruiting,
            topics: ["디자인 토큰", "Dynamic Type", "접근성"]
        )
    ]

    private static let defaultDetail = makeDetail(study: defaultStudy, category: .software)

    private static let details: [Study.ID: StudyDetail] = [
        "1": defaultDetail,
        "2": makeDetail(study: studies[1], category: .algorithm, recruitStatus: .closed),
        "3": makeDetail(study: studies[2], category: .software),
        "4": makeDetail(study: studies[3], category: .other)
    ]

    private static func makeDetail(
        study: Study,
        category: StudyCategory,
        recruitStatus: RecruitStatus = .recruiting
    ) -> StudyDetail {
        StudyDetail(
            id: study.id,
            title: study.title,
            description: study.summary,
            category: category,
            studyKind: .study,
            thumbnailURL: nil,
            deliveryFormat: .online,
            status: .open,
            recruitStatus: recruitStatus,
            curriculum: study.topics.joined(separator: "\n"),
            capacity: study.maximumMembers,
            recruitDeadlineAt: Date(timeIntervalSince1970: 1_790_812_800),
            startAt: Date(timeIntervalSince1970: 1_792_022_400),
            endAt: Date(timeIntervalSince1970: 1_797_292_800)
        )
    }
}
#endif
