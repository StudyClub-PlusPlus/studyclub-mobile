/// Public search conditions. Nil filters mean all public studies.
struct StudySearchQuery: Equatable, Sendable {
    let keyword: String
    var phase: StudyPhase?
    var category: StudyCategory?
}
