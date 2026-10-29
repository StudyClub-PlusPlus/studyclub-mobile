import Foundation

/// Parsing contracts for the authentication API. They never leave Data.
struct AccountDTO: Decodable, Sendable {
    let id: Int64
    let nickname: String?
    /// Present once the server has confirmed signup completion.
    let onboardingCompletedAt: String?
    /// Returned only by `GET /api/me` (`AccountSelfView`). Login and onboarding omit it.
    let discordNickname: String?

    init(id: Int64, nickname: String?, onboardingCompletedAt: String?, discordNickname: String? = nil) {
        self.id = id
        self.nickname = nickname
        self.onboardingCompletedAt = onboardingCompletedAt
        self.discordNickname = discordNickname
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        nickname = try container.decode(String.self, forKey: .nickname)
        // Explicit null is incomplete; a missing key is a malformed response.
        onboardingCompletedAt = try container.decode(String?.self, forKey: .onboardingCompletedAt)
        discordNickname = try container.decodeIfPresent(String.self, forKey: .discordNickname)
    }

    private enum CodingKeys: String, CodingKey {
        case id, nickname, onboardingCompletedAt, discordNickname
    }
}

struct AuthSessionDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let account: AccountDTO
    let suggestedNickname: String?
}

struct AccessTokenDTO: Decodable, Sendable {
    let accessToken: String
}

struct OnboardingRequestDTO: Encodable, Sendable {
    let age14Confirmed: Bool
    let termsOfServiceAgreed: Bool
    let privacyPolicyAgreed: Bool
    let marketingAgreed: Bool
    let nickname: String
    let timeZone: String

    init(_ registration: MemberRegistration) {
        age14Confirmed = registration.age14Confirmed
        termsOfServiceAgreed = registration.termsOfServiceAgreed
        privacyPolicyAgreed = registration.privacyPolicyAgreed
        marketingAgreed = registration.marketingAgreed
        nickname = registration.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        timeZone = registration.timeZone
    }
}
