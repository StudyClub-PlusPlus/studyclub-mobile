import Foundation

/// API host from Info.plist (`API_HOST` in Config.xcconfig). Falls back to production.
enum APIHost {
    static let root: URL = {
        let host = (Bundle.main.object(forInfoDictionaryKey: "StudyClubAPIHost") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let host, !host.isEmpty, let url = URL(string: "https://\(host)") else {
            return URL(string: "https://api.studyclub-plusplus.com")!
        }
        return url
    }()
}
