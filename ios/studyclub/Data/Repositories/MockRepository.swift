#if DEBUG
struct MockRepository: RepositoryProtocol {
    func fetchStudies() async throws -> [Study] {
        return Self.studies
    }

    func fetchStudy(id: Study.ID) async throws -> Study {
        Self.studies.first(where: { $0.id == id }) ?? Self.defaultStudy
    }

    private static let defaultStudy = Study(
        id: "ios-architecture", category: "iOS", title: "UIKit 아키텍처 같이 읽기",
        summary: "작은 예제를 만들며 MVVM과 Repository의 책임을 함께 정리해요.",
        currentMembers: 5, maximumMembers: 8, status: .recruiting,
        topics: ["의존성 역전", "Swift Concurrency", "테스트 가능한 ViewModel"]
    )

    private static let studies: [Study] = [
        defaultStudy,
        Study(
            id: "algorithm", category: "알고리즘", title: "알고리즘 문제 풀이",
            summary: "매주 두 문제를 풀고 풀이의 시간·공간 복잡도를 차분히 비교해요.",
            currentMembers: 7, maximumMembers: 8, status: .almostFull,
            topics: ["그래프 탐색", "동적 계획법", "코드 리뷰"]
        ),
        Study(
            id: "backend-design", category: "Backend", title: "확장 가능한 API 설계",
            summary: "실제 서비스 사례를 바탕으로 API 경계와 오류 계약을 설계해요.",
            currentMembers: 4, maximumMembers: 10, status: .recruiting,
            topics: ["REST 계약", "관찰 가능성", "장애 대응"]
        ),
        Study(
            id: "design-system", category: "Design", title: "모바일 디자인 시스템 실습",
            summary: "토큰부터 접근성까지 작은 컴포넌트 라이브러리를 함께 다듬어요.",
            currentMembers: 6, maximumMembers: 9, status: .recruiting,
            topics: ["디자인 토큰", "Dynamic Type", "접근성"]
        )
    ]
}
#endif
