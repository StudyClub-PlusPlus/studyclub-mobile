import Foundation

enum MockStudyScenario: String, Sendable {
    case content
    case empty
    case failure
    case loading
    case detailFailure = "detail-failure"
    case detailLoading = "detail-loading"
    case detailEmpty = "detail-empty"
}

actor MockStudyAPIClient: StudyAPIClient {
    private let scenario: MockStudyScenario
    private let delayNanoseconds: UInt64

    init(scenario: MockStudyScenario, delayNanoseconds: UInt64 = 250_000_000) {
        self.scenario = scenario
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchStudies() async throws -> [StudyDTO] {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()

        switch scenario {
        case .content, .detailFailure, .detailLoading, .detailEmpty:
            return Self.samples
        case .empty:
            return []
        case .failure:
            throw RepositoryError.unavailable
        case .loading:
            try await Task.sleep(nanoseconds: .max)
            throw CancellationError()
        }
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetailDTO {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()
        switch scenario {
        case .failure, .detailFailure:
            throw RepositoryError.unavailable
        case .detailEmpty:
            throw RepositoryError.notFound
        case .loading, .detailLoading:
            try await Task.sleep(nanoseconds: .max)
            throw CancellationError()
        default:
            guard let study = Self.detailSamples[id] else {
                throw RepositoryError.notFound
            }
            return study
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

    private static let detailSamples: [Study.ID: StudyDetailDTO] = [
        "ios-architecture": makeDetail(
            id: 1,
            slug: "ios-architecture",
            title: "UIKit 아키텍처 같이 읽기",
            category: "MOBILE",
            description: "작은 예제를 만들며 MVVM과 Repository의 책임을 함께 정리해요.",
            curriculum: "의존성 역전\nSwift Concurrency\n테스트 가능한 ViewModel",
            capacity: 8
        ),
        "algorithm": makeDetail(
            id: 2,
            slug: "algorithm",
            title: "알고리즘 문제 풀이",
            category: "CS",
            description: "매주 두 문제를 풀고 풀이의 시간·공간 복잡도를 차분히 비교해요.",
            curriculum: "그래프 탐색\n동적 계획법\n코드 리뷰",
            capacity: 8,
            recruitStatus: "RECRUIT_CLOSED"
        ),
        "backend-design": makeDetail(
            id: 3,
            slug: "backend-design",
            title: "확장 가능한 API 설계",
            category: "BACKEND",
            description: "실제 서비스 사례를 바탕으로 API 경계와 오류 계약을 설계해요.",
            curriculum: "REST 계약\n관찰 가능성\n장애 대응",
            capacity: 10
        ),
        "design-system": makeDetail(
            id: 4,
            slug: "design-system",
            title: "모바일 디자인 시스템 실습",
            category: "DESIGN",
            description: "토큰부터 접근성까지 작은 컴포넌트 라이브러리를 함께 다듬어요.",
            curriculum: "디자인 토큰\nDynamic Type\n접근성",
            capacity: 9
        )
    ]

    private static func makeDetail(
        id: Int,
        slug: String,
        title: String,
        category: String,
        description: String,
        curriculum: String,
        capacity: Int,
        recruitStatus: String = "RECRUITING"
    ) -> StudyDetailDTO {
        StudyDetailDTO(
            id: id,
            slug: slug,
            title: title,
            description: description,
            category: category,
            studyKind: "STUDY",
            thumbnailURL: nil,
            deliveryFormat: "ONLINE",
            status: "OPEN",
            recruitStatus: recruitStatus,
            curriculum: curriculum,
            capacity: capacity,
            recruitDeadlineAt: "2026-10-01T00:00:00Z",
            startAt: "2026-10-15T00:00:00Z",
            endAt: "2026-12-15T00:00:00Z"
        )
    }
}
