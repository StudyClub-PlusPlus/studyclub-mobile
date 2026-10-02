extension StudyCategory {
    var displayText: String {
        switch self {
        case .aiML: "AI/ML"
        case .cs: "CS"
        case .data: "데이터"
        case .backend: "백엔드"
        case .frontend: "프론트엔드"
        case .mobile: "모바일"
        case .planning: "기획"
        case .pm: "PM"
        case .design: "디자인"
        case .career: "커리어"
        case .language: "외국어"
        case .lifestyle: "라이프스타일"
        case .business: "비즈니스"
        case .other: "기타"
        }
    }
}
