import Foundation

struct MockRepository: RepositoryProtocol {
    func fetchStudies(offset: Int) async throws -> StudyPage {
        StudyPage(studies: Array(Self.studies.dropFirst(offset).prefix(20)),
                  totalCount: Self.studies.count, offset: offset)
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetail {
        if let detail = Self.details[id] { return detail }
        guard let study = Self.studies.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        return Self.makeDetail(study: study, category: study.category,
                               curriculum: "함께 읽기\n실습과 토론\n결과 공유")
    }

    private static let defaultStudy = Study(
        id: "1", category: .software, title: "UIKit 아키텍처 같이 읽기",
        summary: "작은 예제를 만들며 MVVM과 Repository의 책임을 함께 정리해요.",
        participantCount: 5, capacity: 8, phase: .recruiting, closingSoon: false
    )

    private static let studies: [Study] = [
        defaultStudy,
        Study(
            id: "2", category: .algorithm, title: "알고리즘 문제 풀이",
            summary: "매주 두 문제를 풀고 풀이의 시간·공간 복잡도를 차분히 비교해요.",
            participantCount: 7, capacity: 8, phase: .recruiting, closingSoon: true
        ),
        Study(
            id: "3", category: .software, title: "확장 가능한 API 설계",
            summary: "실제 서비스 사례를 바탕으로 API 경계와 오류 계약을 설계해요.",
            participantCount: 4, capacity: 10, phase: .recruiting, closingSoon: false
        ),
        Study(
            id: "4", category: .other, title: "모바일 디자인 시스템 실습",
            summary: "토큰부터 접근성까지 작은 컴포넌트 라이브러리를 함께 다듬어요.",
            participantCount: 6, capacity: 9, phase: .recruiting, closingSoon: false
        )
    ] + (5...65).map { number in
        Study(
            id: String(number), category: number.isMultiple(of: 2) ? .software : .algorithm,
            title: "스터디 \(number) · 함께 만드는 작은 프로젝트",
            summary: "매주 학습한 내용을 나누고 작은 결과물을 완성해요.",
            participantCount: number % 8 + 1, capacity: 10,
            phase: .recruiting, closingSoon: number.isMultiple(of: 5)
        )
    }

    private static let defaultDetail = makeDetail(study: defaultStudy, category: .software, curriculum: "의존성 역전\nSwift Concurrency\n테스트 가능한 ViewModel")

    private static let details: [Study.ID: StudyDetail] = [
        "1": defaultDetail,
        "2": makeDetail(study: studies[1], category: .algorithm, curriculum: "그래프 탐색\n동적 계획법\n코드 리뷰", recruitStatus: .closed),
        "3": makeDetail(study: studies[2], category: .software, curriculum: "REST 계약\n관찰 가능성\n장애 대응"),
        "4": makeDetail(study: studies[3], category: .other, curriculum: "디자인 토큰\nDynamic Type\n접근성")
    ]

    private static func makeDetail(
        study: Study,
        category: StudyCategory,
        curriculum: String,
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
            curriculum: curriculum,
            capacity: study.capacity,
            recruitDeadlineAt: Date(timeIntervalSince1970: 1_790_812_800),
            startAt: Date(timeIntervalSince1970: 1_792_022_400),
            endAt: Date(timeIntervalSince1970: 1_797_292_800)
        )
    }
}
