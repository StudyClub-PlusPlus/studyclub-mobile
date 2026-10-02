enum StudyStatus: String, Decodable, CaseIterable, Sendable {
    case draft = "DRAFT"
    case open = "OPEN"
    case closed = "CLOSED"
}
