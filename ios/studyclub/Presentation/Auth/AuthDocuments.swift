import Foundation

/// Terms and privacy are the live pages on the StudyClub site (`WEB_HOST` in the xcconfig), so the app
/// never ships a stale copy and a wording change needs no app release. Marketing is a one-line notice.
struct AuthDocuments {
    enum Kind: String, CaseIterable {
        case terms = "이용약관"
        case privacy = "개인정보 처리방침"
        case marketing = "마케팅 동의 내용"
    }

    static let webRoot: URL = {
        let host = (Bundle.main.object(forInfoDictionaryKey: "StudyClubWebHost") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let host, !host.isEmpty, let url = URL(string: "https://\(host)") else {
            return URL(string: "https://studyclub.life")!
        }
        return url
    }()

    /// The page to open, or nil when the document is shown as text.
    func url(for kind: Kind) -> URL? {
        switch kind {
        case .terms: Self.webRoot.appending(path: "ko/terms")
        case .privacy: Self.webRoot.appending(path: "ko/privacy")
        case .marketing: nil
        }
    }

    func content(for kind: Kind) -> String {
        switch kind {
        case .marketing: "스터디 소식과 행사 안내를 이메일로 보내드려요"
        case .terms, .privacy: url(for: kind)?.absoluteString ?? ""
        }
    }

    /// The linked pages are the current terms, so consent and submission are open.
    var allowsConsentAndSubmit: Bool { true }
}
