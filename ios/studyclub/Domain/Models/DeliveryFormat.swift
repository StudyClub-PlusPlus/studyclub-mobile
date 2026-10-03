enum DeliveryFormat: String, Decodable, CaseIterable, Sendable {
    case online = "ONLINE"
    case offline = "OFFLINE"
    case hybrid = "HYBRID"
}
