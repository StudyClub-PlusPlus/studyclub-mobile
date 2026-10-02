extension DeliveryFormat {
    var displayText: String {
        switch self {
        case .online: "온라인"
        case .offline: "오프라인"
        case .hybrid: "온·오프라인"
        }
    }
}
