import Foundation

enum MockStudyScenario: String, Sendable {
    case content
    case empty
    case failure
    case failureOnce = "failure-once"
    case loading
}

actor MockStudyAPIClient: StudyAPIClient {
    private let scenario: MockStudyScenario
    private let delayNanoseconds: UInt64
    private var requestCount = 0

    init(scenario: MockStudyScenario, delayNanoseconds: UInt64 = 250_000_000) {
        self.scenario = scenario
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchStudies() async throws -> [StudyDTO] {
        requestCount += 1
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()

        switch scenario {
        case .content:
            return Self.samples
        case .empty:
            return []
        case .failure:
            throw RepositoryError.unavailable
        case .failureOnce:
            if requestCount == 1 {
                throw RepositoryError.unavailable
            }
            return Self.samples
        case .loading:
            try await Task.sleep(nanoseconds: .max)
            throw CancellationError()
        }
    }

    private static let samples: [StudyDTO] = [
        StudyDTO(
            id: "ios-architecture",
            category: "iOS",
            title: "UIKit 아키텍처 같이 읽기",
            summary: "작은 예제를 만들며 MVVM과 Repository의 책임을 함께 정리해요.",
            currentMembers: 5,
            maximumMembers: 8,
            status: "recruiting",
            topics: ["의존성 역전", "Swift Concurrency", "테스트 가능한 ViewModel"]
        ),
        StudyDTO(
            id: "algorithm",
            category: "알고리즘",
            title: "알고리즘 문제 풀이",
            summary: "매주 두 문제를 풀고 풀이의 시간·공간 복잡도를 차분히 비교해요.",
            currentMembers: 7,
            maximumMembers: 8,
            status: "almost_full",
            topics: ["그래프 탐색", "동적 계획법", "코드 리뷰"]
        ),
        StudyDTO(
            id: "backend-design",
            category: "Backend",
            title: "확장 가능한 API 설계",
            summary: "실제 서비스 사례를 바탕으로 API 경계와 오류 계약을 설계해요.",
            currentMembers: 4,
            maximumMembers: 10,
            status: "recruiting",
            topics: ["REST 계약", "관찰 가능성", "장애 대응"]
        ),
        StudyDTO(
            id: "design-system",
            category: "Design",
            title: "모바일 디자인 시스템 실습",
            summary: "토큰부터 접근성까지 작은 컴포넌트 라이브러리를 함께 다듬어요.",
            currentMembers: 6,
            maximumMembers: 9,
            status: "recruiting",
            topics: ["디자인 토큰", "Dynamic Type", "접근성"]
        )
    ]
}
