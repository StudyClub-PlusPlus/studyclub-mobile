extension StudyCategory {
    var displayText: String {
        switch self {
        case .aiML: "AI/ML"
        case .algorithm: "알고리즘"
        case .data: "데이터"
        case .software: "소프트웨어"
        case .career: "커리어"
        case .bookClub: "북클럽"
        case .language: "외국어"
        case .lifestyle: "라이프스타일"
        case .product: "프로덕트"
        case .business: "비즈니스"
        case .other: "기타"
        }
    }
}
