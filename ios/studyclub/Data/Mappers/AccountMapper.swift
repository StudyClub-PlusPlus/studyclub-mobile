import Foundation

extension AccountDTO {
    func toDomain() throws -> Account {
        guard id > 0, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccountError.invalidData
        }

        let pictureURL: URL?
        if let picture, let candidateURL = URL(string: picture),
           candidateURL.scheme == "https", candidateURL.host != nil {
            pictureURL = candidateURL
        } else {
            pictureURL = nil
        }

        return Account(id: id, email: email, nickname: nickname, picture: pictureURL)
    }
}
