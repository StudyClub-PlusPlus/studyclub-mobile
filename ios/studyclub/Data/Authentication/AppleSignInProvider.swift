import AuthenticationServices
import UIKit

/// Presents Sign in with Apple and returns the one-time authorization code for the server.
/// Apple sends the name only on the first authorization; it is passed along, never stored.
struct AppleSignInProvider: AppleAuthorizationProviding {
    func authorization() async throws -> SocialAuthorization {
        let session = await AppleSignInSession()
        return try await withTaskCancellationHandler {
            try await session.start()
        } onCancel: {
            Task { @MainActor in session.cancel() }
        }
    }
}

@MainActor
private final class AppleSignInSession: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<SocialAuthorization, Error>?
    private var controller: ASAuthorizationController?

    func start() async throws -> SocialAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    /// The system sheet cannot be dismissed programmatically; its later result is ignored.
    func cancel() {
        finish(.failure(CancellationError()))
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        let code = credential?.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let name = credential?.fullName.flatMap {
            PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
        }
        MainActor.assumeIsolated {
            guard let code, !code.isEmpty else { return finish(.failure(AuthError.unavailable)) }
            finish(.success(SocialAuthorization(
                provider: .apple, code: code, name: name?.isEmpty == false ? name : nil
            )))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let canceled = (error as? ASAuthorizationError)?.code == .canceled
        MainActor.assumeIsolated {
            finish(.failure(canceled ? AuthError.userCancelled : AuthError.unavailable))
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .keyWindow ?? ASPresentationAnchor()
        }
    }

    private func finish(_ result: Result<SocialAuthorization, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        controller = nil
        continuation.resume(with: result)
    }
}
