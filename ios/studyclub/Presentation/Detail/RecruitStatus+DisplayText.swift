extension RecruitStatus {
    var displayText: String {
        switch self {
        case .recruiting: "모집 중"
        case .closed: "모집 마감"
        }
    }
}
