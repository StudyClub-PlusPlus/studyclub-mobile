import Foundation
import GoogleSignIn
import UIKit

/// Google OAuth values read from the app's Info.plist. Authentication starts only when every
/// value exists and the reversed client ID is registered as a URL scheme for the SDK callback.
struct GoogleSignInConfiguration: Equatable, Sendable {
    let clientID: String
    let serverClientID: String

    init?(infoDictionary: [String: Any]?) {
        guard let info = infoDictionary,
              let clientID = Self.text(info["GIDClientID"]),
              let serverClientID = Self.text(info["GIDServerClientID"]),
              let scheme = Self.reversedScheme(of: clientID),
              Self.registeredSchemes(in: info).contains(scheme) else { return nil }
        self.clientID = clientID
        self.serverClientID = serverClientID
    }

    private static func text(_ value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    /// `123-abc.apps.googleusercontent.com` -> `com.googleusercontent.apps.123-abc`
    static func reversedScheme(of clientID: String) -> String? {
        let suffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(suffix), clientID.count > suffix.count else { return nil }
        return "com.googleusercontent.apps." + clientID.dropLast(suffix.count)
    }

    private static func registeredSchemes(in info: [String: Any]) -> Set<String> {
        let types = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
        return Set(types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] })
    }
}

/// Presents the Google SDK flow and returns the one-time server authorization code.
/// The SDK keeps no session of its own: it is signed out as soon as the code is read.
struct GoogleSignInProvider: GoogleAuthorizationProviding {
    func authorizationCode() async throws -> String {
        guard let configuration = GoogleSignInConfiguration(infoDictionary: Bundle.main.infoDictionary) else {
            throw AuthError.configurationMissing
        }
        let waiter = SignInWaiter()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiter.install(continuation)
                Task { @MainActor in
                    Self.start(configuration, waiter: waiter)
                }
            }
        } onCancel: {
            waiter.finish(.failure(CancellationError()))
        }
    }

    @MainActor
    private static func start(_ configuration: GoogleSignInConfiguration, waiter: SignInWaiter) {
        // A task cancelled before presentation must not open the Google UI.
        guard !waiter.hasFinished else { return }
        guard let presenter = topViewController() else {
            waiter.finish(.failure(AuthError.unavailable))
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: configuration.clientID,
            serverClientID: configuration.serverClientID
        )
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            // Completion is delivered on the main queue.
            GIDSignIn.sharedInstance.signOut()
            if let error {
                let canceled = (error as NSError).domain == kGIDSignInErrorDomain
                    && (error as NSError).code == GIDSignInError.canceled.rawValue
                waiter.finish(.failure(canceled ? AuthError.userCancelled : AuthError.unavailable))
            } else if let code = result?.serverAuthCode, !code.isEmpty {
                waiter.finish(.success(code))
            } else {
                waiter.finish(.failure(AuthError.unavailable))
            }
        }
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// Resumes the continuation once. The SDK cannot be cancelled, so a cancelled task finishes the
/// waiter first and the SDK's later completion is ignored.
private final class SignInWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?
    private var result: Result<String, Error>?
    private var isFinished = false

    var hasFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isFinished
    }

    func install(_ continuation: CheckedContinuation<String, Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func finish(_ result: Result<String, Error>) {
        lock.lock()
        guard !isFinished else { lock.unlock(); return }
        isFinished = true
        if let continuation {
            self.continuation = nil
            lock.unlock()
            continuation.resume(with: result)
        } else {
            self.result = result
            lock.unlock()
        }
    }
}
