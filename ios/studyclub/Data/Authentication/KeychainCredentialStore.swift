import Foundation
import Security

/// The committed session and one replaceable pending write use separate Keychain items.
/// A crash or failed pending cleanup cannot turn staged credentials into a session.
struct KeychainCredentialStore: CredentialStore {
    private struct Pending: Codable {
        let write: PendingCredentialWrite
        let tokens: AuthTokens
        let previous: AuthTokens?
        var invalidated: Bool
    }

    private struct Session: Codable {
        let tokens: AuthTokens
        let write: PendingCredentialWrite?
        let previous: AuthTokens?
    }

    // Serializes conditional Keychain updates across feature-owned instances in this process.
    // This mutex owns no session state.
    private static let lock = NSRecursiveLock()
    private let persistence: any CredentialPersistence
    private let account = "session"
    private let pendingAccount = "pending-session"

    init(service: String = "studycub.studyclub.auth") {
        persistence = SecurityCredentialPersistence(service: service)
    }

    init(persistence: any CredentialPersistence) {
        self.persistence = persistence
    }

    func load() throws -> AuthTokens? {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        let session = try session()
        if let write = session?.write,
           let pending = try pending(), pending.write == write, pending.invalidated {
            // A new instance reconciles an interrupted compensation before exposing credentials.
            try rollback(write)
            return try self.session()?.tokens
        }
        return session?.tokens
    }

    @discardableResult
    func save(_ tokens: AuthTokens) throws -> PendingCredentialWrite {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        let write = PendingCredentialWrite(id: UUID())
        let previous = try load()
        let data = try JSONEncoder().encode(Pending(write: write, tokens: tokens, previous: previous, invalidated: false))
        try persist(data, account: pendingAccount)
        return write
    }

    func commit(_ write: PendingCredentialWrite) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard let pending = try pending(), pending.write == write, !pending.invalidated else {
            throw CredentialStoreError.corrupted
        }
        let session = Session(tokens: pending.tokens, write: write, previous: pending.previous)
        try persist(JSONEncoder().encode(session), account: account)
    }

    func rollback(_ write: PendingCredentialWrite) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard let session = try session(), session.write == write else {
            try? discard(write)
            return
        }
        // Record invalidation before the compensating active write. If that write fails, a fresh
        // instance will retry it rather than restoring the cancelled credentials.
        let invalidated = Pending(write: write, tokens: session.tokens, previous: session.previous, invalidated: true)
        let data = try JSONEncoder().encode(invalidated)
        do { try persist(data, account: pendingAccount) }
        catch {
            // Even when recording the marker fails, successful compensation is enough to finish.
            try restorePrevious(session.previous)
            return
        }
        try restorePrevious(session.previous)
        try? discard(write)
    }

    private func restorePrevious(_ previous: AuthTokens?) throws {
        if let previous { try persist(JSONEncoder().encode(previous), account: account) }
        else { try remove(account: account) }
    }

    private func session() throws -> Session? {
        guard let data = try read(account: account) else { return nil }
        if let session = try? JSONDecoder().decode(Session.self, from: data) { return session }
        // Credentials written by the original unreleased implementation have no attempt metadata.
        guard let tokens = try? JSONDecoder().decode(AuthTokens.self, from: data) else {
            throw CredentialStoreError.corrupted
        }
        return Session(tokens: tokens, write: nil, previous: nil)
    }

    func discard(_ write: PendingCredentialWrite) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard let pending = try pending(), pending.write == write else { return }
        try remove(account: pendingAccount)
    }

    func delete() throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        // Reconcile a recorded invalidation before removing its marker. Corrupt active bytes
        // remain deletable, while a storage/recovery failure must keep logout visibly failed.
        do { _ = try load() }
        catch CredentialStoreError.corrupted { }
        try remove(account: pendingAccount)
        try remove(account: account)
    }

    private func pending() throws -> Pending? {
        guard let data = try read(account: pendingAccount) else { return nil }
        guard let pending = try? JSONDecoder().decode(Pending.self, from: data) else {
            throw CredentialStoreError.failure(status: errSecDecode)
        }
        return pending
    }

    private func read(account: String) throws -> Data? { try persistence.read(account: account) }
    private func persist(_ data: Data, account: String) throws { try persistence.write(data, account: account) }
    private func remove(account: String) throws { try persistence.delete(account: account) }
}

/// The three physical I/O operations are isolated so tests can fail real store-policy writes.
/// This is not a session owner; DTO and transaction decisions stay in KeychainCredentialStore.
protocol CredentialPersistence: Sendable {
    func read(account: String) throws -> Data?
    func write(_ data: Data, account: String) throws
    func delete(account: String) throws
}

private struct SecurityCredentialPersistence: CredentialPersistence {
    let service: String
    func read(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialStoreError.failure(status: status) }
        guard let data = result as? Data else { throw CredentialStoreError.corrupted }
        return data
    }

    func write(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw CredentialStoreError.failure(status: update) }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let add = SecItemAdd(item as CFDictionary, nil)
        guard add == errSecSuccess else { throw CredentialStoreError.failure(status: add) }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.failure(status: status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
