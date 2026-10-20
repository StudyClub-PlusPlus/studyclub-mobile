import Foundation

extension AccountDTO {
    /// Only an explicit null completion on a valid account means incomplete signup.
    /// Known signup identity must match on both submit and completion recheck.
    func toMember(expectedID: Int64? = nil) throws -> Member? {
        guard id > 0, expectedID == nil || id == expectedID,
              let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
              !nickname.isEmpty else { throw AuthRemoteError.server }
        guard let completedAt = onboardingCompletedAt else { return nil }

        // The server serializes Instant.toString(): UTC seconds with up to nine fractional digits.
        // A lexical check and calendar round trip reject garbage, truncation and normalized dates.
        let pattern = #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,9})?Z\z"#
        guard completedAt.range(of: pattern, options: .regularExpression) != nil else {
            throw AuthRemoteError.server
        }
        let seconds = String(completedAt.prefix(19)) + "Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let instant = formatter.date(from: seconds), formatter.string(from: instant) == seconds else {
            throw AuthRemoteError.server
        }
        return Member(nickname: nickname)
    }
}

extension AuthSessionDTO {
    func validatedTokens() throws -> AuthTokens {
        let tokens = AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
        try tokens.validate()
        return tokens
    }
}
